import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/image_upload_service.dart';
import 'package:lispinto_chat/services/link_preview_service.dart';
import 'package:lispinto_chat/services/websocket_factory.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _connectionStateController = StreamController<bool>.broadcast();

  MockChatService() {
    _connectionStateController.add(true);
  }

  @override
  Stream<ChatMessage> get messages => const Stream.empty();

  @override
  Stream<bool> get connectionState async* {
    yield true;
    yield* _connectionStateController.stream;
  }

  @override
  Stream<ChatMessage> get notifications => const Stream.empty();

  @override
  Stream<List<String>> get users => Stream.value(['alice']);

  @override
  Stream<String> get nickChanges => const Stream.empty();

  @override
  Stream<Map<String, int>> get channels => const Stream.empty();

  @override
  ChatConnectionState get state => ChatConnectionState.loggedIn;

  @override
  bool get isConnected => true;

  @override
  bool get isLoggedIn => true;

  @override
  bool get isConnecting => false;
}

class MockWebSocketFactory extends Mock implements WebSocketFactory {}

class MockImageUploadService extends Mock implements ImageUploadService {
  @override
  Future<String> uploadImage(Uint8List bytes) async =>
      'http://example.com/image.png';
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
      final config = PersistentUserConfiguration(preferences: prefs);
      final mockNotifications = MockFlutterLocalNotificationsPlugin();
      final mockChatService = MockChatService();

      provider = ChatProvider(
        config,
        appVersion: 'test',
        localNotifications: mockNotifications,
        chatService: mockChatService,
      );

      locator.pushNewScope();
      locator.registerSingleton<UserConfiguration>(config);
      locator.registerSingleton<ChatProvider>(provider);
      locator.registerSingleton<Logger>(Logger('Test'));
      locator.registerSingleton<PackageInfo>(
        PackageInfo(
          appName: 'Test',
          packageName: 'test',
          version: '1.0.0',
          buildNumber: '1',
        ),
      );
      locator.registerSingleton<LinkPreviewService>(LinkPreviewService());
      locator.registerSingleton<MessageGrouper>(const MessageGrouper());
      locator.registerSingleton<ImageUploadService>(MockImageUploadService());
    });

    tearDown(() {
      try {
        locator.popScope();
      } catch (_) {
        // Ignore if no scope to pop
      }
    });

    testWidgets('preserves text selection when tapping a user to DM', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Type a message...',
        skipOffstage: false,
      );
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder.first);
      final controller = textField.controller!;

      controller.value = const TextEditingValue(
        text: '​abcdefg',
        selection: TextSelection(baseOffset: 5, extentOffset: 7),
      );
      await tester.pumpAndSettle();

      expect(controller.text, '​abcdefg');
      expect(controller.selection.baseOffset, 5);
      expect(controller.selection.extentOffset, 7);

      final aliceFinder = find.text('alice', skipOffstage: false);
      expect(aliceFinder, findsOneWidget);

      await tester.tap(aliceFinder);

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
