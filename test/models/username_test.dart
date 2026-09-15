import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/models/username.dart';

void main() {
  group('UserName.normalize', () {
    test('normalizes identical ASCII nickname without modification', () {
      expect(UserName.normalize('john_doe'), 'john_doe');
    });

    test('replaces spaces with hyphens', () {
      expect(UserName.normalize('john doe'), 'john-doe');
    });

    test('trims whitespace and replaces interior spaces with hyphens', () {
      expect(UserName.normalize('  john doe  '), 'john-doe');
    });

    test('removes punctuation, quotes, and special symbols', () {
      expect(UserName.normalize('{"jsonrpc":"2.0","id":1}'), 'jsonrpc20id1');
    });

    test('truncates to at most 20 characters', () {
      final normalized = UserName.normalize(
        'this_is_a_very_long_username_that_exceeds_limit',
      );
      expect(normalized, 'this_is_a_very_long_');
      expect(normalized.length, 20);
    });

    test('replaces diacritical marks with ASCII base characters', () {
      expect(UserName.normalize('jõão_vítor'), 'joao_vitor');
    });

    test('returns empty string when only invalid characters are present', () {
      expect(UserName.normalize('!@#\$%^&*()'), '');
    });

    test('returns empty string for empty input', () {
      expect(UserName.normalize(''), '');
    });

    test('returns empty string for null input', () {
      expect(UserName.normalize(null), '');
    });
  });

  group('UserName.isValid', () {
    test('returns true for valid nicknames', () {
      expect(UserName.isValid('john_doe'), isTrue);
      expect(UserName.isValid('john doe'), isTrue);
      expect(UserName.isValid('jõão_vítor'), isTrue);
      expect(UserName.isValid('A'), isTrue);
    });

    test('returns false for invalid or empty nicknames', () {
      expect(UserName.isValid(null), isFalse);
      expect(UserName.isValid(''), isFalse);
      expect(UserName.isValid('   '), isFalse);
      expect(UserName.isValid('!@#\$%^&*()'), isFalse);
    });
  });

  group('UserName constructor', () {
    test('creates UserName for valid string', () {
      final user = UserName('john_doe');
      expect(user, 'john_doe');
    });

    test('normalizes input upon creation', () {
      final user = UserName('João Vitor');
      expect(user, 'Joao-Vitor');
    });

    test('throws ArgumentError when input is invalid', () {
      expect(() => UserName('!@#\$%^&*()'), throwsArgumentError);
      expect(() => UserName('   '), throwsArgumentError);
      expect(() => UserName(''), throwsArgumentError);
    });
  });

  group('UserName.tryParse', () {
    test('returns UserName for valid input', () {
      expect(UserName.tryParse('alice'), isNotNull);
      expect(UserName.tryParse('alice')?.value, 'alice');
    });

    test('returns null for null or invalid input', () {
      expect(UserName.tryParse(null), isNull);
      expect(UserName.tryParse(''), isNull);
      expect(UserName.tryParse('!@#'), isNull);
    });
  });

  group('UserNameInputFormatter', () {
    const formatter = UserNameInputFormatter();

    test('formats text by removing diacritics and replacing spaces', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'João Vitor',
        selection: TextSelection.collapsed(offset: 10),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Joao-Vitor');
      expect(result.selection.end, 10);
    });

    test('discards invalid characters and maintains cursor position', () {
      const oldValue = TextEditingValue(
        text: 'user',
        selection: TextSelection.collapsed(offset: 4),
      );
      const newValue = TextEditingValue(
        text: 'user@1!',
        selection: TextSelection.collapsed(offset: 7),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'user1');
      expect(result.selection.end, 5);
    });

    test('enforces maximum length of 20 characters', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '12345678901234567890EXTRA',
        selection: TextSelection.collapsed(offset: 25),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '12345678901234567890');
      expect(result.text.length, 20);
      expect(result.selection.end, 20);
    });
  });
}
