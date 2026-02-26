import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';
import 'package:mockito/annotations.dart';

import 'chat_screen_test.mocks.dart';

@GenerateMocks([BuildContext])
void main() {
  late MockBuildContext mockContext;

  setUp(() {
    mockContext = MockBuildContext();
  });

  group('Input Area Styling', () {
    test('renders plain text without highlights', () {
      const text = 'Hello world';
      final spans = buildStylizedText(
        context: mockContext,
        text: text,
        buildImagePills: false,
      );

      expect(spans, hasLength(1));
      expect((spans[0] as TextSpan).text, text);
      expect((spans[0] as TextSpan).style, isNull);
    });

    test('highlights mention correctly (User Preferred Logic)', () {
      // User regex requires: (@[^\s]+)\s
      const text = 'Hello @user world';
      final spans = buildStylizedText(
        context: mockContext,
        text: text,
        buildImagePills: false,
      );

      // result:
      //  0: "Hello "
      //  1: Mention wrapper
      //  2: " " (Manual space)
      //  3: "world"
      expect(spans, hasLength(4));

      expect((spans[0] as TextSpan).text, 'Hello ');

      final mentionWrapper = spans[1] as TextSpan;
      expect(mentionWrapper.style?.fontWeight, FontWeight.bold);
      expect((mentionWrapper.children![0] as TextSpan).text, '@user');

      expect((spans[2] as TextSpan).text, ' ');
      expect((spans[3] as TextSpan).text, 'world');
    });

    test('highlights bold text in input area', () {
      const text = 'Hello **bold**';
      final spans = buildStylizedText(
        context: mockContext,
        text: text,
        buildImagePills: false,
      );

      expect(spans, hasLength(2));
      expect((spans[0] as TextSpan).text, 'Hello ');
      
      final boldWrapper = spans[1] as TextSpan;
      expect(boldWrapper.style?.fontWeight, FontWeight.bold);
      expect(boldWrapper.children![0].toPlainText(), 'bold');
    });
  });
}
