import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/services/link_preview_service.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/message_bubble_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLinkPreviewService mockService;

  setUp(() async {
    if (locator.isRegistered<LinkPreviewService>()) {
      locator.unregister<LinkPreviewService>();
    }
    mockService = MockLinkPreviewService();
    locator.registerSingleton<LinkPreviewService>(mockService);

    // Stub service to return null for repro link
    when(mockService.getCachedInfo(any)).thenReturn(null);
    when(mockService.fetchInfo(any)).thenAnswer((_) async => null);

    SharedPreferences.setMockInitialValues({
      'nickname': 'testuser',
      'show_image_previews': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final mockConfig = PersistentUserConfiguration(preferences: prefs);
    locator.registerSingleton<UserConfiguration>(mockConfig);
  });

  testWidgets('Link in MessageBubble should be clickable', (tester) async {
    final message = ChatMessage(
      from: 'user',
      content: 'Visit https://google.com',
      date: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message, searchQuery: ''),
        ),
      ),
    );

    // Initial build and image detection pump
    await tester.pump(const Duration(milliseconds: 100));

    // Find the link text. It should be rendered as blue underlined text.
    final linkFinder = find.textContaining('https://google.com');
    expect(linkFinder, findsOneWidget);

    // We can't easily verify url_launcher without a mock,
    // but we can check if the TapGestureRecognizer is present and clickable.
    // However, in tests, we can use the MethodChannel to verify launchUrl.

    final List<MethodCall> log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        return true;
      },
    );

    debugDumpApp();
    await tester.tap(linkFinder);
    await tester.pump();

    expect(
      log.any((call) => call.method == 'launch'),
      isTrue,
      reason: 'launchUrl should have been called',
    );
    final launchCall = log.firstWhere((call) => call.method == 'launch');
    expect(launchCall.arguments['url'], 'https://google.com');
  });
}
