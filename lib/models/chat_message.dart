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

  /// Whether the message is a system message.
  ///
  /// System messages include messages sent by the server and messages sent by
  /// commands.
  bool get isSystemMessage => isServerMessage || isCommandMessage;

  /// Whether the message was sent by the server.
  ///
  /// Messages sent by the server are not logged in the backend and won't
  /// come in a /log command.
  bool get isServerMessage => from == '@server';

  /// Whether the message was sent by a command.
  bool get isCommandMessage => from == '@command';

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
