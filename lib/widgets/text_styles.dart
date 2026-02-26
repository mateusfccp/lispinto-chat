import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds a [TextSpan] for a mention.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
TextSpan buildMentionText(TextSpan text, String nickname) {
  return TextSpan(
    style: TextStyle(
      color: getNicknameColor(nickname),
      fontWeight: FontWeight.bold,
    ),
    children: [text],
  );
}

/// Builds a [TextSpan] for bold text.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
TextSpan buildBoldText(TextSpan text) {
  return TextSpan(
    style: TextStyle(fontWeight: FontWeight.bold),
    children: [text],
  );
}

/// Builds a [TextSpan] for italic text.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
TextSpan buildItalicText(TextSpan text) {
  return TextSpan(
    style: TextStyle(fontStyle: FontStyle.italic),
    children: [text],
  );
}

/// Builds a [TextSpan] for strikethrough text.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
TextSpan buildStrikethroughText(TextSpan text) {
  return TextSpan(
    style: TextStyle(decoration: TextDecoration.lineThrough),
    children: [text],
  );
}

/// Builds a [TextSpan] for monospace text.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
TextSpan buildMonospaceText(BuildContext context, TextSpan text) {
  return TextSpan(
    style: GoogleFonts.firaCode(
      background: getMonospaceBackgroundPaint(context),
      color: Theme.of(context).colorScheme.primary,
    ),
    children: [text],
  );
}

/// Returns a [Paint] object for the background of monospace text.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
Paint getMonospaceBackgroundPaint(BuildContext context) {
  final paint = Paint()
    ..color = Theme.of(context).colorScheme.surfaceBright
    ..style = PaintingStyle.stroke;

  return paint;
}

/// Builds a [TextSpan] for a hyperlink.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
TextSpan buildLinkText(TextSpan text, String url) {
  return TextSpan(
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
    children: [text],
  );
}

/// Recursively builds a list of [InlineSpan]s with highlighted search query.
List<InlineSpan> buildHighlightedSearchText(
  InlineSpan inlineSpan,
  String query,
) {
  if (query.trim().isEmpty) {
    return [inlineSpan];
  }

  if (inlineSpan is WidgetSpan) {
    return [inlineSpan];
  }

  if (inlineSpan is! TextSpan) {
    return [inlineSpan];
  }

  final baseStyle = inlineSpan.style;

  // Case 1: Span with children
  if (inlineSpan.children != null) {
    final highlightedChildren = <InlineSpan>[];
    for (final child in inlineSpan.children!) {
      highlightedChildren.addAll(buildHighlightedSearchText(child, query));
    }
    return [TextSpan(children: highlightedChildren, style: baseStyle)];
  }

  // Case 2: Span with text
  final text = inlineSpan.text;
  if (text == null) {
    return [inlineSpan];
  }

  final spans = <InlineSpan>[];
  int start = 0;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();

  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index == -1) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      }
      break;
    }

    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }

    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle?.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
        ) ?? const TextStyle(backgroundColor: Color(0x4DFFFF00)),
      ),
    );

    start = index + query.length;
  }

  return spans;
}

final _stylingPattern = RegExp(
  r'(?<url>https?://[^\s]+)'
  r'|(?<mention>@[^\s]+)\s'
  r'|(?<bold>(\*\*|__)(?<boldContent>.+)\4)'
  r'|(?<italic>(\*|_)(?<italicContent>.+)\7)'
  r'|(?<strike>~~(?<strikeContent>.+)~~)'
  r'|(?<code>`(?<codeContent>.+)`)',
);

/// Builds a [TextSpan] with multiple styles applied to the input text.
///
/// This uses a "Master Regex" approach to avoid string fragmentation
/// and support nested styles (e.g., **@user**).
List<InlineSpan> buildStylizedText({
  required BuildContext context,
  required String text,
  bool buildImagePills = false,
}) {
  final spans = <InlineSpan>[];
  int lastMatchEnd = 0;

  for (final match in _stylingPattern.allMatches(text)) {
    // Add text before the match
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
    }

    if (match.namedGroup('url') != null) {
      final url = match.group(0)!;
      if (buildImagePills && _isImageUrl(url)) {
        spans.add(
          WidgetSpan(
            child: _ImagePill(
              pillText: 'image',
              onTap: () async {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
        );
      } else {
        spans.add(buildLinkText(TextSpan(text: url), url));
      }
    } else if (match.namedGroup('mention') case final mention?) {
      spans.addAll([
        buildMentionText(TextSpan(text: mention), mention.substring(1)),
        const TextSpan(text: ' '),
      ]);
    } else if (match.namedGroup('bold') != null) {
      final content = match.namedGroup('boldContent')!;
      spans.add(
        buildBoldText(
          TextSpan(
            children: buildStylizedText(
              context: context,
              text: content,
              buildImagePills: false,
            ),
          ),
        ),
      );
    } else if (match.namedGroup('italic') != null) {
      final content = match.namedGroup('italicContent')!;
      spans.add(
        buildItalicText(
          TextSpan(
            children: buildStylizedText(
              context: context,
              text: content,
              buildImagePills: false,
            ),
          ),
        ),
      );
    } else if (match.namedGroup('strike') != null) {
      final content = match.namedGroup('strikeContent')!;
      spans.add(
        buildStrikethroughText(
          TextSpan(
            children: buildStylizedText(
              context: context,
              text: content,
              buildImagePills: false,
            ),
          ),
        ),
      );
    } else if (match.namedGroup('code') != null) {
      final content = match.namedGroup('codeContent')!;
      spans.add(buildMonospaceText(context, TextSpan(text: content)));
    }

    lastMatchEnd = match.end;
  }

  // Add remaining text
  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastMatchEnd)));
  }

  return spans;
}

bool _isImageUrl(String url) {
  final lowerUrl = url.toLowerCase();
  return lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg') ||
      lowerUrl.endsWith('.png') ||
      lowerUrl.endsWith('.gif') ||
      lowerUrl.endsWith('.webp');
}

final class _ImagePill extends StatelessWidget {
  const _ImagePill({required this.pillText, required this.onTap});

  final String pillText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(32.0),
      color: Theme.of(context).colorScheme.onPrimary,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(32.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsGeometry.symmetric(horizontal: 8.0),
          child: Text(pillText),
        ),
      ),
    );
  }
}
