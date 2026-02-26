import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';

void main() {
  group('Stylized Text Verification', () {
    testWidgets('renders bold correctly', (tester) async {
      late List<InlineSpan> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = buildStylizedText(
                  context: context,
                  text: 'This is **bold text**',
                );
                return RichText(text: TextSpan(children: result));
              },
            ),
          ),
        ),
      );

      // result:
      //  0: "This is "
      //  1: Bold wrapper
      expect(result.length, 2);
      expect((result[0] as TextSpan).text, 'This is ');
      expect(result[1].toPlainText(), 'bold text');
    });

    testWidgets('renders mention with trailing space correctly', (tester) async {
      late List<InlineSpan> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = buildStylizedText(
                  context: context,
                  text: 'Hey @user check this',
                );
                return RichText(text: TextSpan(children: result));
              },
            ),
          ),
        ),
      );

      // result:
      //   0: "Hey "
      //   1: Mention wrapper (text: "@user")
      //   2: " " (Manual space)
      //   3: "check this"
      expect(result.length, 4);
      expect((result[0] as TextSpan).text, 'Hey ');
      expect(result[1].toPlainText(), '@user');
      expect((result[2] as TextSpan).text, ' ');
      expect((result[3] as TextSpan).text, 'check this');
    });

    testWidgets('search highlight works inside stylized text', (tester) async {
      late List<InlineSpan> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final stylized = buildStylizedText(
                  context: context,
                  text: 'This is **bold text**',
                );
                result = stylized.expand((s) => buildHighlightedSearchText(s, 'bold')).toList();
                return RichText(text: TextSpan(children: result));
              },
            ),
          ),
        ),
      );

      // Verify "bold" is highlighted somewhere in the tree
      bool foundHighlight = false;
      void check(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text == 'bold' && span.style?.backgroundColor != null) {
            foundHighlight = true;
          }
          if (span.children != null) {
            for (final child in span.children!) {
              check(child);
            }
          }
        }
      }

      for (final span in result) {
        check(span);
      }
      expect(foundHighlight, isTrue);
    });
  });
}
