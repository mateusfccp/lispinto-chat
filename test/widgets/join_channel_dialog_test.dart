import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/widgets/join_channel_dialog.dart';
import 'package:fluent_i18n/fluent_i18n.dart';

void main() {
  testWidgets('JoinChannelDialog shows and submits channel name', (
    WidgetTester tester,
  ) async {
    String? joinedChannel;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en')],
          localizationsDelegates: [
            FluentLocalizationsDelegate([Locale('en')]),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              if (FluentLocalizations.of(context) == null) {
                return const SizedBox.shrink();
              }
              return JoinChannelDialog(
                onJoin: (channel) {
                  joinedChannel = channel;
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    expect(find.text('Join channel'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'test-channel');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(joinedChannel, 'test-channel');
    expect(find.byType(JoinChannelDialog), findsNothing);
  });

  testWidgets('JoinChannelDialog validation works', (
    WidgetTester tester,
  ) async {
    String? joinedChannel;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en')],
          localizationsDelegates: [
            FluentLocalizationsDelegate([Locale('en')]),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              if (FluentLocalizations.of(context) == null) {
                return const SizedBox.shrink();
              }
              return JoinChannelDialog(
                onJoin: (channel) {
                  joinedChannel = channel;
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    await tester.tap(find.text('Join'));
    await tester.pump();

    expect(find.text('Please enter a channel name'), findsOneWidget);
    expect(joinedChannel, isNull);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Join'));
    await tester.pump();

    expect(find.text('Please enter a channel name'), findsOneWidget);
    expect(joinedChannel, isNull);
  });
}
