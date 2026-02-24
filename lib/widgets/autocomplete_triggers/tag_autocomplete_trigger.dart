import 'package:lispinto_chat/widgets/mentions_autocomplete.dart';

/// An autocomplete trigger for tagging users with '@'.
final class TagAutocompleteTrigger implements AutocompleteTrigger {
  /// Creates a [TagAutocompleteTrigger].
  const TagAutocompleteTrigger();

  @override
  String? triggerDetector(String textBeforeCursor) {
    final lastSpaceIndex = textBeforeCursor.lastIndexOf(RegExp(r'[\s]'));
    final startIndex = lastSpaceIndex == -1 ? 0 : lastSpaceIndex + 1;
    final currentWord = textBeforeCursor.substring(startIndex);
    if (currentWord.startsWith('@')) {
      return currentWord.substring(1);
    } else {
      return null;
    }
  }
}
