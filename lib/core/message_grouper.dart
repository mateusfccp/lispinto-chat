import 'package:meta/meta.dart';
import 'package:lispinto_chat/models/chat_message.dart';

/// A utility to group sequential chat messages.
final class MessageGrouper {
  /// Creates a [MessageGrouper].
  const MessageGrouper();

  /// Groups sequential messages from the same user at the exact same time.
  ///
  /// When messages are grouped, their content is joined with a newline.
  List<ChatMessage> group(List<ChatMessage> messages) {
    if (messages.isEmpty) return [];

    final result = <ChatMessage>[];
    ChatMessage? currentGroup;

    for (final message in messages) {
      if (currentGroup == null) {
        currentGroup = message;
        continue;
      }

      if (canGroup(currentGroup, message)) {
        currentGroup = ChatMessage(
          date: currentGroup.date,
          from: currentGroup.from,
          content: '${currentGroup.content}\n${message.content}',
        );
      } else {
        result.add(currentGroup);
        currentGroup = message;
      }
    }

    if (currentGroup != null) {
      result.add(currentGroup);
    }

    return result;
  }

  /// Whether two messages can be grouped together.
  @visibleForTesting
  bool canGroup(ChatMessage a, ChatMessage b) {
    if (a.from != b.from) return false;

    // We only group messages that have a date.
    if (a.date == null || b.date == null) return false;

    // Check if they have the exact same timestamp (down to the second).
    return a.date!.year == b.date!.year &&
        a.date!.month == b.date!.month &&
        a.date!.day == b.date!.day &&
        a.date!.hour == b.date!.hour &&
        a.date!.minute == b.date!.minute &&
        a.date!.second == b.date!.second;
  }
}
