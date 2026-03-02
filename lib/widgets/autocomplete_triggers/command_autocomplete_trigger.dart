import 'package:lispinto_chat/widgets/autocomplete_dropdown.dart';

/// An autocomplete trigger for the '/dm' command.
final class CommandAutocompleteTrigger implements AutocompleteTrigger {
  /// Creates a [CommandAutocompleteTrigger].
  const CommandAutocompleteTrigger({
    required this.command,
    required this.suggestions,
  });

  final String command;

  static final _spaces = RegExp(r'\s+');

  @override
  String? triggerDetector(String textBeforeCursor) {
    if (textBeforeCursor.startsWith('/$command ')) {
      final parts = textBeforeCursor.split(_spaces);
      if (parts.length == 2) {
        return parts[1];
      }
    }

    return null;
  }

  @override
  String formatSelection(String selection) => selection;

  @override
  final List<String> suggestions;
}
