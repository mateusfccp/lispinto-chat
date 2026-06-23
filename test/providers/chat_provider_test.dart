import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/websocket_factory.dart';
import 'package:mockito/mockito.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }
}

class FakeUserConfiguration extends Fake implements UserConfiguration {
  @override
  String get nickname => _nickname;
  String _nickname = 'tester';

  @override
  set nickname(String value) => _nickname = value;

  @override
  bool get hasNickname => _nickname.isNotEmpty;

  @override
  String get serverUrl => 'http://localhost:8080';

  @override
  bool get autoConnect => _autoConnect;
  bool _autoConnect = false;

  @override
  set autoConnect(bool value) => _autoConnect = value;

  @override
  bool get mentionNotificationsEnabled => true;

  @override
  bool get pushNotificationsEnabled => true;

  @override
  String get lastChannel => 'general';

  @override
  set lastChannel(String value) {}

  @override
  bool get showImagePreviews => true;

  @override
  bool get showEmptyChannels => true;
}

class FakeChatService extends Fake implements ChatService {
  final List<String> sentMessages = [];

  final _currentChannelController = StreamController<String>.broadcast();

  @override
  WebSocketFactory get webSocketFactory =>
      const DefaultWebSocketFactory('test');

  @override
  String get currentChannel => _currentChannel;

  @override
  set currentChannel(String value) {
    _currentChannel = value;
    _currentChannelController.add(value);
  }

  String _currentChannel = '#general';

  @override
  Stream<String> get currentChannelStream => _currentChannelController.stream;

  @override
  Stream<ChatMessage> get messages => const Stream.empty();

  @override
  Stream<ChatMessage> get notifications => const Stream.empty();

  @override
  Stream<List<String>> get users => const Stream.empty();

  @override
  Stream<Map<String, int>> get channels => const Stream.empty();

  @override
  Stream<bool> get connectionState => _connectionStateController.stream;
  final _connectionStateController = StreamController<bool>.broadcast();

  @override
  Stream<ChatConnectionState> get stateStream => _stateController.stream;
  final _stateController = StreamController<ChatConnectionState>.broadcast();

  @override
  ChatConnectionState get state {
    if (!_isConnected) return ChatConnectionState.disconnected;
    if (_isLoggedIn) return ChatConnectionState.loggedIn;
    return ChatConnectionState.connected;
  }

  @override
  bool get isLoggedIn => state == ChatConnectionState.loggedIn;

  @override
  bool get isConnected =>
      state == ChatConnectionState.connected ||
      state == ChatConnectionState.loggedIn;

  bool _isLoggedIn = true;
  bool _isConnected = true;

  @override
  Stream<String> get nickChanges => const Stream.empty();

  void setConnectionState(bool connected) {
    _isConnected = connected;
    _connectionStateController.add(connected);
    _stateController.add(state);
  }

  void setLoggedIn(bool loggedIn) {
    _isLoggedIn = loggedIn;
    _stateController.add(state);
  }

  @override
  Future<Map<String, int>> requestChannelsList() async {
    return {};
  }

  @override
  Future<List<String>> requestUsersList({required String targetChannel}) async {
    return [];
  }

  @override
  void sendMessage(String message) {
    if (_isLoggedIn) {
      sentMessages.add(message);
    }
  }

  @override
  void dispose() {}
}

