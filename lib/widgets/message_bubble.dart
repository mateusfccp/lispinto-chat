import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays a single chat message bubble.
final class MessageBubble extends StatelessWidget {
  /// Creates a [MessageBubble].
  const MessageBubble({
    super.key,
    required this.message,
    this.searchQuery = '',
    this.showSeconds = false,
  });

  /// The chat [message] to display in this bubble.
  final ChatMessage message;

  /// The current active search query to highlight in the message content.
  final String searchQuery;

  /// Whether to show seconds in the timestamp.
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: message.isSystemMessage
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  getNicknameColor(message.from).withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: SelectableText.rich(
          TextSpan(
            children: [
              if (message.date case final date?)
                TextSpan(
                  text: _getTimestampText(date),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              TextSpan(
                text: '[${message.from}]: ',
                style: TextStyle(
                  color: getNicknameColor(message.from),
                  fontWeight: FontWeight.bold,
                ),
              ),
              ..._parseContent(context, message.content),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimestampText(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (showSeconds) {
      final second = date.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second ';
    } else {
      return '$hour:$minute ';
    }
  }

  List<InlineSpan> _parseContent(BuildContext context, String text) {
    final spans = <InlineSpan>[];

    final pattern = RegExp(
      r'(https?://[^\s]+)' // 1: url
      r'|(@[^\s]+)' // 2: mention
      r'|\*\*(.*?)\*\*' // 3: bold1
      r'|__(.*?)__' // 4: bold2
      r'|\*(.*?)\*' // 5: italic1
      r'|_(.*?)_' // 6: italic2
      r'|~~(.*?)~~' // 7: strike
      r'|`(.*?)`', // 8: code
    );

    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.addAll(
          _highlightSearchText(
            text.substring(lastMatchEnd, match.start),
            const TextStyle(color: Colors.white),
          ),
        );
      }

      if (match.group(1) != null) {
        // url
        final url = match.group(1)!;
        spans.add(
          TextSpan(
            text: url,
            style: const TextStyle(
              color: Colors.blueAccent,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
          ),
        );
      } else if (match.group(2) != null) {
        // mention
        final mention = match.group(2)!;
        final user = mention.substring(1);
        spans.addAll(
          _highlightSearchText(
            mention,
            TextStyle(
              color: getNicknameColor(user),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (match.group(3) != null || match.group(4) != null) {
        // bold
        final content = match.group(3) ?? match.group(4)!;
        spans.addAll(
          _highlightSearchText(
            content,
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      } else if (match.group(5) != null || match.group(6) != null) {
        // italic
        final content = match.group(5) ?? match.group(6)!;
        spans.addAll(
          _highlightSearchText(
            content,
            const TextStyle(fontStyle: FontStyle.italic, color: Colors.white),
          ),
        );
      } else if (match.group(7) != null) {
        // strike
        final content = match.group(7)!;
        spans.addAll(
          _highlightSearchText(
            content,
            const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.white,
            ),
          ),
        );
      } else if (match.group(8) != null) {
        // code
        final content = match.group(8)!;
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.addAll(
        _highlightSearchText(
          text.substring(lastMatchEnd),
          const TextStyle(color: Colors.white),
        ),
      );
    }

    return spans;
  }

  List<InlineSpan> _highlightSearchText(String text, TextStyle baseStyle) {
    if (searchQuery.trim().isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    int start = 0;
    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + searchQuery.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          ),
        ),
      );

      start = index + searchQuery.length;
    }

    return spans;
  }
}
