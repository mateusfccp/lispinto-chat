import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/widgets/join_channel_dialog.dart';

void main() {
  testWidgets('JoinChannelDialog shows and submits channel name', (
    WidgetTester tester,
  ) async {
    String? joinedChannel;

    await tester.pumpWidget(
      MaterialApp(
        home: JoinChannelDialog(
          onJoin: (channel) {
            joinedChannel = channel;
          },
        ),
      ),
    );

    expect(find.text('Join/Create Channel'), findsOneWidget);
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

    await tester.pumpWidget(
      MaterialApp(
        home: JoinChannelDialog(
          onJoin: (channel) {
            joinedChannel = channel;
          },
        ),
      ),
    );

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
