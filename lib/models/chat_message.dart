import 'package:logging/logging.dart';

/// Represents a single chat message.
final class ChatMessage {
  static final _logger = Logger('ChatMessage');

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
    final [fullMatch, date, timeHM, timeS, from, content] = match;

    if (from == null) {
      _logger.severe(
        'Parsed message is missing the sender (from) field. Full match: $fullMatch',
      );
      throw ArgumentError('Parsed message is missing the sender (from) field.');
    }

    if (content == null) {
      _logger.severe(
        'Parsed message is missing the content field. Full match: $fullMatch',
      );
      throw ArgumentError('Parsed message is missing the content field.');
    }

    if (timeHM != null && timeS != null) {
      final now = DateTime.now();
      final dateString =
          date ??
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      try {
        final dateTimeString = '$dateString $timeHM:$timeS';
        final parsedDate = DateTime.parse(dateTimeString);
        return ChatMessage(date: parsedDate, from: from, content: content);
      } catch (_) {
        return ChatMessage(date: now, from: from, content: content);
      }
    } else {
      return ChatMessage(date: DateTime.now(), from: from, content: content);
    }
  }
}
