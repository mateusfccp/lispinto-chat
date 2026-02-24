import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/command_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/tag_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/mentions_autocomplete.dart';
import 'package:lispinto_chat/core/delete_aware_text_controller.dart';

void main() {
  group('MentionsAutocomplete', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Widget buildSubject({
      List<String> onlineUsers = const ['alice', 'bob', 'charlie'],
      TextEditingController? customController,
      FocusNode? customFocusNode,
    }) {
      final defaultTriggers = [
        const TagAutocompleteTrigger(),
        const CommandAutocompleteTrigger(command: 'dm'),
        const CommandAutocompleteTrigger(command: 'whois'),
      ];

      return MaterialApp(
        home: Scaffold(
          body: MentionsAutocomplete(
            controller: customController ?? controller,
            focusNode: customFocusNode ?? focusNode,
            users: onlineUsers,
            triggers: defaultTriggers,
            child: TextField(
              controller: customController ?? controller,
              focusNode: customFocusNode ?? focusNode,
            ),
          ),
        ),
      );
    }

    testWidgets('does not show dropdown initially', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows dropdown when typing @', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Focus and type '@'
      focusNode.requestFocus();
      await tester.pump();

      controller.value = const TextEditingValue(
        text: '@',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
      expect(find.text('charlie'), findsOneWidget);
    });

    testWidgets('filters list based on query', (tester) async {
      await tester.pumpWidget(
        buildSubject(onlineUsers: ['alice', 'albert', 'bob']),
      );

      focusNode.requestFocus();
      await tester.pump();

      controller.value = const TextEditingValue(
        text: '@a',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('albert'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsNothing);
    });

    testWidgets('hides dropdown when match is invalid', (tester) async {
      await tester.pumpWidget(buildSubject());

      focusNode.requestFocus();
      await tester.pump();

      controller.value = const TextEditingValue(
        text: 'hello@',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('replaces text correctly on tap', (tester) async {
      await tester.pumpWidget(buildSubject());

      focusNode.requestFocus();
      await tester.pump();

      controller.value = const TextEditingValue(
        text: 'Hello @b',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();

      expect(find.text('bob'), findsOneWidget);

      await tester.tap(find.text('bob'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Hello @bob ');
      expect(controller.selection.baseOffset, 11);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('works flawlessly with DeleteAwareEditingController', (
      tester,
    ) async {
      final localFocusNode = FocusNode();
      final deleteAwareController = DeleteAwareEditingController(
        focusNode: localFocusNode,
        onDeleteEmpty: () {},
      );
      // Manually force prefix mode for simulation
      deleteAwareController.text = '\u200B';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildSubject(
              onlineUsers: const ['alice', 'bob', 'charlie'],
              customController: deleteAwareController,
              customFocusNode: localFocusNode,
            ),
          ),
        ),
      );

      localFocusNode.requestFocus();
      await tester.pump();

      // Type "Hello @c"
      deleteAwareController.value = const TextEditingValue(
        text: '\u200BHello @c',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pumpAndSettle();

      expect(find.text('charlie'), findsOneWidget);

      await tester.tap(find.text('charlie'));
      await tester.pumpAndSettle();

      expect(deleteAwareController.text, '\u200BHello @charlie ');
      expect(deleteAwareController.typedText, 'Hello @charlie ');
      expect(deleteAwareController.selection.baseOffset, 16);

      deleteAwareController.dispose();
      localFocusNode.dispose();
    });

    testWidgets('preserves zero-width space when mention is at the start', (
      tester,
    ) async {
      final localFocusNode = FocusNode();
      final deleteAwareController = DeleteAwareEditingController(
        focusNode: localFocusNode,
        onDeleteEmpty: () {},
      );
      // Manually force prefix mode for simulation
      deleteAwareController.text = '\u200B';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildSubject(
              onlineUsers: const ['alice', 'bob', 'charlie'],
              customController: deleteAwareController,
              customFocusNode: localFocusNode,
            ),
          ),
        ),
      );

      localFocusNode.requestFocus();
      await tester.pump();

      // Type "@a" directly after the zero-width space
      deleteAwareController.value = const TextEditingValue(
        text: '${DeleteAwareEditingController.zeroWidthSpace}@a',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);

      await tester.tap(find.text('alice'));
      await tester.pumpAndSettle();

      // The key behavior: \u200B must remain intact at index 0.
      expect(
        deleteAwareController.text,
        '${DeleteAwareEditingController.zeroWidthSpace}@alice ',
      );
      expect(deleteAwareController.typedText, '@alice ');
      expect(deleteAwareController.selection.baseOffset, 8);

      deleteAwareController.dispose();
      localFocusNode.dispose();
    });
  });
}
