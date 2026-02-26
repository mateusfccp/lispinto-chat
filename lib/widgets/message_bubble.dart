import 'package:flutter/material.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays a single chat message bubble.
final class MessageBubble extends StatelessWidget {
  /// Creates a [MessageBubble].
  const MessageBubble({
    super.key,
    required this.message,
    this.searchQuery = '',
    this.showSeconds = false,
    this.showImagePreviews = true,
  });

  /// The chat [message] to display in this bubble.
  final ChatMessage message;

  /// The current active search query to highlight in the message content.
  final String searchQuery;

  /// Whether to show seconds in the timestamp.
  final bool showSeconds;

  /// Whether to show in-line image previews.
  final bool showImagePreviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
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
            child: _buildContent(context),
          ),
        ),
        if (showImagePreviews) _buildGallery(context, message.content),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return SelectableText.rich(
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
          ...() {
            final stylizedSpans = buildStylizedText(
              context: context,
              text: message.content,
              buildImagePills: showImagePreviews,
            );
            if (searchQuery.isEmpty) {
              return stylizedSpans;
            } else {
              return [
                for (final span in stylizedSpans)
                  ...buildHighlightedSearchText(span, searchQuery),
              ];
            }
          }(),
        ],
      ),
    );
  }

  Widget _buildGallery(BuildContext context, String text) {
    final imageUrls = _getImageUrls(text);
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: imageUrls.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8.0),
          itemBuilder: (context, index) {
            final url = imageUrls[index];
            return GestureDetector(
              onTap: () => _launchUrl(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  url,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 120,
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> _getImageUrls(String text) {
    final pattern = RegExp(r'https?://[^\s]+');
    return pattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where(_isImageUrl)
        .toList();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp');
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
}
