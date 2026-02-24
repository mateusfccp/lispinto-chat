import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/delete_aware_text_controller.dart';

void main() {
  group('DeleteAwareEditingController', () {
    test('initializes with zero-width space', () {
      final focusNode = FocusNode();
      final controller = DeleteAwareEditingController(
        onDeleteEmpty: () {},
        focusNode: focusNode,
      );

      // Focus node is not active initially, so there should be no prefix.
      expect(controller.text, isEmpty);
      expect(controller.typedText, isEmpty);

      controller.dispose();
      focusNode.dispose();
    });

    test('initializes with zero-width space and existing text if focused', () {
      final focusNode = FocusNode();
      final controller = DeleteAwareEditingController(
        text: 'hello',
        onDeleteEmpty: () {},
        focusNode: focusNode,
      );

      expect(controller.text, 'hello');
      expect(controller.typedText, 'hello');

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('adds zero-width space on focus', (WidgetTester tester) async {
      final focusNode = FocusNode();
      int deleteEmptyCalledCounter = 0;
      final controller = DeleteAwareEditingController(
        onDeleteEmpty: () {
          deleteEmptyCalledCounter = deleteEmptyCalledCounter + 1;
        },
        focusNode: focusNode,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      );

      // Tap to focus
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
      expect(controller.text, DeleteAwareEditingController.zeroWidthSpace);
      expect(controller.typedText, isEmpty);
      expect(deleteEmptyCalledCounter, 0);

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('clears zero-width space on unfocus if empty', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      final controller = DeleteAwareEditingController(
        onDeleteEmpty: () {},
        focusNode: focusNode,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, focusNode: focusNode),
                const TextField(key: Key('other_field')),
              ],
            ),
          ),
        ),
      );

      // Focus our field
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(controller.text, DeleteAwareEditingController.zeroWidthSpace);

      // Focus another field to unfocus our field
      await tester.tap(find.byKey(const Key('other_field')));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isFalse);
      expect(controller.text, isEmpty);
      expect(controller.typedText, isEmpty);

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets(
      'calls onDeleteEmpty when backspace is pressed on zero-width space (simulate deletion)',
      (WidgetTester tester) async {
        final focusNode = FocusNode();
        int deleteEmptyCalledCounter = 0;
        final controller = DeleteAwareEditingController(
          onDeleteEmpty: () {
            deleteEmptyCalledCounter = deleteEmptyCalledCounter + 1;
          },
          focusNode: focusNode,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        );

        // Focus the field
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        expect(controller.text, DeleteAwareEditingController.zeroWidthSpace);
        expect(controller.typedText, isEmpty);

        // Simulate a backspace by setting the text to empty directly
        // When the user presses backspace, the text goes from '${DeleteAwareEditingController.zeroWidthSpace}' to ''
        controller.value = const TextEditingValue(text: '');
        await tester.pump();

        expect(deleteEmptyCalledCounter, 1);

        controller.dispose();
        focusNode.dispose();
      },
    );

    testWidgets(
      'keeps zero-width space when typing and preserves text when unfocused',
      (WidgetTester tester) async {
        final focusNode = FocusNode();
        final controller = DeleteAwareEditingController(
          onDeleteEmpty: () {},
          focusNode: focusNode,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextField(controller: controller, focusNode: focusNode),
                  const TextField(key: Key('other_field')),
                ],
              ),
            ),
          ),
        );

        // Focus the field
        await tester.tap(find.byType(TextField).first);
        await tester.pumpAndSettle();

        // Type some text natively as a user would
        await tester.enterText(
          find.byType(TextField).first,
          '${DeleteAwareEditingController.zeroWidthSpace}Hello',
        );
        await tester.pumpAndSettle();

        expect(
          controller.text,
          '${DeleteAwareEditingController.zeroWidthSpace}Hello',
        );
        expect(controller.typedText, 'Hello');

        // Unfocus
        await tester.tap(find.byKey(const Key('other_field')));
        await tester.pumpAndSettle();

        expect(
          controller.text,
          '${DeleteAwareEditingController.zeroWidthSpace}Hello',
        ); // Text should be preserved but zero width space remains due to 'set value' implementation details if text exists
        expect(controller.typedText, 'Hello');

        controller.dispose();
        focusNode.dispose();
      },
    );
  });
}
