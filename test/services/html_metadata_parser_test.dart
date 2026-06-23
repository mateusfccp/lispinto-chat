import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/services/html_metadata_parser.dart';

void main() {
  group('HtmlMetadataParser', () {
    const parser = HtmlMetadataParser();

    test('extracts OpenGraph metadata', () {
      final uri = Uri.parse('https://example.com/page');
      const html = '''
        <html>
          <head>
            <title>Test Page</title>
            <meta property="og:title" content="OG Title">
            <meta property="og:description" content="OG Description">
            <meta property="og:image" content="https://example.com/preview.jpg">
            <meta property="og:site_name" content="My Site">
          </head>
        </html>
      ''';

      final metadata = parser.parse(uri, html);

      expect(metadata, isNotNull);
      expect(metadata!.title, 'OG Title');
      expect(metadata.description, 'OG Description');
      expect(metadata.imageUrl, 'https://example.com/preview.jpg');
      expect(metadata.siteName, 'My Site');
      expect(metadata.url, uri.toString());
    });

    test('extracts Twitter metadata', () {
      final uri = Uri.parse('https://example.com/page');
      const html = '''
        <html>
          <head>
            <meta name="twitter:title" content="Twitter Title">
            <meta name="twitter:description" content="Twitter Description">
            <meta name="twitter:image" content="https://example.com/twitter.jpg">
            <meta name="twitter:site" content="Twitter Site">
          </head>
        </html>
      ''';

      final metadata = parser.parse(uri, html);

      expect(metadata, isNotNull);
      expect(metadata!.title, 'Twitter Title');
      expect(metadata.description, 'Twitter Description');
      expect(metadata.imageUrl, 'https://example.com/twitter.jpg');
      expect(metadata.siteName, 'Twitter Site');
    });

    test('falls back to standard metadata if OG/Twitter missing', () {
      final uri = Uri.parse('https://example.com/page');
      const html = '''
        <html>
          <head>
            <title>Standard Title</title>
            <meta name="description" content="Standard Description">
          </head>
        </html>
      ''';

      final metadata = parser.parse(uri, html);

      expect(metadata, isNotNull);
      expect(metadata!.title, 'Standard Title');
      expect(metadata.description, 'Standard Description');
      expect(metadata.imageUrl, isNull);
      expect(metadata.siteName, isNull);
    });

    test('resolves relative URLs for images', () {
      final uri = Uri.parse('https://example.com/blog/post');

      const html = '''
        <html>
          <head>
            <meta property="og:image" content="/images/preview.jpg">
          </head>
        </html>
      ''';

      final metadata = parser.parse(uri, html);

      expect(metadata, isNotNull);
      // Absolute path from host
      expect(metadata!.imageUrl, 'https://example.com/images/preview.jpg');

      const html2 = '''
        <html>
          <head>
            <meta property="og:image" content="assets/preview.png">
          </head>
        </html>
      ''';

      final metadata2 = parser.parse(uri, html2);
      expect(metadata2, isNotNull);
      // Relative path resolution
      expect(
        metadata2!.imageUrl,
        'https://example.com/blog/assets/preview.png',
      );

      const html3 = '''
        <html>
          <head>
            <meta property="og:image" content="//cdn.example.com/preview.gif">
          </head>
        </html>
      ''';

      final metadata3 = parser.parse(uri, html3);
      expect(metadata3, isNotNull);
      // Protocol-relative resolution
      expect(metadata3!.imageUrl, 'https://cdn.example.com/preview.gif');
    });

    test('returns null when no metadata is found', () {
      final uri = Uri.parse('https://example.com/page');
      const html = '''
        <html>
          <head>
            <!-- Just an empty head -->
          </head>
          <body>Hello world</body>
        </html>
      ''';

      final metadata = parser.parse(uri, html);

      expect(metadata, isNull);
    });
  });
}
