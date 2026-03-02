import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/services/image_upload_service.dart';

/// Service for uploading images to ImgBB.
class ImgBBImageUploadService implements ImageUploadService {
  /// Creates an [ImgBBImageUploadService] with the given [apiKey].
  const ImgBBImageUploadService({required this.apiKey});

  /// The ImgBB API key.
  final String apiKey;

  @override
  Future<String> uploadImage(Uint8List imageBytes) async {
    final uri = Uri.parse('https://api.imgbb.com/1/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['key'] = apiKey
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.png',
        ),
      );

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final json = jsonDecode(responseBody);
      if (json['success'] == true) {
        return json['data']['url'];
      } else {
        throw Exception(
          'ImgBB API returned failure: ${json['error']['message']}',
        );
      }
    } else {
      throw Exception(
        'Failed to upload image. Status code: ${response.statusCode}',
      );
    }
  }
}