void main() {
  group('ChatProvider', () {
    late UserConfiguration config;
    late ChatProvider provider;

    late FakeChatService fakeChatService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      config = FakeUserConfiguration();
      final mockNotifications = MockFlutterLocalNotificationsPlugin();
      fakeChatService = FakeChatService();

      provider = ChatProvider(
        config,
        appVersion: "test",
        localNotifications: mockNotifications,
        chatService: fakeChatService,
      );

      // Initialize state for traditional tests
      fakeChatService.setConnectionState(true);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initializes with default state', () {
      expect(provider.messages, isEmpty);
      expect(provider.usersFuture, isNotNull);
      expect(provider.channelsFuture, isNotNull);
      expect(provider.isConnected, isTrue);
      expect(provider.currentDmNickname, isNull);
    });

    test('setDmMode updates state', () {
      provider.setDmMode('AnotherUser');
      expect(provider.currentDmNickname, 'AnotherUser');

      provider.setDmMode(null);
      expect(provider.currentDmNickname, isNull);
    });

    test('clearMessages empties the message list', () {
      provider.clearMessages();
      expect(provider.messages, isEmpty);
    });

    test('joinChannel resets channel state and sends appropriate commands', () {
      provider.joinChannel('#testchannel');
      expect(provider.activeChannel, '#testchannel');
      expect(provider.isCurrentChannelPrivate, isFalse);

      expect(
        fakeChatService.sentMessages,
        containsAll([
          '/join #testchannel',
          '/log :depth 100 :date-format date',
          '/private status',
        ]),
      );

      expect(fakeChatService.sentMessages, contains('/join #testchannel'));
      expect(
        fakeChatService.sentMessages,
        contains('/log :depth 100 :date-format date'),
      );
      expect(fakeChatService.sentMessages, contains('/private status'));
    });

    test('setPrivateChannel sends appropriate commands and updates state', () {
      provider.setPrivateChannel(true);
      expect(provider.isCurrentChannelPrivate, isTrue);
      expect(fakeChatService.sentMessages, contains('/private on'));

      fakeChatService.sentMessages.clear();

      provider.setPrivateChannel(false);
      expect(provider.isCurrentChannelPrivate, isFalse);
      expect(fakeChatService.sentMessages, contains('/private off'));
    });

    test(
      'reconnectInNonDefaultChannel: sends /join after login, not just connection',
      () async {
        // 1. Setup: be in a non-default channel
        fakeChatService.setLoggedIn(true);
        provider.joinChannel('#testing');
        fakeChatService.sentMessages.clear();

        // 2. Simulate disconnect
        fakeChatService.setConnectionState(false);
        fakeChatService.setLoggedIn(false);

        // 3. Simulate reconnect - only socket connects, not yet logged in
        fakeChatService.setConnectionState(true);
        // We must wait for the connectionState event to be processed by ChatProvider
        // BEFORE it becomes logged in, to confirm that the /join attempt is dropped.
        await Future<void>.delayed(Duration.zero);

        // Verify that /join was NOT sent yet (because it would be dropped by ChatService)
        expect(
          fakeChatService.sentMessages,
          isNot(contains('/join #testing')),
          reason:
              'Should not send /join before login because it will be dropped',
        );

        // 4. Simulate login complete
        fakeChatService.setLoggedIn(true);
        await Future<void>.delayed(Duration.zero);

        expect(
          fakeChatService.sentMessages,
          contains('/join #testing'),
          reason: 'Should send /join after login to ensure correct channel',
        );
      },
    );
  });

  group('hasMention', () {
    test('Detects simple mention', () {
      expect(ChatProvider.hasMention('Hello @TestUser', 'TestUser'), isTrue);
    });

    test('Ignores mentions without @', () {
      expect(ChatProvider.hasMention('Hello TestUser', 'TestUser'), isFalse);
    });

    test('Does not match substrings of longer names', () {
      expect(
        ChatProvider.hasMention('Hello @TestUserABC', 'TestUser'),
        isFalse,
      );
      expect(
        ChatProvider.hasMention('Hello @TestUser123', 'TestUser'),
        isFalse,
      );
    });

    test('Matches mention with punctuation after', () {
      expect(
        ChatProvider.hasMention('Hello @TestUser, how are you?', 'TestUser'),
        isTrue,
      );
      expect(
        ChatProvider.hasMention('Is that you @TestUser?', 'TestUser'),
        isTrue,
      );
      expect(ChatProvider.hasMention('@TestUser!', 'TestUser'), isTrue);
    });

    test('Matches mention at the start of the string', () {
      expect(
        ChatProvider.hasMention('@TestUser you there?', 'TestUser'),
        isTrue,
      );
    });

    test('Matches mention at the end of the string', () {
      expect(
        ChatProvider.hasMention('I am talking to @TestUser', 'TestUser'),
        isTrue,
      );
    });

    test('Case insensitive match', () {
      expect(ChatProvider.hasMention('Hello @testuser', 'TestUser'), isTrue);
      expect(ChatProvider.hasMention('Hello @TESTUSER', 'TestUser'), isTrue);
    });

    test('Empty nickname returns false', () {
      expect(ChatProvider.hasMention('Hello @TestUser', ''), isFalse);
    });
  });
}
