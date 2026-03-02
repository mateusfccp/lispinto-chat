import 'dart:typed_data';

/// Interface for services that can upload an image from bytes and return a URL.
abstract interface class ImageUploadService {
  /// Uploads the given [imageBytes] and returns the resulting uploaded image URL.
  Future<String> uploadImage(Uint8List imageBytes);
}
