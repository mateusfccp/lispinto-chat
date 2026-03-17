import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/web_notifications.dart';
import 'package:logging/logging.dart';

/// A provider that manages chat state.
///
/// It listens to the ChatService streams and updates the UI accordingly. It
/// also handles sending messages and showing local notifications for important
/// events.
class ChatProvider with ChangeNotifier {
  /// Creates a [ChatProvider] with the given user configuration.
  ChatProvider(
    this.configuration, {
    required this.appVersion,
    required FlutterLocalNotificationsPlugin localNotifications,
    required ChatService chatService,
  }) : _localNotifications = localNotifications,
       _chatService = chatService {
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        _chatService.setAppBackgroundState(false);
        if (!_isConnected && configuration.autoConnect) {
          autoConnect();
        }
      },
      onPause: () => _chatService.setAppBackgroundState(true),
      onInactive: () => _chatService.setAppBackgroundState(true),
      onDetach: () => _chatService.setAppBackgroundState(true),
    );
    _initializeNotifications();
    _initializeService();

    if (configuration.autoConnect && configuration.hasNickname) {
      autoConnect();
    }
  }

  late final AppLifecycleListener _lifecycleListener;
  bool _isDisposed = false;

  /// The user configuration.
  final UserConfiguration configuration;

  /// The version of the app used for the User-Agent header.
  final String appVersion;

  static final _logger = Logger('ChatProvider');
  final ChatService _chatService;

  /// The list of chat messages to display in the UI.
  UnmodifiableListView<ChatMessage> get messages {
    return UnmodifiableListView(_messages);
  }

  final List<ChatMessage> _messages = [];

  /// A future containing the result of the current users list fetch.
  ResultFuture<List<String>>? get usersFuture => _usersFuture;
  ResultFuture<List<String>>? _usersFuture;

  /// A future containing the result of the current channels list fetch.
  ResultFuture<Map<String, int>>? get channelsFuture => _channelsFuture;
  ResultFuture<Map<String, int>>? _channelsFuture;

  /// Whether the client is currently connected to the chat server.
  bool get isConnected => _isConnected;
  bool _isConnected = false;

  /// Whether the client is currently logged in to the chat server.
  bool get isLoggedIn => _chatService.isLoggedIn;

  /// The current connection state of the chat server.
  ChatConnectionState get connectionState => _chatService.state;

  /// Whether the client is currently in the process of connecting.
  bool get isConnecting => _chatService.isConnecting;

  /// The currently active channel.
  String get activeChannel => _chatService.currentChannel;

  /// Whether the current channel is private.
  bool get isCurrentChannelPrivate => _isCurrentChannelPrivate;
  bool _isCurrentChannelPrivate = false;

  /// The nickname of the current DM target, or null if not in DM mode.
  String? get currentDmNickname => _currentDmUser;
  String? _currentDmUser;

  /// The current search query being filtered on the server.
  String get searchQuery => _searchQuery;
  String _searchQuery = '';

  /// A stream of important notifications to show as local notifications.
  Stream<String> get notifications {
    return _chatService.notifications.map(
      (notification) => notification.content,
    );
  }

  final FlutterLocalNotificationsPlugin _localNotifications;

  DateTime _lastNotificationTimestamp = DateTime.now();

  final List<StreamSubscription<Object?>> _subscriptions = [];

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
      _chatService.currentChannelStream.listen((channel) => notifyListeners()),
    );
    _subscriptions.add(
      _chatService.messages.listen((message) {
        _messages.add(message);

        if (message.from == '@server') {
          final privateStatus = RegExp(
            r'Private mode for (#.+) is currently (ON|OFF)',
          ).firstMatch(message.content);
          if (privateStatus != null) {
            final targetChannel = privateStatus.group(1);
            if (targetChannel == activeChannel) {
              _isCurrentChannelPrivate = privateStatus.group(2) == 'ON';
            }
          }

          final privateActivated = RegExp(
            r'Private mode was (de|)activated by @',
          ).firstMatch(message.content);
          if (privateActivated != null) {
            final isDeactivated = privateActivated.group(1) == 'de';
            _isCurrentChannelPrivate = !isDeactivated;
          }
        }

        notifyListeners();

        if (configuration.mentionNotificationsEnabled &&
            configuration.hasNickname &&
            message.from != configuration.nickname &&
            !message.isSystemMessage &&
            hasMention(message.content, configuration.nickname)) {
          final timestamp = message.date ?? DateTime.now();
          if (timestamp.isAfter(_lastNotificationTimestamp)) {
            _lastNotificationTimestamp = timestamp;
            _triggerDisplayNotification('Mention from ${message.from}');
          }
        }
      }),
    );

    _subscriptions.add(
      _chatService.users.listen((users) {
        _usersFuture = ResultFuture(Future.value(users));
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _chatService.channels.listen((channels) {
        final currentUsersCount =
            _usersFuture?.result?.asValue?.value.length ?? 0;
        final displayActiveChannel = activeChannel.startsWith('#')
            ? activeChannel
            : '#$activeChannel';
        final channelMap = {
          displayActiveChannel: currentUsersCount,
          ...channels,
        };
        _channelsFuture = ResultFuture(Future.value(channelMap));
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.stateStream.listen((state) {
        _isConnected = _chatService.isConnected;

        if (state == ChatConnectionState.loggedIn) {
          // Send /join to ensure the connection gets associated with the currently
          // expected channel on reconnect (or login defaults).
          _chatService.sendMessage('/join $activeChannel');
          _fetchUsersAndChannelsList();
        }

        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.nickChanges.listen((newNick) {
        configuration.nickname = newNick;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _chatService.notifications.listen((notification) {
        if (configuration.pushNotificationsEnabled) {
          if (notification.date case final date?
              when date.isAfter(_lastNotificationTimestamp)) {
            _lastNotificationTimestamp = date;
            _triggerDisplayNotification(notification.content);
          }
        }
      }),
    );
  }

  Future<void> _triggerDisplayNotification(String body) async {
    final title = 'Lispinto Chat';

    if (kIsWeb) {
      showWebNotification(title, body);
    } else {
      const details = NotificationDetails(macOS: DarwinNotificationDetails());

      await _localNotifications.show(
        id: body.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
      );
    }
  }

  /// Updates the connection configuration dynamically.
  ///
  /// If [newNickname] differs from the current nickname, it sends a command to
  /// the server to change it. If [newServerUrl] differs, it completely
  /// disconnects and reconnects the underlying WebSocket to the new address.
  Future<void> updateConfiguration(UserConfiguration newConfiguration) async {
    final oldServerUrl = configuration.serverUrl;
    final newServerUrl = newConfiguration.serverUrl;
    final oldNickname = configuration.nickname;
    final newNickname = newConfiguration.nickname;

    configuration.updateWith(newConfiguration);

    _logger.info('Updating configuration.');

    // If the server URL changed, or if we are not connected, we must disconnect
    // and reconnect entirely.
    if (newServerUrl != oldServerUrl || !_isConnected) {
      _chatService.disconnect();

      _chatService.url = Uri.parse(newServerUrl);
      _chatService.nickname = newNickname;

      _messages.clear();
      _usersFuture = null;
      _channelsFuture = null;
      _isConnected = false;
      _currentDmUser = null;
      _chatService.currentChannel = 'general';
      _isCurrentChannelPrivate = false;

      _fetchUsersAndChannelsList();
    }
    // If only the nickname or settings changed, sync them.
    else {
      if (_isConnected) {
        _fetchUsersAndChannelsList();
      }
      if (newNickname != oldNickname && _isConnected) {
        _chatService.sendMessage('/nick $newNickname');
      }
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
          final String targetUser = split[1].trim();
          final currentUsers = _usersFuture?.result?.asValue?.value ?? [];
          if (targetUser.isNotEmpty && currentUsers.contains(targetUser)) {
            setDmMode(targetUser);
          }
        }
      } else if (message.startsWith('/join ')) {
        if (message.split(' ') case final split when split.length > 1) {
          final targetChannel = split[1].trim();
          joinChannel(targetChannel);
          return;
        }
      } else if (message.startsWith('/private')) {
        final split = message.split(' ');
        if (split.length > 1) {
          final arg = split[1].trim();
          if (arg == 'on') {
            setPrivateChannel(true);
            return;
          } else if (arg == 'off') {
            setPrivateChannel(false);
            return;
          }
        } else {
          setPrivateChannel(!_isCurrentChannelPrivate);
          return;
        }
      }

      _chatService.sendMessage(message);
    }
  }

  /// Sets the current DM mode to the specified [user].
  ///
  /// If [user] is null, DM mode is disabled and messages will be sent to the
  /// public chat.
  void setDmMode(String? user) {
    _currentDmUser = user;
    notifyListeners();
  }

  /// Joins a new channel.
  ///
  /// If the specified [channel] is the same as the current one, this method
  /// does nothing.
  void joinChannel(String channel) {
    if (activeChannel == channel) return;

    _currentDmUser = null;
    _searchQuery = '';
    _isCurrentChannelPrivate = false;
    _messages.clear();
    _chatService.currentChannel = channel;
    configuration.lastChannel = channel.replaceFirst('#', '');
    notifyListeners();

    _chatService.sendMessage('/join $channel');
    _chatService.sendMessage('/private status');
    _chatService.sendMessage('/log :depth 100 :date-format date');

    _fetchUsersAndChannelsList();
  }

  Future<void> _fetchUsersAndChannelsList() async {
    final usersFuture = ResultFuture(
      _chatService.requestUsersList(targetChannel: activeChannel),
    );
    _usersFuture = usersFuture;

    final channelsFuture = ResultFuture(_chatService.requestChannelsList());
    _channelsFuture = channelsFuture;

    notifyListeners();

    _notifyWhenComplete(usersFuture);
    _notifyWhenComplete(channelsFuture);
  }

  /// Sets whether the current channel is private.
  void setPrivateChannel(bool isPrivate) {
    if (isPrivate) {
      _chatService.sendMessage('/private on');
      _isCurrentChannelPrivate = true;
    } else {
      _chatService.sendMessage('/private off');
      _isCurrentChannelPrivate = false;
    }
    notifyListeners();
  }

  /// Triggers a search on the backend and updates the search query.
  void search(String query) {
    if (_searchQuery == query) return;

    _searchQuery = query;
    _messages.clear();
    notifyListeners();

    if (query.trim().isEmpty) {
      _chatService.sendMessage('/log :depth 100 :date-format date');
    } else {
      _chatService.sendMessage('/search "$query"');
    }
  }

  /// Clears the chat messages from the UI.
  ///
  /// This does not affect the server-side history, and new messages will still
  /// arrive as normal. This is purely a client-side UI action.
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Connects to the chat server explicitly.
  Future<void> connect() async {
    await _chatService.connect();
    _isConnected = _chatService.isConnected;
    notifyListeners();
  }

  /// Attempts to connect to the server without propagating errors upwards.
  ///
  /// Useful for background initialization and auto-reconnection.
  void autoConnect() async {
    if (connectionState == ChatConnectionState.disconnected) {
      try {
        _logger.info('Auto-connecting in background...');
        await connect();
      } catch (exception, stackTrace) {
        // Background connection errors are ignored here since the service
        // already manages its own notification or reconnection loops for silent
        // failures.
        _logger.warning(
          'Auto-connect failed silently: $exception',
          exception,
          stackTrace,
        );
      }
    }
  }

  /// Disconnects from the chat server explicitly.
  void disconnect() => _chatService.disconnect();

  @override
  void dispose() {
    _isDisposed = true;
    _lifecycleListener.dispose();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _notifyWhenComplete<T>(Future<T> future) {
    return future.then((value) {
      if (_isDisposed) return;
      notifyListeners();
    });
  }
}
