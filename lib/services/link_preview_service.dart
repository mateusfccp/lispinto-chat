import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/models/image_type.dart';
import 'package:lispinto_chat/models/link_metadata.dart';
import 'package:lispinto_chat/services/html_metadata_parser.dart';
import 'package:logging/logging.dart';

/// Represents the result of fetching information about a link.
sealed class LinkPreviewInfo {
  const LinkPreviewInfo();
}

/// The link is an image.
final class ImageLinkPreviewInfo extends LinkPreviewInfo {
  /// Creates an [ImageLinkPreviewInfo] with the given [imageType].
  const ImageLinkPreviewInfo(this.imageType);

  /// The type of the image (raster or SVG) along with its URL.
  final ImageType imageType;
}

/// The link is a web page with metadata.
final class MetadataLinkPreviewInfo extends LinkPreviewInfo {
  /// Creates a [MetadataLinkPreviewInfo] with the given [metadata].
  const MetadataLinkPreviewInfo(this.metadata);

  /// The metadata extracted from the web page.
  final LinkMetadata metadata;
}

/// A service that fetches information (metadata or image type) from a URL.
interface class LinkPreviewService {
  LinkPreviewService({http.Client? client, HtmlMetadataParser? parser})
    : _client = client ?? http.Client(),
      _parser = parser ?? const HtmlMetadataParser();

  final http.Client _client;
  final HtmlMetadataParser _parser;
  final Map<String, ResultFuture<LinkPreviewInfo?>> _cache = {};

  static final _logger = Logger('LinkPreviewService');

  /// Fetches information for the given [url].
  ///
  /// Returns [ImageLinkPreviewInfo] if the URL is an image,
  /// [MetadataLinkPreviewInfo] if it's a web page with metadata,
  /// or null if fetching fails or no meaningful information is found.
  Future<LinkPreviewInfo?> fetchInfo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return null;
    }

    if (_cache[url]?.result case ValueResult(:final value?)) {
      return value;
    } else if (_cache[url] case final future?) {
      return future;
    }

    final future = _fetchInternal(url, uri);
    _cache[url] = ResultFuture(future);

    try {
      return await future;
    } catch (error, stackTrace) {
      _logger.warning(
        'Error fetching link preview for $url.',
        error,
        stackTrace,
      );
      _cache.remove(url);
      return null;
    }
  }

  Future<LinkPreviewInfo?> _fetchInternal(String url, Uri uri) async {
    try {
      final request = http.Request('GET', uri);
      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 5));

      final contentType =
          streamedResponse.headers['content-type']?.toLowerCase() ?? '';

      // 1. Check if it's an image by content-type
      if (contentType.startsWith('image/svg+xml')) {
        unawaited(streamedResponse.stream.drain());
        return ImageLinkPreviewInfo(SvgImageType(url: url));
      }

      if (contentType.startsWith('image/')) {
        unawaited(streamedResponse.stream.drain());
        return ImageLinkPreviewInfo(RasterImageType(url: url));
      }

      // 2. If octet-stream, check magic bytes
      if (contentType == 'application/octet-stream' || contentType.isEmpty) {
        // Read just enough to check magic bytes
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          final magicResult = _checkMagicBytes(url, response.bodyBytes);
          if (magicResult != null) {
            return ImageLinkPreviewInfo(magicResult);
          }
          // If it didn't match magic bytes but might be HTML?
          // (Rare for octet-stream but possible)
          if (response.body.contains('<html') ||
              response.body.contains('<head')) {
            final metadata = _parser.parse(uri, response.body);
            return metadata != null ? MetadataLinkPreviewInfo(metadata) : null;
          }
        }
        return null;
      }

      // 3. If not HTML, skip
      if (!contentType.contains('text/html')) {
        unawaited(streamedResponse.stream.drain());
        return null;
      }

      // 4. It's HTML, read the full body for metadata
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) return null;

      final metadata = _parser.parse(uri, response.body);
      return metadata != null ? MetadataLinkPreviewInfo(metadata) : null;
    } catch (e) {
      _logger.fine('Failed to fetch info for $url: $e');
      return null;
    }
  }

  ImageType? _checkMagicBytes(String url, Uint8List bytes) {
    if (bytes.length < 2) return null;

    // SVG: <?xml or <svg
    if (bytes.length >= 5 &&
        bytes[0] == 0x3C &&
        bytes[1] == 0x3F &&
        bytes[2] == 0x78 &&
        bytes[3] == 0x6D &&
        bytes[4] == 0x6C) {
      return SvgImageType(url: url);
    } else if (bytes.length >= 4 &&
        bytes[0] == 0x3C &&
        bytes[1] == 0x73 &&
        bytes[2] == 0x76 &&
        bytes[3] == 0x67) {
      return SvgImageType(url: url);
    }
    // JPEG: FF D8 FF
    else if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return RasterImageType(url: url);
    }
    // PNG: 89 50 4E 47
    else if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return RasterImageType(url: url);
    }
    // GIF: 47 49 46 38
    else if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return RasterImageType(url: url);
    }
    // BMP: 42 4D
    else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return RasterImageType(url: url);
    }
    // WebP: RIFF (4 bytes) ... WEBP (4 bytes)
    else if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return RasterImageType(url: url);
    }
    // AVIF: starts with 00 00 00 and contains ftypavif at offset 4
    if (bytes.length >= 12) {
      final sub = String.fromCharCodes(bytes.sublist(4, 12));
      if (sub == 'ftypavif') {
        return RasterImageType(url: url);
      }
    }
    return null;
  }

  /// Gets the cached information for the [url], or null if unknown.
  LinkPreviewInfo? getCachedInfo(String url) {
    return _cache[url]?.result?.asValue?.value;
  }

  @Deprecated('Use fetchInfo instead')
  Future<LinkMetadata?> fetchMetadata(String url) async {
    final info = await fetchInfo(url);
    if (info is MetadataLinkPreviewInfo) {
      return info.metadata;
    }
    return null;
  }
}
