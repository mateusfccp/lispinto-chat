import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen_shortcut_test.mocks.dart';

class FakeChatProvider extends ChatProvider {
  FakeChatProvider(
    super.configuration, {
    required super.appVersion,
    super.localNotifications, // Accept the mock
  });

  @override
  UnmodifiableListView<String> get onlineUsers =>
      UnmodifiableListView(['testuser', 'otheruser']);

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

@GenerateMocks([SharedPreferences, FlutterLocalNotificationsPlugin])
void main() {
  late MockSharedPreferences mockPrefs;
  late MockFlutterLocalNotificationsPlugin mockNotifications;
  late UserConfiguration config;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockNotifications = MockFlutterLocalNotificationsPlugin();
    config = UserConfiguration(preferences: mockPrefs);

    when(mockPrefs.getString('nickname')).thenReturn('testuser');
    when(mockPrefs.getString('server_url')).thenReturn('ws://localhost');
    when(mockPrefs.getBool(any)).thenReturn(false);

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
  });

  testWidgets('CTRL+S should toggle search even if chat input is not focused', (
    tester,
  ) async {
    // Set a large surface size to avoid layout overflows
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeProvider = FakeChatProvider(
      config,
      appVersion: '1.0.0',
      localNotifications: mockNotifications,
    );

    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(provider: fakeProvider)),
    );

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
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeProvider = FakeChatProvider(
      config,
      appVersion: '1.0.0',
      localNotifications: mockNotifications,
    );

    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(provider: fakeProvider)),
    );

    await tester.pumpAndSettle();

    // Open search
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

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
