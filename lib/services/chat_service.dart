import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:logging/logging.dart';
import 'package:retry/retry.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_factory.dart';

/// The possible connection states of the [ChatService].
enum ChatConnectionState {
  /// The client is not connected to the server.
  disconnected,

  /// The client is currently establishing a WebSocket connection.
  connecting,

  /// The connection is established, but the user is not yet logged in.
  connected,

  /// The user is successfully logged in to the chat server.
  loggedIn,

  /// The connection was lost, and the client is attempting to reconnect.
  reconnecting,
}

/// A service that manages the server connection and messages processing.
interface class ChatService {
  /// Creates a [ChatService].
  ChatService({
    required Uri url,
    required this.nickname,
    this.initialChannel,
    required UserConfiguration configuration,
    required http.Client httpClient,
    required this.webSocketFactory,
  }) : _configuration = configuration,
       _httpClient = httpClient,
       _currentChannel = initialChannel == null
           ? '#general'
           : initialChannel.startsWith('#')
           ? initialChannel
           : '#$initialChannel',
       _url = url,
       _wsUrl = deriveWebSocketUrl(url);

  /// The HTTP server URL to connect to.
  Uri get url => _url;
  Uri _url;

  set url(Uri value) {
    _url = value;
    _wsUrl = deriveWebSocketUrl(value);
  }

  /// The WebSocket URL to connect to.
  Uri get websocketUrl => _wsUrl;
  Uri _wsUrl;

  /// The nickname to use when logging in to the chat server.
  String nickname;

  /// The initial channel to join on connection.
  final String? initialChannel;

  final UserConfiguration _configuration;

  /// A factory to create the [WebSocketChannel].
  final WebSocketFactory webSocketFactory;

  final http.Client _httpClient;

  static final _logger = Logger('ChatService');

  /// The current active channel we are focused on.
  String get currentChannel => _currentChannel;

  set currentChannel(String value) {
    final normalized = value.startsWith('#') ? value : '#$value';
    if (_currentChannel != normalized) {
      _currentChannel = normalized;
      _currentChannelController.add(_currentChannel);
    }
  }

  String _currentChannel;

  /// A stream of the current active channel we are focused on.
  Stream<String> get currentChannelStream => _currentChannelController.stream;
  final _currentChannelController = StreamController<String>.broadcast();

  /// A stream of incoming chat messages to be displayed in the UI.
  Stream<ChatMessage> get messages => _messageController.stream;
  final _messageController = StreamController<ChatMessage>.broadcast();

  /// A stream of important notifications to be shown as local notifications.
  Stream<ChatMessage> get notifications => _notificationsController.stream;
  final _notificationsController = StreamController<ChatMessage>.broadcast();

  /// A stream of the current online users list to be displayed in the UI.
  Stream<List<String>> get users => _usersController.stream;
  final _usersController = StreamController<List<String>>.broadcast();

  /// A stream of the current active channels list to be displayed in the UI.
  Stream<Map<String, int>> get channels => _channelsController.stream;
  final _channelsController = StreamController<Map<String, int>>.broadcast();

  bool _isDisposed = false;

  /// A stream of the current connection state.
  ///
  /// True if connected, false if disconnected. The UI can listen to this stream
  /// to update the connection status indicator and trigger reconnection
  /// attempts.
  Stream<bool> get connectionState => _connectionStateController.stream;
  final _connectionStateController = StreamController<bool>.broadcast();

  /// A stream of the detailed connection state.
  Stream<ChatConnectionState> get stateStream => _stateController.stream;
  final _stateController = StreamController<ChatConnectionState>.broadcast();

  /// A stream of the current user's nick changes.
  ///
  /// The UI can listen to this stream to update the displayed nickname when the
  /// user changes their nick.
  Stream<String> get nickChanges => _nickChangeController.stream;
  final _nickChangeController = StreamController<String>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _keepAliveTimer;
  bool _loggedIn = false;
  bool _isReconnecting = false;
  Completer<void>? _loginCompleter;
  String? _sessionUuid;

