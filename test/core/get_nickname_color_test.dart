import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';

void main() {
  group('getUserColor', () {
    test('returns exact server color for @server', () {
      final color = getNicknameColor('@server');
      expect(color, const Color(0xffbb2222));
    });

    test('returns consistent color for same nickname', () {
      final color1 = getNicknameColor('Pintass');
      final color2 = getNicknameColor('Pintass');
      expect(color1, equals(color2));
    });

    test('handles unicode and diacritics', () {
      final color1 = getNicknameColor('Pintassíssimo');
      final color2 = getNicknameColor('Pintassíssimo');
      expect(color1, equals(color2));

      // Should likely differ from regular Pintass
      final color3 = getNicknameColor('Pintassimmo');
      expect(color1, isNot(equals(color3)));
    });
  });
}
