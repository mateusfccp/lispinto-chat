import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatProvider', () {
    late UserConfiguration config;
    late ChatProvider provider;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      config = await UserConfiguration.load();
      await config.setNickname('TestUser');
      await config.setServerUrl('ws://localhost:8080');

      provider = ChatProvider(config, appVersion: "test");
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initializes with default state', () {
      expect(provider.messages, isEmpty);
      expect(provider.onlineUsers, isEmpty);
      expect(provider.isConnected, isFalse);
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
