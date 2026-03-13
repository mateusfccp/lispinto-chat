import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/websocket_factory.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockHttpClient extends Fake implements http.Client {
  String responseBody = '';

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return http.Response(responseBody, 200);
  }
}

class FakeUserConfiguration extends Fake implements UserConfiguration {
  @override
  String get nickname => 'tester';

  @override
  String get serverUrl => 'http://localhost:8080';

  @override
  bool get showEmptyChannels => true;

  @override
  String get lastChannel => '#general';
}

class MockWebSocketChannel extends Fake implements WebSocketChannel {
  final _streamController = StreamController<dynamic>();
  final _sinkController = StreamController<dynamic>();

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _MockWebSocketSink(_sinkController);

  @override
  Future<void> get ready => Future.value();

  void feed(String data) => _streamController.add(data);

  Stream<dynamic> get outgoing => _sinkController.stream;
}

class _MockWebSocketSink extends Fake implements WebSocketSink {
  final StreamController<dynamic> _controller;
  _MockWebSocketSink(this._controller);

  @override
  void add(dynamic data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async =>
      _controller.close();

  @override
  Future<void> get done => _controller.done;
}

class MockWebSocketFactory extends Fake implements WebSocketFactory {
  MockWebSocketChannel? lastCreatedChannel;

  @override
  WebSocketChannel create(Uri uri) {
    return lastCreatedChannel = MockWebSocketChannel();
  }
}

void main() {
  late ChatService service;
  late MockWebSocketFactory factory;
  late MockHttpClient httpClient;

  setUp(() {
    factory = MockWebSocketFactory();
    httpClient = MockHttpClient();
    service = ChatService(
      url: Uri.parse('http://localhost:8080'),
      nickname: 'tester',
      initialChannel: '#test',
      webSocketFactory: factory,
      httpClient: httpClient,
      configuration: FakeUserConfiguration(),
    );
  });

  Future<MockWebSocketChannel> connectAndLogin() async {
    final loginFuture = service.connect();
    final channel = factory.lastCreatedChannel!;

    httpClient.responseBody = '{"result": ""}';
    channel.feed('> Type your username:');
    channel.feed('|10:00:00| [@server]: Your session ID is: mock-uuid');

    await loginFuture;
    return channel;
  }

  group('ChatService', () {
    test('connects and logs in', () async {
      final loginFuture = service.connect();
      final channel = factory.lastCreatedChannel!;

      final outgoing = channel.outgoing.first;

      httpClient.responseBody = '{"result": ""}';
      channel.feed('> Type your username:');
      channel.feed('|10:00:00| [@server]: Your session ID is: mock-uuid');

      expect(await outgoing, 'tester');
      await loginFuture;

      expect(service.isConnected, isTrue);
    });

    test('parses simple message', () async {
      final channel = await connectAndLogin();

      final messageFuture = service.messages.first;
      channel.feed('|10:00:00| [alice]: hello world');

      final message = await messageFuture;
      expect(message.content, 'hello world');
      expect(message.from, 'alice');
    });

    test('handles user list response', () async {
      await connectAndLogin();

      final usersFuture = service.users.first;
      httpClient.responseBody = '{"result": "users: alice, bob, charlie"}';
      await service.requestUsersList(targetChannel: '#general');

      final users = await usersFuture;
      expect(users, containsAll(['alice', 'bob', 'charlie']));
    });

    test('handles user join via system message', () async {
      final channel = await connectAndLogin();

      final messageFuture = service.messages.first;
      channel.feed('|10:00:01| [@server]: The user @bob joined to the party!');

      final message = await messageFuture;
      expect(message.content, 'The user @bob joined to the party!');
      expect(message.from, '@server');
    });

    test('handles user exit via system message', () async {
      final channel = await connectAndLogin();

      final messageFuture = service.messages.first;
      channel.feed(
        '|10:00:01| [@server]: The user @bob exited from the party :(',
      );

      final message = await messageFuture;
      expect(message.content, 'The user @bob exited from the party :(');
      expect(message.from, '@server');
    });

    test('ignores non-standard lines without crashing', () async {
      final channel = await connectAndLogin();

      // This line doesn't match the regex but shouldn't throw FormatException
      channel.feed('--- History Log Start ---');
      channel.feed('|10:00:02| [alice]: i am still here');

      final message = await service.messages.first;
      expect(message.content, 'i am still here');
      expect(service.isConnected, isTrue);
    });

    test('isLoggedIn correctly reflects login state', () async {
      expect(service.isLoggedIn, isFalse);

      final loginFuture = service.connect();
      final channel = factory.lastCreatedChannel!;

      expect(service.isLoggedIn, isFalse);
      expect(service.isConnected, isFalse); // Because state is 'connecting'

      httpClient.responseBody = '{"result": ""}';
      channel.feed('> Type your username:');
      channel.feed('|10:00:00| [@server]: Your session ID is: mock-uuid');

      await loginFuture;

      expect(service.isLoggedIn, isTrue);
      expect(service.isConnected, isTrue);

      service.disconnect();
      expect(service.isLoggedIn, isFalse);
      expect(service.isConnected, isFalse);
    });
  });

  group('ChatService.deriveWebSocketUrl', () {
    test('converts http to ws and appends /ws', () {
      final httpUrl = Uri.parse('http://localhost:8080');
      final wsUrl = ChatService.deriveWebSocketUrl(httpUrl);
      expect(wsUrl.toString(), 'ws://localhost:8080/ws');
    });

    test('converts https to wss and appends /ws', () {
      final httpsUrl = Uri.parse('https://example.com');
      final wssUrl = ChatService.deriveWebSocketUrl(httpsUrl);
      expect(wssUrl.toString(), 'wss://example.com/ws');
    });

    test('handles path in http url', () {
      final httpUrl = Uri.parse('http://localhost:8080/api');
      final wsUrl = ChatService.deriveWebSocketUrl(httpUrl);
      expect(wsUrl.toString(), 'ws://localhost:8080/api/ws');
    });

    test('handles trailing slash in http url', () {
      final httpUrl = Uri.parse('http://localhost:8080/api/');
      final wsUrl = ChatService.deriveWebSocketUrl(httpUrl);
      expect(wsUrl.path, '/api//ws');
    });

    test('throws if scheme is not http or https', () {
      expect(
        () => ChatService.deriveWebSocketUrl(Uri.parse('ftp://example.com')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
