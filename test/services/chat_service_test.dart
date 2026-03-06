import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/websocket_factory.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  setUp(() {
    factory = MockWebSocketFactory();
    service = ChatService(
      serverUrl: Uri.parse('ws://localhost:8080'),
      nickname: 'tester',
      initialChannel: '#test',
      webSocketFactory: factory,
    );
  });

  Future<MockWebSocketChannel> connectAndLogin() async {
    final loginFuture = service.connect();
    final channel = factory.lastCreatedChannel!;
    channel.feed('> Type your username:');
    await loginFuture;
    return channel;
  }

  group('ChatService', () {
    test('connects and logs in', () async {
      final loginFuture = service.connect();
      final channel = factory.lastCreatedChannel!;

      final outgoing = channel.outgoing.first;
      channel.feed('> Type your username:');

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
      final channel = await connectAndLogin();

      final usersFuture = service.users.first;
      channel.feed('|10:00:00| [@server]: users: alice, bob, charlie');

      final users = await usersFuture;
      expect(users, containsAll(['alice', 'bob', 'charlie']));
    });

    test('handles user join', () async {
      final channel = await connectAndLogin();

      // First set initial users
      channel.feed('|10:00:00| [@server]: users: alice');
      await service.users.first;

      final usersFuture = service.users.first;
      channel.feed('|10:00:01| [@server]: The user @bob joined to the party!');

      final users = await usersFuture;
      expect(users, containsAll(['alice', 'bob']));
    });

    test('handles user exit', () async {
      final channel = await connectAndLogin();

      // First set initial users
      channel.feed('|10:00:00| [@server]: users: alice, bob');
      await service.users.first;

      final usersFuture = service.users.first;
      channel.feed(
        '|10:00:01| [@server]: The user @bob exited from the party :(',
      );

      final users = await usersFuture;
      expect(users, ['alice']);
    });
  });
}
