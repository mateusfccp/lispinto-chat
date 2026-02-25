import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'chat_screen_test.mocks.dart';

@GenerateMocks([BuildContext])
void main() {
  late MockBuildContext mockContext;

  setUp(() {
    mockContext = MockBuildContext();
  });

  group('buildTextWithMentionsHighlight', () {
    test('renders plain text without highlights', () {
      const text = 'Hello world';
      final span = buildTextWithMentionsHighlight(
        mockContext,
        text,
        null,
        false,
      );

      expect(span.text, isNull);
      expect(span.children, hasLength(1));
      expect((span.children![0] as TextSpan).text, text);
      expect((span.children![0] as TextSpan).style, isNull);
    });

    test('highlights mention with trailing space', () {
      const text = 'Hello @user world';
      final span = buildTextWithMentionsHighlight(
        mockContext,
        text,
        null,
        false,
      );

      // Children: ["Hello ", "@user ", "world"]
      expect(span.children, hasLength(3));
      
      final first = span.children![0] as TextSpan;
      expect(first.text, 'Hello ');
      
      final second = span.children![1] as TextSpan;
      expect(second.text, '@user ');
      expect(second.style?.color, isNotNull);
      expect(second.style?.fontWeight, FontWeight.bold);
      
      final third = span.children![2] as TextSpan;
      expect(third.text, 'world');
    });

    test('does NOT highlight mention without trailing space', () {
      const text = 'Hello @user';
      final span = buildTextWithMentionsHighlight(
        mockContext,
        text,
        null,
        false,
      );

      // Children: ["Hello @user"]
      expect(span.children, hasLength(1));
      expect((span.children![0] as TextSpan).text, text);
    });

    test('highlights multiple mentions', () {
      const text = '@alice @bob ';
      final span = buildTextWithMentionsHighlight(
        mockContext,
        text,
        null,
        false,
      );

      // Children: ["@alice ", "@bob "]
      expect(span.children, hasLength(2));
      
      final first = span.children![0] as TextSpan;
      expect(first.text, '@alice ');
      expect(first.style?.color, isNotNull);
      
      final second = span.children![1] as TextSpan;
      expect(second.text, '@bob ');
      expect(second.style?.color, isNotNull);
    });
    
    test('works with custom base style', () {
      const text = '@user ';
      const baseStyle = TextStyle(fontSize: 20);
      final span = buildTextWithMentionsHighlight(
        mockContext,
        text,
        baseStyle,
        false,
      );

      final mentionSpan = span.children![0] as TextSpan;
      expect(mentionSpan.style?.fontSize, 20);
      expect(mentionSpan.style?.fontWeight, FontWeight.bold);
    });
  });
}
