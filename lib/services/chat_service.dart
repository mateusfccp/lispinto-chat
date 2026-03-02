import 'dart:async';
import 'dart:convert';

import 'package:lispinto_chat/models/chat_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_factory.dart';

/// A service that manages the server connection and messages processing.
interface class ChatService {
  /// Creates a [ChatService].
  ChatService({
    required this.serverUrl,
    required this.nickname,
    required this.appVersion,
    this.initialChannel,
  });

  /// The WebSocket server URL to connect to.
  final Uri serverUrl;

  /// The nickname to use when logging in to the chat server.
  final String nickname;

  /// The version of the app, used for the User-Agent header.
  final String appVersion;

  /// The initial channel to join on connection.
  final String? initialChannel;

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

  final List<String> _currentUsers = [];

  final Map<String, _ChannelPingData> _currentChannels = {};
  int _channelPingId = 0;

  /// Whether to show empty channels in the channel list.
  bool showEmptyChannels = false;

  /// Connects to the chat server and starts listening for messages.
  ///
  /// If already connected, it will first disconnect and then reconnect.
  /// [mockChannel] can be provided for testing purposes.
  void connect({WebSocketChannel? mockChannel}) {
    disconnect();

    try {
      var connectionUri = serverUrl;
      if (initialChannel != null) {
        final channelName = initialChannel!.startsWith('#')
            ? initialChannel!.substring(1)
            : initialChannel!;
        connectionUri = connectionUri.replace(
          queryParameters: {...connectionUri.queryParameters, 'channel': channelName},
        );
      }

      final channel = _channel =
          mockChannel ?? createWebSocketChannel(connectionUri, appVersion);

      channel.ready.catchError((_) {
        _handleDisconnect();
      });

      _connectionStateController.add(true);

      _subscription = channel.stream.listen(
        (data) {
          _handleIncomingData(data.toString());
        },
        onDone: _handleDisconnect,
        onError: (error) => _handleDisconnect(),
      );
    } catch (error) {
      _handleDisconnect();
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
        channel.sink.add(nickname);
        _loggedIn = true;
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
        final rawMessage = ChatMessage(from: 'unknown', content: line);
        final shouldRender = _processServerMessage(rawMessage);
        if (shouldRender) {
          _messageController.add(rawMessage);
        }
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

    if (message.from == 'unknown') {
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
        (message.from == 'server' ||
            message.from == '@server' ||
            message.from == 'unknown')) {
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
        return false;
      }
    } else if (isUsersListResponse) {
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

  void _handleDisconnect() {
    _loggedIn = false;
    _currentChannels.clear();
    _keepAliveTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _connectionStateController.add(false);
    _notificationsController.add(
      ChatMessage(
        from: 'system',
        content: 'Connection lost. Attempting to reconnect...',
        date: DateTime.now(),
      ),
    );

    // Attempt reconnect after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!_loggedIn && _channel == null) {
        connect();
      }
    });
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
