import 'dart:typed_data';

import 'package:http/http.dart' as http;

sealed class ImageType {
  const ImageType();

  /// The URL of the image.
  String get url;
}

final class RasterImageType extends ImageType {
  const RasterImageType({required this.url});

  @override
  final String url;
}

final class SvgImageType extends ImageType {
  const SvgImageType({required this.url});

  @override
  final String url;
}

/// A service that detects if a URL points to an image using HTTP headers and magic bytes.
class LinkImageDetector {
  LinkImageDetector({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, ImageType?> _cache = {};
  final Map<String, Future<ImageType?>> _inFlight = {};

  /// Checks if the given [url] is an image.
  ///
  /// Uses a HEAD request to check Content-Type, and falls back to checking
  /// magic bytes if the content type is application/octet-stream.
  ///
  /// Returns [ImageType.svg] for SVG images, [ImageType.raster] for raster
  /// images, and null if it's not an image or if the URL is invalid.
  Future<ImageType?> isImage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    if (_inFlight[url] case final future?) {
      return future;
    }

    final future = _isImageInternal(url, uri);
    _inFlight[url] = future;
    try {
      final result = await future;
      _cache[url] = result;
      return result;
    } finally {
      _inFlight.remove(url);
    }
  }

  Future<ImageType?> _isImageInternal(String url, Uri uri) async {
    try {
      // 1. Try HEAD request first
      final headResponse = await _client
          .head(uri)
          .timeout(const Duration(seconds: 3));
      final contentType =
          headResponse.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.startsWith('image/svg+xml')) {
        return _cache[url] = SvgImageType(url: url);
      }

      if (contentType.startsWith('image/')) {
        return _cache[url] = RasterImageType(url: url);
      }

      // 2. If octet-stream, check magic bytes
      if (contentType == 'application/octet-stream' || contentType.isEmpty) {
        final getResponse = await _client
            .get(
              uri,
              headers: {'Range': 'bytes=0-15'}, // Sufficient for common formats
            )
            .timeout(const Duration(seconds: 5));

        if (getResponse.statusCode == 200 || getResponse.statusCode == 206) {
          final magicResult = _checkMagicBytes(url, getResponse.bodyBytes);
          if (magicResult != null) {
            return _cache[url] = magicResult;
          }
        }
      }
    } catch (_) {
      // Fallback or handle error
    }

    return null;
  }

  /// Returns true if the status of the [url] is already known.
  bool isKnown(String url) => _cache.containsKey(url);

  /// Gets the cached status of the [url], or null if unknown.
  ImageType? getCachedStatus(String url) => _cache[url];

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
    // AVIF: starts with 00 00 00 and contains ftypavif
    // Usually at offset 4: 66 74 79 70 61 76 69 66
    else if (bytes.length >= 12) {
      final sub = String.fromCharCodes(bytes.sublist(4, 12));
      if (sub == 'ftypavif') {
        return RasterImageType(url: url);
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
}
