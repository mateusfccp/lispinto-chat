import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen_shortcut_test.mocks.dart';

class FakeChatProvider extends ChatProvider {
  FakeChatProvider(
    super.configuration, {
    required super.appVersion,
    required super.localNotifications,
    required super.chatService,
  });

  @override
  UnmodifiableListView<ChatMessage> get messages => UnmodifiableListView([]);

  @override
  bool get isConnected => true;

  @override
  Stream<String> get notifications => const Stream.empty();

  @override
  String? get currentDmNickname => null;

  @override
  String get searchQuery => '';

  @override
  void search(String query) {}
}

class FakeUserConfiguration extends Fake implements UserConfiguration {
  @override
  String get nickname => 'testuser';

  @override
  set nickname(String value) {}

  @override
  bool get hasNickname => true;

  @override
  String get serverUrl => 'ws://localhost';

  @override
  String get lastChannel => 'general';

  @override
  set lastChannel(String value) {}

  @override
  bool get autoConnect => false;

  @override
  set autoConnect(bool value) {}

  @override
  bool get groupMessages => true;

  @override
  bool get mentionNotificationsEnabled => false;

  @override
  bool get pushNotificationsEnabled => false;

  @override
  bool get showImagePreviews => true;

  @override
  bool get showEmptyChannels => true;
}

@GenerateMocks([SharedPreferences, FlutterLocalNotificationsPlugin])
void main() {
  late MockFlutterLocalNotificationsPlugin mockNotifications;
  late UserConfiguration config;

  setUp(() {
    mockNotifications = MockFlutterLocalNotificationsPlugin();
    config = FakeUserConfiguration();

    // Suppress overflow errors in tests
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };

    when(
      mockNotifications.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed(
          'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);

    // Setup locator
    locator.reset();
    locator.registerSingleton<UserConfiguration>(config);
    locator.registerSingleton<MessageGrouper>(const MessageGrouper());
    final mockChatService = FakeTestChatService();
    locator.registerSingleton<ChatProvider>(
      FakeChatProvider(
        config,
        appVersion: '1.0.0',
        localNotifications: mockNotifications,
        chatService: mockChatService,
      ),
    );
  });

  testWidgets('CTRL+S should toggle search even if chat input is not focused', (
    tester,
  ) async {
    // Set a large surface size to avoid layout overflows
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));

    // Initial pump to let autofocus happen
    await tester.pumpAndSettle();

    // Verify chat input doesn't have focus
    // We search for TextField by hint to avoid the prototype one
    final chatInputFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Type a message...',
    );
    final chatInputFocusNode = tester
        .widget<TextField>(chatInputFinder)
        .focusNode;
    expect(chatInputFocusNode?.hasFocus ?? false, isFalse);

    // Try to trigger CTRL+S
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    // Try to trigger CMD+S
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    // Verify search is visible (look for the search text field)
    // There are 3 TextFields: Prototype + Chat Input + Search Input
    final searchInputFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search messages...',
    );
    expect(searchInputFinder, findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('Escape should close search and return focus to chat input', (
    tester,
  ) async {
    // Set a large surface size to avoid layout overflows
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pump();

    // Ensure focus is on the main detector
    await tester.tap(find.byType(ChatScreen));
    await tester.pump();

    // Open search with CTRL+S
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    // Or open with CMD+S
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final searchInputFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search messages...',
    );
    expect(searchInputFinder, findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    // Press Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Verify search is closed
    expect(searchInputFinder, findsNothing);
    expect(find.byType(TextField), findsNWidgets(2)); // Prototype + Chat Input

    // Verify chat input has focus
    final chatInputFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Type a message...',
    );
    final chatInputFocusNode = tester
        .widget<TextField>(chatInputFinder)
        .focusNode;
    expect(chatInputFocusNode?.hasFocus ?? false, isTrue);
  });
}

class FakeTestChatService extends Fake implements ChatService {
  @override
  Stream<String> get currentChannelStream => const Stream.empty();

  @override
  Stream<ChatMessage> get messages => const Stream.empty();

  @override
  Stream<List<String>> get users => const Stream.empty();

  @override
  Stream<Map<String, int>> get channels => const Stream.empty();

  @override
  Stream<String> get nickChanges => const Stream.empty();

  @override
  Stream<ChatMessage> get notifications => const Stream.empty();

  @override
  void setAppBackgroundState(bool state) {}

  @override
  ChatConnectionState get state => ChatConnectionState.connected;

  @override
  Stream<bool> get connectionState => Stream.value(true);

  @override
  String get currentChannel => '#general';

  @override
  void sendMessage(String text, {params}) {}

  @override
  Future<List<String>> requestUsersList({required String targetChannel}) async {
    return [];
  }

  @override
  Future<Map<String, int>> requestChannelsList() async {
    return {};
  }

  @override
  void dispose() {}
}
