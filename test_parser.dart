import 'dart:async';
import 'package:lispinto_chat/models/chat_message.dart';

void main() {
  final regex = RegExp(
    r'^\|(?:(\d{4}-\d{2}-\d{2}) )?(\d{2}:\d{2}):(\d{2})\| \[(.*?)\]: (.*)$',
  );

  final line = '|12:00:00| [@server]: #general: 5 users';
  final match = regex.firstMatch(line);
  if (match != null) {
    final from = match.group(4);
    final content = match.group(5);
    print('from: $from, content: $content');

    if (from == '@server') {
      print('isServerMessage: true');
    }

    final channelCountMatch = RegExp(
      r'^#([A-Za-z0-9_\-]+): (\d+) users?$',
    ).firstMatch(content!);
    if (channelCountMatch != null) {
      print(
        'channel matched: ${channelCountMatch.group(1)} ${channelCountMatch.group(2)}',
      );
    } else {
      print('channelCountMatch is null');
    }
  } else {
    print('no match');
  }
}
