import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('renders image pill for single image URL', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/image.jpg',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, showImagePreviews: true),
          ),
        ),
      );

      // Link is replaced by a pill
      expect(find.text('image'), findsOneWidget);
      expect(find.text('https://example.com/image.jpg'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders pills for multiple image URLs', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content:
            'Photos: https://example.com/1.png and https://example.com/2.webp',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, showImagePreviews: true),
          ),
        ),
      );

      // Now pills are not numbered
      expect(find.text('image'), findsNWidgets(2));
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('renders normal URLs when showImagePreviews is false', (
      tester,
    ) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/image.jpg',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, showImagePreviews: false),
          ),
        ),
      );

      expect(find.text('image'), findsNothing);
      // find.text should find it even if it's in a styled TextSpan child
      expect(find.textContaining('https://example.com/image.jpg'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('does not treat non-image URLs as images', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/page.html',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, showImagePreviews: true),
          ),
        ),
      );

      expect(find.text('image'), findsNothing);
      expect(find.textContaining('https://example.com/page.html'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders search highlights correctly', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Hello **bold world** and @alice ',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              showImagePreviews: true,
              searchQuery: 'bold',
            ),
          ),
        ),
      );

      // Verify "bold" is highlighted (background color set)
      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan!;

      bool foundHighlight = false;
      void checkHighlight(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text == 'bold' && span.style?.backgroundColor != null) {
            foundHighlight = true;
          }
          if (span.children != null) {
            for (final child in span.children!) {
              checkHighlight(child);
            }
          }
        }
      }

      for (final span in textSpan.children!) {
        checkHighlight(span);
      }

      expect(foundHighlight, isTrue);
    });
  });
}
