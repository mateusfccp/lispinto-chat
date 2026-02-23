import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lisp_chat_client/core/get_user_color.dart';

void main() {
  group('getUserColor', () {
    test('returns exact server color for @server', () {
      final color = getUserColor('@server');
      expect(color, const Color(0xffbb2222));
    });

    test('returns consistent color for same username', () {
      final color1 = getUserColor('Pintass');
      final color2 = getUserColor('Pintass');
      expect(color1, equals(color2));
    });

    test('handles unicode and diacritics', () {
      final color1 = getUserColor('Pintassíssimo');
      final color2 = getUserColor('Pintassíssimo');
      expect(color1, equals(color2));

      // Should likely differ from regular Pintass
      final color3 = getUserColor('Pintassimmo');
      expect(color1, isNot(equals(color3)));
    });
  });
}
