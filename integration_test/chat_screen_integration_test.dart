import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/mockito.dart';

import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/models/chat_message.dart';

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

class MockChatService extends Mock implements ChatService {
  @override
  Stream<ChatMessage> get messages => const Stream.empty();

  @override
  Stream<String> get notifications => const Stream.empty();

  @override
  Stream<List<String>> get users => Stream.value(['alice']);

  @override
  Stream<bool> get connectionState => Stream.value(true);

  @override
  Stream<String> get nickChanges => const Stream.empty();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen Selection Bug (Integration Test)', () {
    late ChatProvider provider;

    setUp(() async {
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return true;
          });

      SharedPreferences.setMockInitialValues({
        'nickname': 'me',
        'server_url': 'ws://localhost',
      });
      final prefs = await SharedPreferences.getInstance();
      final config = UserConfiguration(preferences: prefs);
      final mockNotifications = MockFlutterLocalNotificationsPlugin();
      final mockChatService = MockChatService();

      provider = ChatProvider(
        config,
        appVersion: 'test',
        localNotifications: mockNotifications,
        chatService: mockChatService,
      );
    });

    testWidgets('preserves text selection when tapping a user to DM', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ChatScreen(provider: provider)),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Type a message...',
      );
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      final controller = textField.controller!;

      controller.value = const TextEditingValue(
        text: '​abcdefg',
        selection: TextSelection(baseOffset: 5, extentOffset: 7),
      );
      await tester.pumpAndSettle();

      expect(controller.text, '​abcdefg');
      expect(controller.selection.baseOffset, 5);
      expect(controller.selection.extentOffset, 7);

      expect(find.text('alice'), findsOneWidget);

      await tester.tap(find.text('alice'));

      await tester.pumpAndSettle();

      expect(provider.currentDmNickname, 'alice');

      expect(controller.text, '​abcdefg');
      expect(
        controller.selection.baseOffset,
        5,
        reason: "Text block selection was lost or overwritten by OS",
      );
      expect(
        controller.selection.extentOffset,
        7,
        reason: "Text block selection was lost or overwritten by OS",
      );
    });
  });
}