  /// The current connection state of the client.
  ChatConnectionState get state {
    if (_isReconnecting) {
      return ChatConnectionState.reconnecting;
    } else if (_loginCompleter != null) {
      return ChatConnectionState.connecting;
    } else if (_channel == null) {
      return ChatConnectionState.disconnected;
    } else if (_loggedIn) {
      return ChatConnectionState.loggedIn;
    } else {
      return ChatConnectionState.connected;
    }
  }

  /// Whether the client is currently connected to the WebSocket server.
  bool get isConnected {
    return state == ChatConnectionState.connected ||
        state == ChatConnectionState.loggedIn;
  }

  /// Whether the client is currently logged in to the chat server.
  bool get isLoggedIn => state == ChatConnectionState.loggedIn;

  /// Whether the client is currently in the process of connecting or logging in.
  bool get isConnecting {
    return state == ChatConnectionState.connecting ||
        state == ChatConnectionState.reconnecting;
  }

  bool _isAppInBackground = false;

  /// Signals to the service whether the app is in the background.
  ///
  /// When in the background, the service will pause automatic reconnection
  /// attempts to preserve battery life and OS resources.
  void setAppBackgroundState(bool isBackground) {
    _isAppInBackground = isBackground;
  }

  final List<String> _currentUsers = [];
  final DateTime _appStartTime = DateTime.now();

  final Map<String, _ChannelPingData> _currentChannels = {};
  int _channelPingId = 0;

  /// Connects to the chat server and starts listening for messages.
  ///
  /// If already connected, it will first disconnect and then reconnect.
  /// [mockChannel] can be provided for testing purposes.
  Future<void> connect({WebSocketChannel? mockChannel}) async {
    if (_isDisposed) {
      _logger.warning(
        'Attempted to connect after service was disposed. Ignoring.',
      );
      return;
    }

    if (isLoggedIn) {
      _logger.info('Already connected and logged in. No action taken.');
      return;
    }

    if (_loginCompleter != null) {
      _logger.info(
        'Already in the process of connecting. Awaiting existing connection '
        'attempt.',
      );
      return;
    }

    _logger.info('Connecting to $url as $nickname...');
    disconnect();

    final loginCompleter = Completer<void>();
    _loginCompleter = loginCompleter;

    try {
      final Uri connectionUrl;

      final channelName = currentChannel;
      final timezoneOffset = DateTime.now().timeZoneOffset.inHours;
      connectionUrl = websocketUrl.replace(
        queryParameters: {
          ...websocketUrl.queryParameters,
          'channel': channelName,
          'tz': '$timezoneOffset',
        },
      );

      final channel = _channel =
          mockChannel ?? webSocketFactory.create(connectionUrl);

      // We don't await channel.ready here because we want to start listening
      // immediately. The login completer will handle waiting for full success.
      channel.ready
          .then((_) {
            _logger.info('WebSocket channel ready.');
            _connectionStateController.add(true);
            _stateController.add(state);
          })
          .catchError((error, stackTrace) {
            _logger.severe(
              'WebSocket channel connection failed: $error',
              error,
              stackTrace,
            );
            _handleConnectionFailure(error);
          });

      _subscription = channel.stream.listen(
        (data) => _handleIncomingData(data.toString()),
        onDone: () {
          _logger.warning('WebSocket connection closed.');
          _handleConnectionFailure(Exception('Connection closed'));
        },
        onError: (error, stackTrace) {
          _logger.severe('WebSocket stream error: $error', error, stackTrace);
          _handleConnectionFailure(error);
        },
      );

      return loginCompleter.future
          .then((_) => _loginCompleter = null)
          .catchError((exception, stackTrace) {
            _logger.severe('Login completer error', exception, stackTrace);
            _loginCompleter = null;
            throw exception;
          });
    } catch (error) {
      _handleDisconnect();
      if (!loginCompleter.isCompleted) loginCompleter.completeError(error);
      _loginCompleter = null;
      rethrow;
    }
  }

  /// Disconnects from the chat server and cleans up resources.
  void disconnect() {
    _keepAliveTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _loggedIn = false;
    _sessionUuid = null;
    _connectionStateController.add(false);

    // Clear state so reconnecting doesn't show stale users or channels briefly.
    _currentUsers.clear();
    _usersController.add([]);
    _channelsController.add({});

    if (_loginCompleter?.isCompleted == false) {
      _loginCompleter?.completeError(Exception('Disconnected'));
    }
    _loginCompleter = null;
  }

