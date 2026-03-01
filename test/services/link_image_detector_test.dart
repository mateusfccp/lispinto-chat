import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/services/link_image_detector.dart';
import 'package:mockito/mockito.dart';

class MockClient extends Mock implements http.Client {
  @override
  Future<http.Response> head(Uri? url, {Map<String, String>? headers}) =>
      super.noSuchMethod(
        Invocation.method(#head, [url], {#headers: headers}),
        returnValue: Future.value(http.Response('', 200)),
      );

  @override
  Future<http.Response> get(Uri? url, {Map<String, String>? headers}) =>
      super.noSuchMethod(
        Invocation.method(#get, [url], {#headers: headers}),
        returnValue: Future.value(http.Response('', 200)),
      );
}

void main() {
  late LinkImageDetector detector;
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
    detector = LinkImageDetector(client: mockClient);
  });

  group('LinkImageDetector', () {
    test('detects image via Content-Type image/jpeg', () async {
      const url = 'https://example.com/image';
      when(mockClient.head(Uri.parse(url))).thenAnswer(
        (_) async =>
            http.Response('', 200, headers: {'content-type': 'image/jpeg'}),
      );

      final result = await detector.isImage(url);
      expect(result, isA<RasterImageType>());
      verify(mockClient.head(Uri.parse(url))).called(1);
    });

    test(
      'detects image via magic bytes for application/octet-stream (PNG)',
      () async {
        const url = 'https://example.com/binary';
        when(mockClient.head(Uri.parse(url))).thenAnswer(
          (_) async => http.Response(
            '',
            200,
            headers: {'content-type': 'application/octet-stream'},
          ),
        );

        final pngBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        when(
          mockClient.get(Uri.parse(url), headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response.bytes(pngBytes, 200));

        final result = await detector.isImage(url);
        expect(result, isA<RasterImageType>());
        expect(detector.getCachedStatus(url), isA<RasterImageType>());
      },
    );

    test('detects AVIF via magic bytes', () async {
      const url = 'https://example.com/movie.avif';
      when(mockClient.head(Uri.parse(url))).thenAnswer(
        (_) async => http.Response(
          '',
          200,
          headers: {'content-type': 'application/octet-stream'},
        ),
      );

      final avifBytes = Uint8List.fromList([
        0,
        0,
        0,
        0x1C,
        0x66,
        0x74,
        0x79,
        0x70,
        0x61,
        0x76,
        0x69,
        0x66,
      ]);
      when(
        mockClient.get(Uri.parse(url), headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response.bytes(avifBytes, 200));

      final result = await detector.isImage(url);
      expect(result, isA<RasterImageType>());
    });

    test('detects SVG via Content-Type image/svg+xml (exact)', () async {
      const url = 'https://example.com/logo.svg';
      when(mockClient.head(Uri.parse(url))).thenAnswer(
        (_) async =>
            http.Response('', 200, headers: {'content-type': 'image/svg+xml'}),
      );

      final result = await detector.isImage(url);
      expect(result, isA<SvgImageType>());
    });

    test('detects SVG via Content-Type with charset (placehold.co)', () async {
      const url = 'https://placehold.co/400';
      when(mockClient.head(Uri.parse(url))).thenAnswer(
        (_) async => http.Response(
          '',
          200,
          headers: {'content-type': 'image/svg+xml; charset=utf-8'},
        ),
      );

      final result = await detector.isImage(url);
      expect(result, isA<SvgImageType>());
    });

    test(
      'detects SVG via magic bytes for application/octet-stream (<svg)',
      () async {
        const url = 'https://example.com/vector';
        when(mockClient.head(Uri.parse(url))).thenAnswer(
          (_) async => http.Response(
            '',
            200,
            headers: {'content-type': 'application/octet-stream'},
          ),
        );

        final svgBytes = Uint8List.fromList([
          0x3C,
          0x73,
          0x76,
          0x67,
          0x20,
          0x76,
          0x69,
          0x65,
          0x77,
        ]);
        when(
          mockClient.get(Uri.parse(url), headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response.bytes(svgBytes, 200));

        final result = await detector.isImage(url);
        expect(result, isA<SvgImageType>());
      },
    );

    test('returns false for non-image octet-stream', () async {
      const url = 'https://example.com/script.sh';
      when(mockClient.head(Uri.parse(url))).thenAnswer(
        (_) async => http.Response(
          '',
          200,
          headers: {'content-type': 'application/octet-stream'},
        ),
      );

      final randomBytes = Uint8List.fromList([
        0x23,
        0x21,
        0x2F,
        0x62,
        0x69,
        0x6E,
        0x2F,
        0x73,
        0x68,
      ]);
      when(
        mockClient.get(Uri.parse(url), headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response.bytes(randomBytes, 200));

      final result = await detector.isImage(url);
      expect(result, isNull);
    });

    test('caches results', () async {
      const url = 'https://example.com/cached';
      when(mockClient.head(Uri.parse(url))).thenAnswer(
        (_) async =>
            http.Response('', 200, headers: {'content-type': 'image/png'}),
      );

      await detector.isImage(url);
      await detector.isImage(url);

      verify(mockClient.head(Uri.parse(url))).called(1);
    });
  });
}
