import 'package:diacritic/diacritic.dart';
import 'package:flutter/services.dart';

/// Extension type representing a normalized and validated user name.
extension type const UserName._(String value) implements String {
  /// Maximum length allowed for a username.
  static const int maxLength = 20;

  /// Creates a [UserName].
  ///
  /// Throws an [ArgumentError] if the [value] cannot form a valid username.
  factory UserName(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) {
      throw ArgumentError('Invalid username: $value');
    } else {
      return UserName._(normalized);
    }
  }

  /// Creates a [UserName] from [value], or `null` if invalid.
  static UserName? tryParse(String? value) {
    if (value == null) {
      return null;
    } else {
      final normalized = normalize(value);
      if (normalized.isEmpty) {
        return null;
      } else {
        return UserName._(normalized);
      }
    }
  }

  /// Normalizes [username] according to server normalization rules.
  ///
  /// The rules are:
  /// - Strips leading and trailing whitespace
  /// - Removes diacritics
  /// - Replaces spaces with hyphens
  /// - Retains only letters (`a-z`, `A-Z`), digits (`0-9`), `_`, and `-`
  /// - Truncates to at most [maxLength] characters
  static String normalize(String? username) {
    if (username == null) {
      return '';
    } else {
      final trimmed = username.trim();
      final withoutDiacritics = removeDiacritics(trimmed);
      final cleanedChars = [
        for (final char in withoutDiacritics.split('')) ?_cleanChar(char),
      ];
      final joined = cleanedChars.join();
      if (joined.length > maxLength) {
        return joined.substring(0, maxLength);
      } else {
        return joined;
      }
    }
  }

  /// Returns true if [username] can produce a valid, non-empty username.
  static bool isValid(String? username) {
    if (username == null || username.trim().isEmpty) {
      return false;
    } else {
      return normalize(username).isNotEmpty;
    }
  }

  static String? _cleanChar(String char) {
    if (char == ' ') {
      return '-';
    } else {
      final codeUnit = char.codeUnitAt(0);
      final isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
      final isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
      final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      final isAllowedSymbol = char == '_' || char == '-';
      if (isLower || isUpper || isDigit || isAllowedSymbol) {
        return char;
      } else {
        return null;
      }
    }
  }
}

/// A [TextInputFormatter] for usernames.
///
/// It updates the text in real time according to [UserName.normalize] rules and
/// limits length to [UserName.maxLength].
final class UserNameInputFormatter extends TextInputFormatter {
  /// Creates a [UserNameInputFormatter].
  const UserNameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final withoutDiacritics = removeDiacritics(newValue.text);
    final buffer = StringBuffer();
    final selectionOffset = newValue.selection.end;
    var newCursorPosition = 0;

    for (var i = 0; i < withoutDiacritics.length; i++) {
      if (buffer.length >= UserName.maxLength) {
        break;
      }
      final char = withoutDiacritics[i];
      final cleaned = UserName._cleanChar(char);
      if (cleaned != null) {
        buffer.write(cleaned);
        if (i < selectionOffset) {
          newCursorPosition += cleaned.length;
        }
      }
    }

    final formattedText = buffer.toString();
    final clampedOffset = newCursorPosition.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: clampedOffset),
    );
  }
}
