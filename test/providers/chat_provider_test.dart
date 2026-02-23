import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatProvider', () {
    late UserConfiguration config;
    late ChatProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      config = await UserConfiguration.load();
      await config.setNickname('TestUser');
      await config.setServerUrl('ws://localhost:8080');

      provider = ChatProvider(config);
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
}
