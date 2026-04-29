/// Represents metadata fetched from a URL for a link preview.
final class LinkMetadata {
  /// Creates a [LinkMetadata].
  const LinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  /// The title of the page.
  final String? title;

  /// A brief description of the page content.
  final String? description;

  /// The URL of a preview image for the page.
  final String? imageUrl;

  /// The canonical URL of the page.
  final String url;

  /// The name of the site.
  final String? siteName;

  /// Whether this metadata contains any textual content.
  ///
  /// If any of the title, description, or site name is present, this returns
  /// true.
  bool get hasTextualContent {
    return title != null || description != null || siteName != null;
  }

  @override
  String toString() {
    return 'LinkMetadata(url: $url, title: $title, description: $description, imageUrl: $imageUrl, siteName: $siteName)';
  }
}
