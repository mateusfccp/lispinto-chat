import 'package:lispinto_chat/widgets/mentions_autocomplete.dart';

/// An autocomplete trigger for the '/dm' command.
final class CommandAutocompleteTrigger implements AutocompleteTrigger {
  /// Creates a [CommandAutocompleteTrigger].
  const CommandAutocompleteTrigger({required this.command});

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
}
