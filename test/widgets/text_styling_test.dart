import 'package:fluent_i18n/fluent_i18n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lispinto_chat/services/link_image_detector.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'text_styling_test.mocks.dart';

@GenerateMocks([LinkImageDetector])
void main() {
  final locator = GetIt.instance;

  setUp(() {
    final mockDetector = MockLinkImageDetector();
    when(mockDetector.getCachedStatus(any)).thenReturn(null);
    locator.registerSingleton<LinkImageDetector>(mockDetector);
  });

  tearDown(() {
    locator.reset();
  });

  group('Stylized Text Verification', () {
    testWidgets('renders bold correctly', (tester) async {
      late List<InlineSpan> result;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              FluentLocalizationsDelegate([Locale('en')]),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (FluentLocalizations.of(context) == null) {
                    return Container();
                  }
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
        await tester.pumpAndSettle();
      });

      // result:
      //  0: "This is "
      //  1: Bold wrapper
      expect(result.length, 2);
      expect((result[0] as TextSpan).text, 'This is ');
      expect(result[1].toPlainText(), 'bold text');
    });

    testWidgets('renders mention with trailing space correctly', (
      tester,
    ) async {
      late List<InlineSpan> result;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              FluentLocalizationsDelegate([Locale('en')]),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (FluentLocalizations.of(context) == null) {
                    return Container();
                  }
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
        await tester.pumpAndSettle();
      });

      // result:
      //   0: "Hey "
      //   1: Mention wrapper (text: "@user")
      //   2: " check this" (includes the space from the input)
      expect(result.length, 3);
      expect((result[0] as TextSpan).text, 'Hey ');
      expect(result[1].toPlainText(), '@user');
      expect((result[2] as TextSpan).text, ' check this');
    });

    testWidgets('search highlight works inside stylized text', (tester) async {
      late List<InlineSpan> result;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              FluentLocalizationsDelegate([Locale('en')]),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (FluentLocalizations.of(context) == null) {
                    return Container();
                  }
                  final stylized = buildStylizedText(
                    context: context,
                    text: 'This is **bold text**',
                  );
                  result = stylized
                      .expand((s) => buildHighlightedSearchText(s, 'bold'))
                      .toList();
                  return RichText(text: TextSpan(children: result));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

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

    testWidgets('renders flat link correctly', (tester) async {
      late List<InlineSpan> result;
      final recognizer = TapGestureRecognizer();
      addTearDown(recognizer.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              FluentLocalizationsDelegate([Locale('en')]),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (FluentLocalizations.of(context) == null) {
                    return Container();
                  }
                  result = buildStylizedText(
                    context: context,
                    text: 'Check https://google.com',
                    linkRecognizerFactory: (_) => recognizer,
                  );
                  return RichText(text: TextSpan(children: result));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      // result:
      //  0: "Check "
      //  1: Link TextSpan (flat, has recognizer)
      expect(result.length, 2);
      final linkSpan = result[1] as TextSpan;
      expect(linkSpan.text, 'https://google.com');
      expect(linkSpan.recognizer, recognizer);
      expect(
        linkSpan.children,
        isNull,
        reason: 'Link span should be flat (no children)',
      );
    });

    testWidgets('preserves link recognizer after highlighting', (tester) async {
      late List<InlineSpan> result;
      const url = 'https://google.com';
      final recognizer = TapGestureRecognizer();
      addTearDown(recognizer.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              FluentLocalizationsDelegate([Locale('en')]),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (FluentLocalizations.of(context) == null) {
                    return Container();
                  }
                  final stylized = buildStylizedText(
                    context: context,
                    text: 'Check $url for more',
                    linkRecognizerFactory: (_) => recognizer,
                  );
                  // Highlight 'google' which is part of the URL
                  result = stylized
                      .expand((s) => buildHighlightedSearchText(s, 'google'))
                      .toList();
                  return RichText(text: TextSpan(children: result));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      bool foundLinkWithRecognizer = false;
      void check(InlineSpan span) {
        if (span is TextSpan) {
          if (span.toPlainText().contains('google') &&
              span.recognizer == recognizer) {
            foundLinkWithRecognizer = true;
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
      expect(
        foundLinkWithRecognizer,
        isTrue,
        reason: 'Link recognizer was lost or mismatched after highlighting',
      );
    });
  });
}
