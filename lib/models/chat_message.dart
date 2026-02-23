/// Represents a single chat message.
final class ChatMessage {
  /// The date and time when the message was sent.
  ///
  /// This may be null for messages that don't include a timestamp.
  final DateTime? date;

  /// The nickname of the sender.
  ///
  /// Special senders like the server start with '@', e.g. '@server'.
  final String from;

  /// The content of the message.
  final String content;

  /// Creates a [ChatMessage].
  ChatMessage({this.date, required this.from, required this.content});

  bool get isServerMessage => from == '@server';

  /// Factory constructor to create a [ChatMessage] from a parsed regex match.
  factory ChatMessage.fromParsed(List<String?> match) {
    // Match structure: [fullMatch, date, timeHM, timeS, from, content]
    final [fullMatch, date, timeHM, timeS, from, content] = match;

    if (date != null && timeHM != null && timeS != null) {
      final dateTimeString = '$date $timeHM:$timeS';
      final parsedDate = DateTime.parse(dateTimeString);

      return ChatMessage(date: parsedDate, from: from!, content: content!);
    } else {
      return ChatMessage(date: DateTime.now(), from: from!, content: content!);
    }
  }
}