  /// Sends a message to the chat server.
  void sendMessage(String text) {
    if (_channel case final channel? when _loggedIn) {
      channel.sink.add(text);
    }
  }

  void _handleIncomingData(String data) {
    if (_isDisposed) return;
    final channel = _channel;
    if (channel == null) return;

    final lines = LineSplitter.split(data);
    for (final line in lines) {
      if (line.isEmpty) continue;

      if (!_loggedIn && line.contains('> Type your username:')) {
        _logger.info('Successfully logged in as $nickname.');
        channel.sink.add(nickname);
        _loggedIn = true;
        _stateController.add(state);
        channel.sink.add('/session');
        continue;
      }

      if (!_loggedIn && line.contains('> Name cannot be empty')) {
        _notificationsController.add(
          ChatMessage(
            from: 'system',
            content: 'Nickname cannot be empty. Please set a valid nickname.',
            date: DateTime.now(),
          ),
        );
        disconnect();
        return;
      }

      final regex = RegExp(
        r'^\|(?:(\d{4}-\d{2}-\d{2}) )?(\d{2}:\d{2}):(\d{2})\| \[(.*?)\]: (.*)$',
      );
      final match = regex.firstMatch(line);

      if (match != null) {
        final groups = [
          match.group(0),
          match.group(1),
          match.group(2),
          match.group(3),
          match.group(4),
          match.group(5),
        ];

        final message = ChatMessage.fromParsed(groups);

        if (message.isSystemMessage) {
          final shouldRender = _processServerMessage(message);
          if (shouldRender) {
            _messageController.add(message);
          }
        } else {
          _messageController.add(message);
        }
      } else {
        _logger.warning('Unexpected message format: $line');
      }
    }
  }

  bool _processServerMessage(ChatMessage message) {
    final content = message.content;

    if (content.startsWith('pong (system)')) {
      return false;
    }

    if (message.isServerMessage) {
      const sessionIdPrefix = 'Your session ID is: ';
      final prefixIndex = content.indexOf(sessionIdPrefix);
      if (prefixIndex != -1) {
        _sessionUuid = content.substring(prefixIndex + sessionIdPrefix.length);
        _logger.info('Captured session UUID: $_sessionUuid');

        if (_loginCompleter?.isCompleted == false) {
          _fetchInitialData();
        }

        return false;
      }
    }

    final isNickChange = content.contains('Your new nick is: @');

    if (isNickChange) {
      final match = RegExp(r'Your new nick is: @(.*)').firstMatch(content);
      if (match != null) {
        if (match.group(1) case final newNick?) {
          _nickChangeController.add(newNick);
        }
      }
    }

    final date = message.date;
    final isRealTime = date != null && date.isAfter(_appStartTime);

    if (isRealTime) {
      final isJoin = content.contains('joined to the party');
      final isExit = content.contains('exited from the party');
      final isNickChangeBroadcast = content.contains('is now known as @');

      if (isNickChangeBroadcast) {
        final match = RegExp(
          r'User @(.*) is now known as @(.*)',
        ).firstMatch(content);
        if (match != null) {
          final oldNick = match.group(1)!;
          final newNick = match.group(2)!;
          _currentUsers.remove(oldNick);
          if (!_currentUsers.contains(newNick)) {
            _currentUsers.add(newNick);
          }
          _usersController.add(_currentUsers.toList());
        }
      }

      if (isJoin) {
        final match = RegExp(
          r'The user @(.*) joined to the party!',
        ).firstMatch(content);
        if (match != null) {
          final joinedUser = match.group(1)!;
          if (!_currentUsers.contains(joinedUser)) {
            _currentUsers.add(joinedUser);
            _usersController.add(_currentUsers.toList());
          }
        }
        _notificationsController.add(message);
        requestChannelsList();
      } else if (isExit) {
        final match = RegExp(
          r'The user @(.*) exited from the party :\(',
        ).firstMatch(content);
        if (match != null) {
          final exitedUser = match.group(1)!;
          _currentUsers.remove(exitedUser);
          _usersController.add(_currentUsers.toList());
        }
        _notificationsController.add(message);
        requestChannelsList();
      }
    }

    return true;
  }

