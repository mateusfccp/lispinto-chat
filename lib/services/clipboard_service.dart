import 'dart:typed_data';

/// Interface for services that interact with the system clipboard.
abstract interface class ClipboardService {
  /// Reads raw image bytes from the clipboard, if available.
  Future<Uint8List?> getImage();

  /// Reads file paths from the clipboard, if available.
  Future<List<String>> getFiles();

  /// Writes raw image [imageBytes] to the clipboard.
  Future<void> writeImage(Uint8List imageBytes);

  /// Writes [text] to the clipboard.
  Future<void> writeText(String text);
}
