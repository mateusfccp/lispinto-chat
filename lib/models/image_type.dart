/// The type of an image detected from a URL.
sealed class ImageType {
  const ImageType();

  /// The URL of the image.
  String get url;
}

/// A raster image (JPEG, PNG, GIF, BMP, WebP, AVIF).
final class RasterImageType extends ImageType {
  const RasterImageType({required this.url});

  @override
  final String url;
}

/// An SVG image.
final class SvgImageType extends ImageType {
  const SvgImageType({required this.url});

  @override
  final String url;
}