  Future<void> _fetchInitialData() async {
    try {
      await Future.wait([
        requestChannelsList(),
        requestUsersList(targetChannel: currentChannel),
        requestLog(dateFormat: 'date').then((logResult) {
          final lines = LineSplitter.split(logResult);
          for (final line in lines) {
            _handleIncomingData(line);
          }
        }),
      ]);
      _startKeepAlive();
      _loginCompleter?.complete();
    } catch (e, st) {
      _logger.severe('Failed to fetch initial data: $e', e, st);
      _loginCompleter?.completeError(e, st);
      disconnect();
    }
  }

  Future<Map<String, Object?>> _makeApiRequest(
    String command, {
    List<String>? args,
    Map<String, Object?>? kwargs,
    String? channel,
    bool requiresSession = false,
  }) async {
    var apiUrl = url;

    // Build the HTTP endpoint URL.
    apiUrl = apiUrl.replace(
      pathSegments: [...apiUrl.pathSegments, 'api', 'commands', command],
    );

    final requestData = <String, Object?>{};
    if (args != null) requestData['args'] = args;
    if (kwargs != null) requestData['kwargs'] = kwargs;
    if (channel != null) requestData['channel'] = channel;

    final requestBody = jsonEncode(requestData);

    _logger.fine('HTTP POST Request to $apiUrl');
    _logger.finer('Request Body: $requestBody');

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresSession) {
      if (_sessionUuid == null) {
        throw Exception(
          'Session required for $command but no session UUID is available.',
        );
      }
      headers['Client-Session'] = _sessionUuid!;
    }

    final response = await _httpClient.post(
      apiUrl,
      headers: headers,
      body: requestBody,
    );

