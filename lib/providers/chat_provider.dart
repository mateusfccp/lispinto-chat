import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/web_notifications.dart';

/// A provider that manages chat state.
///
/// It listens to the ChatService streams and updates the UI accordingly. It
/// also handles sending messages and showing local notifications for important
/// events.
final class ChatProvider with ChangeNotifier {
  /// Creates a [ChatProvider] with the given user configuration.
  ChatProvider(
    this.configuration, {
    required this.appVersion,
    FlutterLocalNotificationsPlugin? localNotifications,
    ChatService? chatService,
  })  : _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin(),
        _chatService = chatService ?? ChatService(
          serverUrl: Uri.parse(configuration.serverUrl),
          nickname: configuration.nickname,
          appVersion: appVersion,
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

  /// The version of the app used for the User-Agent header.
  final String appVersion;

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

  /// The nickname of the current DM target, or null if not in DM mode.
  String? get currentDmNickname => _currentDmUser;
  String? _currentDmUser;

  /// A stream of important notifications to show as local notifications.
  Stream<String> get notifications => _chatService.notifications;

  final FlutterLocalNotificationsPlugin _localNotifications;

  // Track stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  Future<void> _initializeNotifications() async {
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(macOS: darwinSettings);

    await _localNotifications.initialize(settings: settings);
  }

  /// Requests permissions for local notifications.
  /// Returns whether the permissions were granted.
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      return await requestWebNotificationPermissions();
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await _localNotifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  /// Checks if [content] contains a mention for [nickname] strictly.
  @visibleForTesting
  static bool hasMention(String content, String nickname) {
    if (nickname.isEmpty) return false;
    final mentionRegExp = RegExp(
      r'@' + RegExp.escape(nickname) + r'(?=[^\w]|$)',
      caseSensitive: false,
    );
    return mentionRegExp.hasMatch(content);
  }

  void _initializeService() {
    _subscriptions.add(
      _chatService.messages.listen((message) {
        _messages.add(message);
        notifyListeners();

        if (configuration.mentionNotificationsEnabled &&
            configuration.hasNickname &&
            message.from != configuration.nickname &&
            hasMention(message.content, configuration.nickname)) {
          _triggerDisplayNotification(
            'Mention from ${message.from}',
            message.content,
          );
        }
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
        if (configuration.pushNotificationsEnabled) {
          _triggerDisplayNotification('Lisp Chat', notification);
        }
      }),
    );

    if (configuration.hasNickname) {
      _chatService.connect();
    }
  }

  Future<void> _triggerDisplayNotification(String title, String body) async {
    if (kIsWeb) {
      showWebNotification(title, body);
      return;
    }

    const details = NotificationDetails(macOS: DarwinNotificationDetails());

    await _localNotifications.show(
      id: body.hashCode,
      title: title,
      body: body,
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
        appVersion: appVersion,
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
