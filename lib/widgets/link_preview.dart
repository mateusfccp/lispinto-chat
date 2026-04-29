import 'package:flutter/material.dart';
import 'package:lispinto_chat/models/link_metadata.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays a preview card for a link.
final class LinkPreview extends StatelessWidget {
  /// Creates a [LinkPreview].
  const LinkPreview({super.key, required this.metadata});

  /// The metadata to display in this preview.
  final LinkMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () async {
          final uri = Uri.tryParse(metadata.url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (metadata.imageUrl case final imageUrl?)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12.0),
                ),
                child: Image.network(
                  imageUrl,
                  height: 100.0,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: metadata.hasTextualContent ? 8.0 : 0.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4.0,
                children: [
                  if (metadata.siteName case final siteName?)
                    Text(
                      siteName,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (metadata.title case final title?) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (metadata.description case final description?) ...[
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final child = metadata.imageUrl == null
        ? content
        : AspectRatio(aspectRatio: 4.0 / 3.0, child: content);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 300.0),
        child: child,
      ),
    );
  }
}
