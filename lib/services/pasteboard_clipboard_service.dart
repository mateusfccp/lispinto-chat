import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

import 'clipboard_service.dart';

/// Implementation of [ClipboardService] using the `pasteboard` package.
final class PasteboardClipboardService implements ClipboardService {
  /// Creates a [PasteboardClipboardService].
  const PasteboardClipboardService();

  @override
  Future<Uint8List?> getImage() => Pasteboard.image;

  @override
  Future<List<String>> getFiles() => Pasteboard.files();

  @override
  Future<void> writeImage(Uint8List imageBytes) {
    return Pasteboard.writeImage(imageBytes);
  }

  @override
  Future<void> writeText(String text) async {
    Pasteboard.writeText(text);
  }
}
