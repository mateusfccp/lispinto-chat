import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/services/link_image_detector.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:mockito/mockito.dart';

import 'widgets/message_bubble_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLinkImageDetector mockDetector;

  setUp(() {
    if (locator.isRegistered<LinkImageDetector>()) {
      locator.unregister<LinkImageDetector>();
    }
    mockDetector = MockLinkImageDetector();
    locator.registerSingleton<LinkImageDetector>(mockDetector);

    // Stub detector to return null for repro link
    when(mockDetector.getCachedStatus(any)).thenReturn(null);
    when(mockDetector.isImage(any)).thenAnswer((_) async => null);
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
