import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/main.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/services/image_upload_service.dart';
import 'package:lispinto_chat/services/link_image_detector.dart';
import 'package:lispinto_chat/services/websocket_factory.dart';
import 'package:lispinto_chat/widgets/input_area.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockWebSocketChannel extends Fake implements WebSocketChannel {
  final _streamController = StreamController<dynamic>.broadcast();
  final _sinkController = StreamController<dynamic>();

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _MockWebSocketSink(_sinkController);

  @override
  Future<void> get ready => Future.value();

  void feed(String data) => _streamController.add(data);
  Stream<dynamic> get outgoing => _sinkController.stream;
}

class _MockWebSocketSink extends Fake implements WebSocketSink {
  final StreamController<dynamic> _controller;
  _MockWebSocketSink(this._controller);

  @override
  void add(dynamic data) => _controller.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async =>
      _controller.close();
}

class MockWebSocketFactory extends Fake implements WebSocketFactory {
  MockWebSocketChannel? lastChannel;

  @override
  WebSocketChannel create(Uri uri) {
    return lastChannel = MockWebSocketChannel();
  }
}

class MockImageUploadService extends Fake implements ImageUploadService {
  @override
  Future<String> uploadImage(Uint8List bytes) async =>
      'https://example.com/image.png';
}

class MockFlutterLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {}
}

void main() {
  group('Full User Flow Test', () {
    late MockWebSocketFactory webSocketFactory;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      webSocketFactory = MockWebSocketFactory();

      final prefs = await SharedPreferences.getInstance();
      final config = PersistentUserConfiguration(preferences: prefs);

      await locator.reset();

      locator.registerSingleton<Logger>(Logger('Test'));
      locator.registerSingleton<UserConfiguration>(config);
      locator.registerSingleton<LinkImageDetector>(LinkImageDetector());
      locator.registerSingleton<MessageGrouper>(const MessageGrouper());
      locator.registerSingleton<WebSocketFactory>(webSocketFactory);
      locator.registerSingleton<ImageUploadService>(MockImageUploadService());

      locator.registerSingleton<ChatProvider>(
        ChatProvider(
          config,
          appVersion: 'test',
          websocketFactory: webSocketFactory,
          localNotifications: MockFlutterLocalNotificationsPlugin(),
        ),
      );

      locator.registerSingleton<PackageInfo>(
        PackageInfo(
          appName: 'Test',
          packageName: 'test',
          version: '1.0.0',
          buildNumber: '1',
        ),
      );
    });

    tearDown(() async {
      await locator.reset();
    });

    testWidgets('Login, Join and Message Flow', (tester) async {
      final provider = locator<ChatProvider>();

      try {
        await tester.pumpWidget(const App());
        await tester.pumpAndSettle();

        // 1. Verify Initial Screen
        expect(find.text('Nickname'), findsWidgets);

        // 2. Enter nickname and connect
        await tester.enterText(find.byType(TextFormField).first, 'tester');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        // Simulate server handshake
        final channel = webSocketFactory.lastChannel;
        expect(channel, isNotNull);

        channel!.feed('> Type your username:');

        // Feed server messages to transition to loggedIn and populate channels
        channel.feed(
          '|18:00:00| [@server]: The user @tester joined to the party!',
        );
        channel.feed('|18:00:01| [@server]: #general: 1 user');

        // Wait for navigation and state updates
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();

        // 3. Verify we are in ChatScreen
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(provider.isConnected, isTrue);
        expect(find.textContaining('#general'), findsWidgets);

        // 4. Send message
        final inputArea = find.byType(InputArea);
        expect(inputArea, findsOneWidget);

        final inputFinder = find.descendant(
          of: inputArea,
          matching: find.byType(TextField),
        );
        expect(inputFinder, findsOneWidget);

        final testMessage = 'hello unique message 123456';
        await tester.enterText(inputFinder, testMessage);
        await tester.pump();

        final sendButton = find.byTooltip('Send message').last;
        expect(sendButton, findsOneWidget);

        await tester.tap(sendButton);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // 5. Simulate server echoing our message
        channel.feed('|18:00:02| [@tester]: $testMessage');

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // 6. Verify message is displayed in the list
        expect(find.textContaining(testMessage), findsWidgets);
      } finally {
        provider.disconnect();
        provider.dispose();
      }
    });
  });
}
