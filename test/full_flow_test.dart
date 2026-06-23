import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/main.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/image_upload_service.dart';
import 'package:lispinto_chat/services/link_preview_service.dart';
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

class MockHttpClient extends Fake implements http.Client {
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return http.Response(
      '{"status":"success", "result": "channels: #general(1)"}',
      200,
    );
  }
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
      locator.registerSingleton<LinkPreviewService>(LinkPreviewService());
      locator.registerSingleton<MessageGrouper>(const MessageGrouper());
      locator.registerSingleton<WebSocketFactory>(webSocketFactory);
      locator.registerSingleton<ImageUploadService>(MockImageUploadService());

      final chatService = ChatService(
        url: Uri.parse('ws://localhost'),
        nickname: 'test',
        webSocketFactory: webSocketFactory,
        httpClient: MockHttpClient(),
        configuration: config,
      );

      locator.registerSingleton<ChatService>(chatService);

      locator.registerSingleton<ChatProvider>(
        ChatProvider(
          config,
          appVersion: 'test',
          localNotifications: MockFlutterLocalNotificationsPlugin(),
          chatService: chatService,
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
        await tester.pump(const Duration(seconds: 1));

        // 1. Verify Initial Screen
        expect(find.text('Nickname'), findsWidgets);

        // 2. Enter nickname and connect
        await tester.enterText(find.byType(TextFormField).first, 'tester');
        await tester.tap(find.text('Connect'));
        // Simulate server handshake
        MockWebSocketChannel? channel;
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          channel = webSocketFactory.lastChannel;
          if (channel != null) break;
        }
        expect(
          channel,
          isNotNull,
          reason: 'WebSocket channel should be created',
        );

        channel!.feed('> Type your username:');
        channel.feed('|10:00:00| [@server]: Your session ID is: mock-uuid');

        // Feed server messages to transition to loggedIn and populate channels
        channel.feed(
          '|18:00:00| [@server]: The user @tester joined to the party!',
        );
        channel.feed('|18:00:01| [@server]: #general: 1 user');

        // Wait for navigation and state updates
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        // Pump to let animations and timers run, but don't wait forever if there's a spinner
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));

        // 3. Verify we are in ChatScreen
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(provider.isConnected, isTrue);
        expect(find.textContaining('#general'), findsWidgets);

        // 4. Send message
        final inputArea = find.byType(InputArea).last;
        final inputFinder = find
            .descendant(of: inputArea, matching: find.byType(TextField))
            .last;
        expect(inputFinder, findsOneWidget);

        final testMessage = 'hello unique message 123456';
        await tester.enterText(inputFinder, testMessage);
        await tester.pump();

        final sendButton = find.byTooltip('Send message').last;
        expect(sendButton, findsOneWidget);

        await tester.tap(sendButton);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        // 5. Simulate server echoing our message
        channel.feed('|18:00:02| [@tester]: $testMessage');

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        // 6. Verify message is displayed in the list
        expect(find.textContaining(testMessage), findsWidgets);
      } finally {
        provider.disconnect();
        provider.dispose();
      }
    });
  });
}
