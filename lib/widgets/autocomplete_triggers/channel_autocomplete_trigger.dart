import 'package:lispinto_chat/widgets/autocomplete_dropdown.dart';

/// An autocomplete trigger for tagging channels with '#'.
final class ChannelAutocompleteTrigger implements AutocompleteTrigger {
  /// Creates a [ChannelAutocompleteTrigger].
  const ChannelAutocompleteTrigger({required this.suggestions});

  @override
  String? triggerDetector(String textBeforeCursor) {
    final lastSpaceIndex = textBeforeCursor.lastIndexOf(RegExp(r'[\s]'));
    final startIndex = lastSpaceIndex == -1 ? 0 : lastSpaceIndex + 1;
    final currentWord = textBeforeCursor.substring(startIndex);
    if (currentWord.startsWith('#')) {
      return currentWord.substring(1);
    } else {
      return null;
    }
  }

  @override
  String formatSelection(String selection) => selection;

  @override
  final List<String> suggestions;
}