    _logger.fine('HTTP Response from $apiUrl: Status ${response.statusCode}');
    _logger.finer('Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, Object?>;
    } else {
      throw Exception(
        'Failed API request to $apiUrl: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Requests the server version.
  Future<String> requestServerVersion() async {
    final data = await _makeApiRequest('version');
    return data['result'] as String;
  }

  /// Requests the server uptime.
  Future<String> requestServerUptime() async {
    final data = await _makeApiRequest('uptime');
    return data['result'] as String;
  }

  /// Requests information about a specific user.
  Future<String> requestWhois(String targetUsername) async {
    final data = await _makeApiRequest(
      'whois',
      args: [targetUsername],
      requiresSession: true,
    );
    return data['result'] as String;
  }

  /// Commands the server to join a new channel for this session.
  Future<void> requestJoin(String channelName) async {
    await _makeApiRequest('join', args: [channelName], requiresSession: true);
  }

  /// Requests the message history for the current channel.
  Future<String> requestLog({String? dateFormat}) async {
    final data = await _makeApiRequest(
      'log',
      kwargs: dateFormat != null ? {'date-format': dateFormat} : null,
      requiresSession: true,
    );
    return data['result'] as String;
  }

  /// Requests the list of channels from the server via HTTP API.
  Future<Map<String, int>> requestChannelsList() async {
    if (!_loggedIn) return {};

    _channelPingId++;
    try {
      final showEmptyChannels = _configuration.showEmptyChannels;
      final data = await _makeApiRequest(
        'channels',
        kwargs: showEmptyChannels ? {'all': 't'} : null,
      );
      final result = data['result'] as String;

      final currentChannels = <String, int>{};
      for (final line in LineSplitter.split(result)) {
        final match = RegExp(
          r'^#([A-Za-z0-9_\-]+): (\d+) users?$',
        ).firstMatch(line);
        if (match != null) {
          final channel = '#${match.group(1)}';
          final count = int.parse(match.group(2)!);
          currentChannels[channel] = count;
          _currentChannels[channel] = _ChannelPingData(count, _channelPingId);
        }
      }

      _currentChannels.removeWhere((k, v) => v.pingId != _channelPingId);
      final currentMap = {
        for (final entry in _currentChannels.entries)
          entry.key: entry.value.userCount,
      };
      _channelsController.add(currentMap);
      return currentMap;
    } catch (e, st) {
      _logger.warning('Failed to load channels', e, st);
      return {};
    }
  }

  /// Requests the list of users from the server via HTTP API.
  Future<List<String>> requestUsersList({required String targetChannel}) async {
    if (!_loggedIn) return [];

    try {
      final data = await _makeApiRequest('users', channel: targetChannel);
      final result = data['result'] as String;

      final usersString = result.replaceFirst('users: ', '');
      final usersList = <String>[
        for (final user in usersString.split(','))
          if (user.isNotEmpty) user.trim(),
      ];

      if (_loggedIn &&
          targetChannel == _currentChannel &&
          !usersList.contains(nickname)) {
        usersList.add(nickname);
      }

      _currentUsers.clear();
      _currentUsers.addAll(usersList);
      _usersController.add(_currentUsers.toList());
      return _currentUsers.toList();
    } catch (e, st) {
      _logger.warning('Failed to load users', e, st);
      return [];
    }
  }

  void _startKeepAlive() {
    if (_isDisposed) return;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_loggedIn && _channel != null) {
        sendMessage('/ping system');
        requestChannelsList();
        requestUsersList(targetChannel: currentChannel);
      }
    });
  }

  void _handleConnectionFailure(Object error) {
    if (!_isReconnecting) _handleDisconnect();
    if (_loginCompleter?.isCompleted == false) {
      _loginCompleter?.completeError(error);
    }
    _loginCompleter = null;
  }

  void _handleDisconnect() {
    final wasLoggedIn = _loggedIn;
    _loggedIn = false;
    _currentChannels.clear();
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _connectionStateController.add(false);
    _stateController.add(state);

    if (wasLoggedIn && !_isReconnecting) {
      _notificationsController.add(
        ChatMessage(
          from: 'system',
          content: 'Connection lost. Attempting to reconnect...',
          date: DateTime.now(),
        ),
      );

      _reconnect();
    }
  }

  Future<void> _reconnect() async {
    if (_isReconnecting || _isAppInBackground) return;
    _isReconnecting = true;
    _logger.warning(
      'Lost connection. Attempting to reconnect (max 3 times)...',
    );

    const r = RetryOptions(maxAttempts: 3);
    try {
      await r.retry(
        () async {
          if (_isAppInBackground) {
            _logger.info('App in background, aborting reconnect loop.');
            throw Exception('App went to background');
          }
          _logger.info('Attempting to reconnect...');
          if (_loggedIn) return;
          await connect();
          if (!_loggedIn) {
            throw Exception('Failed to connect or log in');
          }
          _logger.info('Reconnected successfully.');
        },
        retryIf: (e) {
          if (_isAppInBackground) return false;
          _logger.warning('Reconnection attempt failed: $e');
          return !_loggedIn;
        },
      );
    } catch (exception, stackTrace) {
      _logger.severe('Reconnection failed completely', exception, stackTrace);
      _loggedIn = false;
      _notificationsController.add(
        ChatMessage(
          from: 'system',
          content:
              'Failed to connect. Please try again later or reach out to the server administrator.',
          date: DateTime.now(),
        ),
      );
      disconnect();
    } finally {
      _isReconnecting = false;
      _stateController.add(state);
    }
  }

  /// Cleans up all resources used by the service.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
    _notificationsController.close();
    _usersController.close();
    _connectionStateController.close();
    _nickChangeController.close();
    _channelsController.close();
    _currentChannelController.close();
    _stateController.close();
  }

  @visibleForTesting
  static Uri deriveWebSocketUrl(Uri url) {
    if (url.scheme == 'ws' || url.scheme == 'wss') {
      return url.replace(pathSegments: [...url.pathSegments, 'ws']);
    }

    if (url.scheme != 'http' && url.scheme != 'https') {
      throw ArgumentError(
        'URL must start with http://, https://, ws:// or wss://',
      );
    }

    final scheme = url.scheme == 'https' ? 'wss' : 'ws';

    return url.replace(
      scheme: scheme,
      pathSegments: [...url.pathSegments, 'ws'],
    );
  }
}

class _ChannelPingData {
  final int userCount;
  final int pingId;

  _ChannelPingData(this.userCount, this.pingId);
}
