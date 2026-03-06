import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PersistentUserConfiguration', () {
    test('returns default values when preferences are empty', () async {
      SharedPreferences.setMockInitialValues({});
      final config = await UserConfiguration.load();

      expect(config.nickname, '');
      expect(config.serverUrl, 'wss://chat.manoel.dev/ws');
      expect(config.pushNotificationsEnabled, isFalse);
      expect(config.mentionNotificationsEnabled, isFalse);
      expect(config.autoConnect, isFalse);
      expect(config.showTimeSeconds, isFalse);
      expect(config.showImagePreviews, isTrue);
      expect(config.showEmptyChannels, isFalse);
      expect(config.showMarkdown, isTrue);
      expect(config.groupMessages, isTrue);
      expect(config.lastChannel, '#general');
      expect(config.hasNickname, isFalse);
    });

    test('returns values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'nickname': 'alice',
        'server_url': 'ws://localhost:9999',
        'auto_connect': true,
        'show_markdown': false,
      });
      final config = await UserConfiguration.load();

      expect(config.nickname, 'alice');
      expect(config.serverUrl, 'ws://localhost:9999');
      expect(config.autoConnect, isTrue);
      expect(config.showMarkdown, isFalse);
      expect(config.hasNickname, isTrue);
    });

    test('saves values correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final config = await UserConfiguration.load();
      final prefs = await SharedPreferences.getInstance();

      await config.setNickname('bob');
      await config.setServerUrl('ws://new-server.com');
      await config.setAutoConnect(true);

      expect(prefs.getString('nickname'), 'bob');
      expect(prefs.getString('server_url'), 'ws://new-server.com');
      expect(prefs.getBool('auto_connect'), isTrue);
    });

    test(
      'hasNickname returns true only for non-empty trimmed nicknames',
      () async {
        SharedPreferences.setMockInitialValues({'nickname': '  '});
        var config = await UserConfiguration.load();
        expect(config.hasNickname, isFalse);

        SharedPreferences.setMockInitialValues({'nickname': 'bob'});
        config = await UserConfiguration.load();
        expect(config.hasNickname, isTrue);
      },
    );
  });
}
