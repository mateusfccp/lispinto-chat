import 'dart:async';
import 'dart:convert';

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
    required this.serverUrl,
    required this.nickname,
    this.initialChannel,
    required this.webSocketFactory,
    Logger? logger,
  }) : _logger = logger ?? Logger('ChatService');

  /// The WebSocket server URL to connect to.
  final Uri serverUrl;

  /// The nickname to use when logging in to the chat server.
  final String nickname;

  /// The initial channel to join on connection.
  final String? initialChannel;

  /// A factory to create the [WebSocketChannel].
  final WebSocketFactory webSocketFactory;

  final Logger _logger;

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

  /// A stream of the current connection state.
  ///
  /// True if connected, false if disconnected. The UI can listen to this stream
  /// to update the connection status indicator and trigger reconnection
  /// attempts.
  Stream<bool> get connectionState => _connectionStateController.stream;
  final _connectionStateController = StreamController<bool>.broadcast();

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

  /// The current connection state of the client.
  ChatConnectionState get state {
    if (_isReconnecting) return ChatConnectionState.reconnecting;
    if (_loginCompleter != null) return ChatConnectionState.connecting;
    if (_channel == null) return ChatConnectionState.disconnected;
    if (_loggedIn) return ChatConnectionState.loggedIn;
    return ChatConnectionState.connected;
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

  final List<String> _currentUsers = [];

  final Map<String, _ChannelPingData> _currentChannels = {};
  int _channelPingId = 0;

  /// Whether to show empty channels in the channel list.
  bool showEmptyChannels = false;

  /// Connects to the chat server and starts listening for messages.
  ///
  /// If already connected, it will first disconnect and then reconnect.
  /// [mockChannel] can be provided for testing purposes.
  Future<void> connect({WebSocketChannel? mockChannel}) async {
    if (isLoggedIn) return;
    if (_loginCompleter != null) return _loginCompleter!.future;

    _logger.info('Connecting to $serverUrl as $nickname...');
    disconnect();
    _loginCompleter = Completer<void>();

    try {
      var connectionUri = serverUrl;
      if (initialChannel != null) {
        final channelName = initialChannel!.startsWith('#')
            ? initialChannel!.substring(1)
            : initialChannel!;
        connectionUri = connectionUri.replace(
          queryParameters: {
            ...connectionUri.queryParameters,
            'channel': channelName,
          },
        );
      }

      final channel = _channel =
          mockChannel ?? webSocketFactory.create(connectionUri);

      // We don't await channel.ready here because we want to start listening
      // immediately. The login completer will handle waiting for full success.
      channel.ready
          .then((_) {
            _logger.info('WebSocket channel ready.');
            _connectionStateController.add(true);
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

      return _loginCompleter!.future
          .then((_) => _loginCompleter = null)
          .catchError((exception, stackTrace) {
            _logger.severe('Login completer error', exception, stackTrace);
            _loginCompleter = null;
            throw exception;
          });
    } catch (error) {
      _handleDisconnect();
      if (_loginCompleter?.isCompleted == false) {
        _loginCompleter?.completeError(error);
      }
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
    _connectionStateController.add(false);

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
    final channel = _channel;
    if (channel == null) return;

    final lines = LineSplitter.split(data);
    for (final line in lines) {
      if (line.isEmpty) continue;

      if (!_loggedIn && line.contains('> Type your username:')) {
        _logger.info('Successfully logged in as $nickname.');
        channel.sink.add(nickname);
        _loggedIn = true;
        if (_loginCompleter?.isCompleted == false) {
          _loginCompleter?.complete();
        }
        channel.sink.add('/log :depth 100 :date-format date');
        _startKeepAlive();
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
        throw FormatException('Unexpected message format: $line');
      }
    }
  }

  bool _processServerMessage(ChatMessage message) {
    final content = message.content;

    final isJoin = content.contains('joined to the party');
    final isExit = content.contains('exited from the party');
    final isNickChange = content.contains('Your new nick is: @');
    final isNickChangeBroadcast = content.contains('is now known as @');
    final isSystemMessage =
        isJoin || isExit || isNickChange || isNickChangeBroadcast;
    final isUsersListResponse = content.startsWith('users: ');

    if (message.isServerMessage) {
      final channelCountMatch = RegExp(
        r'^#([A-Za-z0-9_\-]+): (\d+) users?$',
      ).firstMatch(content);
      if (channelCountMatch != null) {
        final channel = '#${channelCountMatch.group(1)}';
        final count = int.parse(channelCountMatch.group(2)!);
        _currentChannels[channel] = _ChannelPingData(count, _channelPingId);

        final currentMap = {
          for (final entry in _currentChannels.entries)
            entry.key: entry.value.userCount,
        };
        _channelsController.add(currentMap);

        return false; // Swallow channel list pings
      }
    }

    if (content == 'channels:' &&
        (message.from == 'server' || message.from == '@server')) {
      return false;
    }

    if (isSystemMessage) {
      if (isNickChange) {
        final match = RegExp(r'Your new nick is: @(.*)').firstMatch(content);
        if (match != null) {
          if (match.group(1) case final newNick?) {
            _nickChangeController.add(newNick);
            _notificationsController.add(
              ChatMessage(
                from: 'system',
                content: 'Your nickname has been changed to $newNick.',
                date: DateTime.now(),
              ),
            );
          }
        }
      } else if (isNickChangeBroadcast) {
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
        return false;
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
        return false;
      }
    }

    if (isUsersListResponse) {
      final usersString = content.replaceFirst('users: ', '');
      final usersList = [
        for (final user in usersString.split(','))
          if (user.isNotEmpty) user.trim(),
      ];

      _currentUsers.clear();
      _currentUsers.addAll(usersList);
      _usersController.add(_currentUsers.toList());
      return false;
    }
    return true;
  }

  void _requestUserList() {
    if (_loggedIn && _channel != null) {
      sendMessage('/users');
    }
  }

  /// Requests the list of channels from the server.
  void requestChannelsList() {
    if (_loggedIn && _channel != null) {
      _channelPingId++;
      if (showEmptyChannels) {
        sendMessage('/channels :all t');
      } else {
        sendMessage('/channels');
      }

      // Give the server up to 1 second to send all individual channel messages,
      // and purge whatever channels were not seen.
      Timer(const Duration(seconds: 1), () {
        _currentChannels.removeWhere((k, v) => v.pingId != _channelPingId);
        final currentMap = {
          for (final entry in _currentChannels.entries)
            entry.key: entry.value.userCount,
        };
        _channelsController.add(currentMap);
      });
    }
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      requestChannelsList();
    });
    _requestUserList(); // Initial fetch for users
    requestChannelsList(); // Initial fetch for channels
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
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _connectionStateController.add(false);

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
    if (_isReconnecting) return;
    _isReconnecting = true;
    _logger.warning(
      'Lost connection. Attempting to reconnect (max 3 times)...',
    );

    const r = RetryOptions(maxAttempts: 3);
    try {
      await r.retry(
        () async {
          _logger.info('Attempting to reconnect...');
          if (_loggedIn) return;
          await connect();
          if (!_loggedIn) {
            throw Exception('Failed to connect or log in');
          }
          _logger.info('Reconnected successfully.');
        },
        retryIf: (e) {
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
    }
  }

  /// Cleans up all resources used by the service.
  void dispose() {
    disconnect();
    _messageController.close();
    _notificationsController.close();
    _usersController.close();
    _connectionStateController.close();
    _nickChangeController.close();
    _channelsController.close();
  }
}

class _ChannelPingData {
  final int userCount;
  final int pingId;

  _ChannelPingData(this.userCount, this.pingId);
}
