import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:lispinto_chat/models/link_metadata.dart';

/// A parser that extracts metadata from HTML content of a web page.
interface class HtmlMetadataParser {
  /// Creates an [HtmlMetadataParser].
  const HtmlMetadataParser();

  /// Parses the given HTML [body] to extract metadata for the [uri].
  LinkMetadata? parse(Uri uri, String body) {
    final document = html_parser.parse(body);

    final title =
        _getMeta(document, 'og:title') ??
        _getMeta(document, 'twitter:title') ??
        document.querySelector('title')?.text.trim();

    final description =
        _getMeta(document, 'og:description') ??
        _getMeta(document, 'twitter:description') ??
        _getMeta(document, 'description');

    var imageUrl =
        _getMeta(document, 'og:image') ?? _getMeta(document, 'twitter:image');

    if (imageUrl != null) {
      imageUrl = _resolveUrl(uri, imageUrl);
    }

    final siteName =
        _getMeta(document, 'og:site_name') ??
        _getMeta(document, 'twitter:site');

    if (title == null && description == null && imageUrl == null) {
      return null;
    }

    return LinkMetadata(
      url: uri.toString(),
      title: title,
      description: description,
      imageUrl: imageUrl,
      siteName: siteName,
    );
  }

  String? _getMeta(Document document, String property) {
    // Try property (OpenGraph)
    var element = document.querySelector('meta[property="$property"]');
    if (element != null) return element.attributes['content']?.trim();

    // Try name (Twitter/Standard)
    element = document.querySelector('meta[name="$property"]');
    if (element != null) return element.attributes['content']?.trim();

    return null;
  }

  String _resolveUrl(Uri base, String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return '${base.scheme}:$url';
    if (url.startsWith('/')) return '${base.scheme}://${base.host}$url';
    return base.resolve(url).toString();
  }
}
