import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/models/image_type.dart';
import 'package:lispinto_chat/services/link_preview_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
import 'link_preview_service_test.mocks.dart';

void main() {
  late LinkPreviewService service;
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
    service = LinkPreviewService(client: mockClient);
  });

  group('LinkPreviewService', () {
    test('identifies image via Content-Type image/jpeg', () async {
      const url = 'https://example.com/image.jpg';
      
      final response = http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {'content-type': 'image/jpeg'},
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      final result = await service.fetchInfo(url);
      
      expect(result, isA<ImageLinkPreviewInfo>());
      final imageInfo = result as ImageLinkPreviewInfo;
      expect(imageInfo.imageType, isA<RasterImageType>());
      expect(imageInfo.imageType.url, url);
      
      // Verify only one request was sent
      verify(mockClient.send(any)).called(1);
    });

    test('identifies SVG via Content-Type image/svg+xml', () async {
      const url = 'https://example.com/logo.svg';
      final response = http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {'content-type': 'image/svg+xml'},
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      final result = await service.fetchInfo(url);
      
      expect(result, isA<ImageLinkPreviewInfo>());
      expect((result as ImageLinkPreviewInfo).imageType, isA<SvgImageType>());
    });

    test('identifies image via magic bytes for application/octet-stream', () async {
      const url = 'https://example.com/binary';
      // PNG magic bytes + some extra to reach length 12
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x00
      ]);
      
      final response = http.StreamedResponse(
        Stream.value(pngBytes),
        200,
        headers: {'content-type': 'application/octet-stream'},
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      final result = await service.fetchInfo(url);
      
      expect(result, isA<ImageLinkPreviewInfo>());
      expect((result as ImageLinkPreviewInfo).imageType, isA<RasterImageType>());
    });

    test('extracts metadata from HTML page', () async {
      const url = 'https://example.com/page';
      const html = '''
        <html>
          <head>
            <title>Test Page</title>
            <meta property="og:description" content="A test description">
            <meta property="og:image" content="/preview.jpg">
          </head>
        </html>
      ''';
      
      final response = http.StreamedResponse(
        Stream.value(Uint8List.fromList(html.codeUnits)),
        200,
        headers: {'content-type': 'text/html'},
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      final result = await service.fetchInfo(url);
      
      expect(result, isA<MetadataLinkPreviewInfo>());
      final metadata = (result as MetadataLinkPreviewInfo).metadata;
      expect(metadata.title, 'Test Page');
      expect(metadata.description, 'A test description');
      expect(metadata.imageUrl, 'https://example.com/preview.jpg');
    });

    test('caches results and avoids redundant requests', () async {
      const url = 'https://example.com/cached';
      final response = http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {'content-type': 'image/png'},
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      await service.fetchInfo(url);
      await service.fetchInfo(url);
      
      final cached = service.getCachedInfo(url);
      expect(cached, isNotNull);
      
      verify(mockClient.send(any)).called(1);
    });

    test('returns null for failed requests', () async {
      const url = 'https://example.com/404';
      final response = http.StreamedResponse(
        const Stream.empty(),
        404,
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      final result = await service.fetchInfo(url);
      expect(result, isNull);
    });

    test('handles non-image/non-html content', () async {
      const url = 'https://example.com/data.json';
      final response = http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {'content-type': 'application/json'},
      );

      when(mockClient.send(any)).thenAnswer((_) async => response);

      final result = await service.fetchInfo(url);
      expect(result, isNull);
    });
  });
}
