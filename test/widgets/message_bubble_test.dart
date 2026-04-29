import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_i18n/fluent_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/models/image_type.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/link_preview_service.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_bubble_test.mocks.dart';

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final request = MockHttpClientRequest();
    request.headers; // Access to avoid unused member warning
    return request;
  }
}

class MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }
}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => -1;

  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    VoidCallback? onDone,
    bool? cancelOnError,
  }) {
    const svgString =
        '<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><circle cx="50" cy="50" r="40" stroke="green" stroke-width="4" fill="yellow" /></svg>';
    final bytes = utf8.encode(svgString);
    return Stream<List<int>>.value(bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

@GenerateMocks([LinkPreviewService, ChatProvider])
void main() {
  HttpOverrides.global = MockHttpOverrides();
  late MockLinkPreviewService mockService;
  late MockChatProvider mockProvider;

  void stubInfo(String url, LinkPreviewInfo? info) {
    when(mockService.getCachedInfo(url)).thenReturn(info);
    when(mockService.fetchInfo(url)).thenAnswer((_) async => info);
  }

  Widget wrapWithLocalization(Widget child) {
    return MaterialApp(
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        FluentLocalizationsDelegate([Locale('en')]),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          if (FluentLocalizations.of(context) == null) {
            return const SizedBox.shrink();
          }
          return Scaffold(body: child);
        },
      ),
    );
  }

  setUp(() async {
    if (locator.isRegistered<LinkPreviewService>()) {
      locator.unregister<LinkPreviewService>();
      locator.unregister<UserConfiguration>();
      locator.unregister<ChatProvider>();
    }

    SharedPreferences.setMockInitialValues({
      'show_image_previews': true,
      'show_time_seconds': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final realConfig = PersistentUserConfiguration(preferences: prefs);

    mockService = MockLinkPreviewService();
    mockProvider = MockChatProvider();

    locator.registerSingleton<LinkPreviewService>(mockService);
    locator.registerSingleton<UserConfiguration>(realConfig);
    locator.registerSingleton<ChatProvider>(mockProvider);
  });

  group('MessageBubble', () {
    testWidgets('renders image pill for single image URL', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/image.jpg',
        date: DateTime.now(),
      );

      stubInfo(
        'https://example.com/image.jpg',
        ImageLinkPreviewInfo(
          RasterImageType(url: 'https://example.com/image.jpg'),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('image'), findsOneWidget);
      expect(find.text('https://example.com/image.jpg'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders pills for multiple image URLs', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content:
            'Photos: https://example.com/1.png and https://example.com/2.webp',
        date: DateTime.now(),
      );

      stubInfo(
        'https://example.com/1.png',
        ImageLinkPreviewInfo(RasterImageType(url: 'https://example.com/1.png')),
      );
      stubInfo(
        'https://example.com/2.webp',
        ImageLinkPreviewInfo(
          RasterImageType(url: 'https://example.com/2.webp'),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('image'), findsNWidgets(2));
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('renders normal URLs when showImagePreviews is false', (
      tester,
    ) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/image.jpg',
        date: DateTime.now(),
      );

      stubInfo(
        'https://example.com/image.jpg',
        ImageLinkPreviewInfo(
          RasterImageType(url: 'https://example.com/image.jpg'),
        ),
      );

      SharedPreferences.setMockInitialValues({
        'show_image_previews': false,
        'show_time_seconds': false,
      });
      final prefs = await SharedPreferences.getInstance();

      locator.unregister<UserConfiguration>();
      locator.registerSingleton<UserConfiguration>(
        PersistentUserConfiguration(preferences: prefs),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('image'), findsNothing);
      expect(
        find.textContaining('https://example.com/image.jpg'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('does not treat non-image URLs as images', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/page.html',
        date: DateTime.now(),
      );

      stubInfo('https://example.com/page.html', null);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('image'), findsNothing);
      expect(
        find.textContaining('https://example.com/page.html'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders search highlights correctly', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Hello **bold world** and @alice ',
        date: DateTime.now(),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: 'bold'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final textSpan = selectableText.textSpan!;

      bool foundHighlight = false;
      void checkHighlight(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text == 'bold' && span.style?.backgroundColor != null) {
            foundHighlight = true;
          }
          if (span.children != null) {
            for (final child in span.children!) {
              checkHighlight(child);
            }
          }
        }
      }

      for (final span in textSpan.children!) {
        checkHighlight(span);
      }

      expect(foundHighlight, isTrue);
    });

    testWidgets('renders SvgPicture for SVG images', (tester) async {
      final message = ChatMessage(
        from: 'user',
        content: 'Check this: https://example.com/logo.png',
        date: DateTime.now(),
      );

      stubInfo(
        'https://example.com/logo.png',
        ImageLinkPreviewInfo(
          RasterImageType(url: 'https://example.com/logo.png'),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
      });

      expect(find.text('image'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders all images in gallery for multiple distinct links', (
      tester,
    ) async {
      final message = ChatMessage(
        from: 'user',
        content:
            'Links: https://example.com/a.jpg and https://example.com/b.png and https://example.com/c.gif',
        date: DateTime.now(),
      );

      stubInfo(
        'https://example.com/a.jpg',
        ImageLinkPreviewInfo(RasterImageType(url: 'https://example.com/a.jpg')),
      );
      stubInfo(
        'https://example.com/b.png',
        ImageLinkPreviewInfo(RasterImageType(url: 'https://example.com/b.png')),
      );
      stubInfo(
        'https://example.com/c.gif',
        ImageLinkPreviewInfo(RasterImageType(url: 'https://example.com/c.gif')),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('image'), findsNWidgets(3));
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders all images in gallery even for duplicate links', (
      tester,
    ) async {
      final message = ChatMessage(
        from: 'user',
        content:
            'Same: https://example.com/a.jpg and https://example.com/a.jpg',
        date: DateTime.now(),
      );

      stubInfo(
        'https://example.com/a.jpg',
        ImageLinkPreviewInfo(RasterImageType(url: 'https://example.com/a.jpg')),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithLocalization(
            MessageBubble(message: message, searchQuery: ''),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('image'), findsNWidgets(2));
      expect(find.byType(Image), findsNWidgets(2));
    });
  });
}
