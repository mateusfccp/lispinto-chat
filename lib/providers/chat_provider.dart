import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';
import '../core/user_configuration.dart';

/// A provider that manages chat state.
///
/// It listens to the ChatService streams and updates the UI accordingly. It
/// also handles sending messages and showing local notifications for important
/// events.
final class ChatProvider with ChangeNotifier {
  /// Creates a [ChatProvider] with the given user configuration.
  ChatProvider(this.configuration)
    : _chatService = ChatService(
        serverUrl: Uri.parse(configuration.serverUrl),
        nickname: configuration.nickname,
      ) {
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!_isConnected) {
          _chatService.connect();
        }
      },
    );
    _initializeNotifications();
    _initializeService();
  }

  late final AppLifecycleListener _lifecycleListener;

  /// The user configuration.
  final UserConfiguration configuration;

  /// The chat service that handles WebSocket communication.
  ChatService _chatService;

  /// The list of chat messages to display in the UI.
  UnmodifiableListView<ChatMessage> get messages {
    return UnmodifiableListView(_messages);
  }

  final _messages = <ChatMessage>[];

  /// The list of online users to display in the UI.
  UnmodifiableListView<String> get onlineUsers {
    return UnmodifiableListView(_onlineUsers);
  }

  List<String> _onlineUsers = [];

  /// Whether the client is currently connected to the chat server.
  bool get isConnected => _isConnected;
  bool _isConnected = false;

  /// The username of the current DM target, or null if not in DM mode.
  String? get currentDmUser => _currentDmUser;
  String? _currentDmUser;

  /// A stream of important notifications to show as local notifications.
  Stream<String> get notifications => _chatService.notifications;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Track stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(settings: settings);
  }

  void _initializeService() {
    _subscriptions.add(
      _chatService.messages.listen((message) {
        _messages.add(message);
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.users.listen((users) {
        _onlineUsers = users;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.connectionState.listen((connected) {
        _isConnected = connected;
        // On reconnect, we might get a flood of history. We could clear messages here
        // but it's better to just let the server send the recent history if the connection drops.
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.nickChanges.listen((newNick) {
        configuration.setNickname(newNick);
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.notifications.listen((notification) {
        _showLocalNotification(notification);
      }),
    );

    _chatService.connect();
  }

  Future<void> _showLocalNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'lisp_chat_channel',
      'Lisp Chat Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      id: 0,
      title: 'Lisp Chat',
      body: message,
      notificationDetails: details,
    );
  }

  /// Updates the connection configuration dynamically.
  ///
  /// If [newNickname] differs from the current nickname, it sends a command to
  /// the server to change it. If [newServerUrl] differs, it completely
  /// disconnects and reconnects the underlying WebSocket to the new address.
  Future<void> updateConfiguration(
    String newNickname,
    String newServerUrl,
  ) async {
    final oldServerUrl = configuration.serverUrl;
    final oldNickname = configuration.nickname;

    await configuration.setNickname(newNickname);
    await configuration.setServerUrl(newServerUrl);

    // If the server URL changed, or if we are not connected, we must create a new ChatService and reconnect entirely.
    if (newServerUrl != oldServerUrl || !_isConnected) {
      _chatService.dispose();

      _chatService = ChatService(
        serverUrl: Uri.parse(newServerUrl),
        nickname: newNickname,
      );

      _messages.clear();
      _onlineUsers.clear();
      _isConnected = false;
      _currentDmUser = null;

      _initializeService();
    }
    // If only the nickname changed, just whisper the command to the existing connection.
    else if (newNickname != oldNickname && _isConnected) {
      _chatService.sendMessage('/nick $newNickname');
    }

    notifyListeners();
  }

  /// Sends a [message] to the chat server.
  void sendMessage(String message) {
    if (message.trim().isEmpty) return;

    // Auto-prefix with /dm if in dm mode AND user didn't manually type a command
    if (_currentDmUser != null && !message.startsWith('/')) {
      _chatService.sendMessage('/dm $_currentDmUser $message');
    } else {
      // Check if user is manually entering a DM mode
      if (message.startsWith('/dm ')) {
        if (message.split(' ') case final split when split.length > 1) {
          final targetUser = split[1].trim();
          if (onlineUsers.contains(targetUser)) {
            setDmMode(targetUser);
          }
        }
      }

      _chatService.sendMessage(message);
    }
  }

  /// Sets the current DM mode to the specified [user].
  ///
  /// If [user] is null, DM mode is disabled and messages will be sent to the
  /// main chat.
  void setDmMode(String? user) {
    _currentDmUser = user;
    notifyListeners();
  }

  /// Clears the chat messages from the UI.
  ///
  /// This does not affect the server-side history, and new messages will still
  /// arrive as normal. This is purely a client-side UI action.
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _chatService.dispose();
    super.dispose();
  }
}
