import 'dart:async';
import 'dart:convert';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'websocket_factory.dart';

/// A service that manages the server connection and messages processing.
final class ChatService {
  /// Creates a [ChatService].
  ChatService({
    required this.serverUrl,
    required this.nickname,
    required this.appVersion,
  });

  /// The WebSocket server URL to connect to.
  final Uri serverUrl;

  /// The nickname to use when logging in to the chat server.
  final String nickname;

  /// The version of the app, used for the User-Agent header.
  final String appVersion;

  /// A stream of incoming chat messages to be displayed in the UI.
  Stream<ChatMessage> get messages => _messageController.stream;
  final _messageController = StreamController<ChatMessage>.broadcast();

  /// A stream of important notifications to be shown as local notifications.
  Stream<String> get notifications => _notificationsController.stream;
  final _notificationsController = StreamController<String>.broadcast();

  /// A stream of the current online users list to be displayed in the UI.
  Stream<List<String>> get users => _usersController.stream;
  final _usersController = StreamController<List<String>>.broadcast();

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
  int _backgroundRequestsPending = 0;
  bool _loggedIn = false;

  /// Connects to the chat server and starts listening for messages.
  ///
  /// If already connected, it will first disconnect and then reconnect.
  void connect() {
    disconnect();

    try {
      final channel = _channel = createWebSocketChannel(serverUrl, appVersion);

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
        _notificationsController.add('Failed to login: name cannot be empty');
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
          final shouldRender = _processServerMessage(message.content);
          if (shouldRender) {
            _messageController.add(message);
          }
        } else {
          _messageController.add(message);
        }
      } else {
        final rawMessage = ChatMessage(from: 'unknown', content: line);
        final shouldRender = _processServerMessage(rawMessage.content);
        if (shouldRender) {
          _messageController.add(rawMessage);
        }
      }
    }
  }

  bool _processServerMessage(String content) {
    final isJoin = content.contains('joined to the party');
    final isExit = content.contains('exited from the party');
    final isNickChange = content.contains('Your new nick is');
    final isNowKnownAs = content.contains('is now known as');
    final isSystemMessage = isJoin || isExit || isNickChange || isNowKnownAs;
    final isUsersListResponse = content.startsWith('users: ');

    if (isSystemMessage) {
      if (isNickChange) {
        final match = RegExp(r'Your new nick is: @(.*)').firstMatch(content);
        if (match != null) {
          if (match.group(1) case final newNick?) {
            _nickChangeController.add(newNick);
            _notificationsController.add('Successfully changed nick to: $newNick');
          }
        }
      }

      _requestUserList(isBackground: true);
      if (isJoin || isExit || isNowKnownAs) {
        _notificationsController.add(content);
        return false;
      }
    } else if (isUsersListResponse) {
      final usersString = content.replaceFirst('users: ', '');
      final usersList = [
        for (final user in usersString.split(','))
          if (user.isNotEmpty) user.trim(),
      ];

      _usersController.add(usersList);

      if (_backgroundRequestsPending > 0) {
        _backgroundRequestsPending--;
        return false; // Swallow background updates
      }
    }
    return true;
  }

  void _requestUserList({bool isBackground = false}) {
    if (_loggedIn && _channel != null) {
      if (isBackground) {
        _backgroundRequestsPending++;
      }
      sendMessage('/users');
    }
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _requestUserList(isBackground: true);
    });
    _requestUserList(isBackground: true); // Initial fetch
  }

  void _handleDisconnect() {
    _loggedIn = false;
    _keepAliveTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _connectionStateController.add(false);
    _notificationsController.add('Disconnected from server.');

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
  }
}
