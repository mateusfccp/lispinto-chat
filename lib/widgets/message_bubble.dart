import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/link_image_detector.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays a single chat message bubble.
final class MessageBubble extends StatefulWidget {
  /// Creates a [MessageBubble].
  const MessageBubble({
    super.key,
    required this.message,
    required this.searchQuery,
  });

  /// The chat [message] to display in this bubble.
  final ChatMessage message;

  /// The current active search query to highlight in the message content.
  final String searchQuery;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  List<ImageType> _imageTypes = [];
  final Map<String, TapGestureRecognizer> _linkRecognizers = {};
  final Map<String, TapGestureRecognizer> _channelRecognizers = {};

  @override
  void dispose() {
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
    for (final recognizer in _channelRecognizers.values) {
      recognizer.dispose();
    }
    _channelRecognizers.clear();
    super.dispose();
  }

  TapGestureRecognizer _getRecognizer(String url) {
    return _linkRecognizers.putIfAbsent(
      url,
      () => TapGestureRecognizer()..onTap = () => _launchUrl(url),
    );
  }

  TapGestureRecognizer _getChannelRecognizer(String channel) {
    return _channelRecognizers.putIfAbsent(
      channel,
      () =>
          TapGestureRecognizer()
            ..onTap = () => locator<ChatProvider>().joinChannel(channel),
    );
  }

  @override
  void initState() {
    super.initState();
    _detectImages();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      for (final recognizer in _linkRecognizers.values) {
        recognizer.dispose();
      }
      _linkRecognizers.clear();
      for (final recognizer in _channelRecognizers.values) {
        recognizer.dispose();
      }
      _channelRecognizers.clear();
      _detectImages();
    }
  }

  Future<void> _detectImages() async {
    final pattern = RegExp(r'https?://\S+');
    final urls = [
      for (final match in pattern.allMatches(widget.message.content))
        ?match.group(0),
    ];
    if (urls.isEmpty) {
      if (mounted) setState(() => _imageTypes = []);
      return;
    }

    final detector = locator<LinkImageDetector>();

    // Check if we already have these cached to avoid flicker
    final cachedResults = [
      for (final url in urls) ?detector.getCachedStatus(url),
    ];

    if (cachedResults.length == urls.length) {
      if (mounted) setState(() => _imageTypes = cachedResults);
      return;
    }

    final results = await [for (final url in urls) detector.isImage(url)].wait;

    if (mounted) {
      setState(() {
        _imageTypes = [for (final result in results) ?result];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showImagePreviews = locator
        .get<UserConfiguration>()
        .showImagePreviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.message.isSystemMessage
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      getNicknameColor(
                        widget.message.from,
                      ).withValues(alpha: 0.5),
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
        if (_imageTypes.isNotEmpty && showImagePreviews)
          _ImageGallery(imageTypes: _imageTypes, onImageTap: _launchUrl),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final showImagePreviews = locator
        .get<UserConfiguration>()
        .showImagePreviews;

    final stylizedSpans = buildStylizedText(
      context: context,
      text: widget.message.content,
      buildImagePills: showImagePreviews,
      linkRecognizerFactory: _getRecognizer,
      channelRecognizerFactory: _getChannelRecognizer,
    );

    return SelectableText.rich(
      TextSpan(
        children: [
          if (widget.message.date case final date?)
            TextSpan(
              text: _getTimestampText(date),
              style: const TextStyle(color: Colors.grey, fontSize: 12.0),
            ),
          TextSpan(
            text: '[${widget.message.from}]: ',
            style: TextStyle(
              color: getNicknameColor(widget.message.from),
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final span in stylizedSpans)
            ...buildHighlightedSearchText(span, widget.searchQuery),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _getTimestampText(DateTime date) {
    final showSeconds = locator.get<UserConfiguration>().showTimeSeconds;
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

final class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.imageTypes, this.onImageTap});

  static final _imageSize = 120.0;

  final List<ImageType> imageTypes;
  final ValueSetter<String>? onImageTap;

  @override
  Widget build(BuildContext context) {
    final onImageTap = this.onImageTap;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: imageTypes.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8.0),
          itemBuilder: (context, index) {
            final imageType = imageTypes[index];
            return MouseRegion(
              cursor: onImageTap == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onImageTap == null
                    ? null
                    : () => onImageTap(imageType.url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: switch (imageType) {
                    SvgImageType(:final url) => SvgPicture.network(
                      url,
                      height: _imageSize,
                      width: _imageSize,
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) => Container(
                        width: _imageSize,
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    RasterImageType(:final url) => Image.network(
                      url,
                      height: _imageSize,
                      width: _imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: _imageSize,
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
