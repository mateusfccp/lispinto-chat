import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/services/websocket_factory.dart';
import 'package:mockito/mockito.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketSink extends Fake implements WebSocketSink {
  final List<dynamic> sentMessages = [];

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async {}

  @override
  Future get done => Future.value();
}

class MockWebSocketFactory extends Mock implements WebSocketFactory {
  MockWebSocketFactory(this.channelFactory);
  final WebSocketChannel Function(Uri uri) channelFactory;

  @override
  WebSocketChannel create(Uri uri) => channelFactory(uri);
}

class FakeWebSocketChannel extends Fake implements WebSocketChannel {
  FakeWebSocketChannel(this.stream, this.sink, {this.failReady = false});

  final bool failReady;

  @override
  final Stream<dynamic> stream;

  @override
  final WebSocketSink sink;

  @override
  Future<void> get ready =>
      failReady ? Future.error(Exception('Connection failed')) : Future.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

void main() {
  group('ChatService parsing channels and users', () {
    late ChatService service;
    late StreamController<String> serverStream;
    late FakeWebSocketSink clientSink;

    setUp(() {
      serverStream = StreamController<String>.broadcast();
      clientSink = FakeWebSocketSink();

      service = ChatService(
        serverUrl: Uri.parse('ws://test'),
        nickname: 'TestUser',
        webSocketFactory: MockWebSocketFactory((uri) {
          if (uri.host == 'fail') {
            return FakeWebSocketChannel(
              const Stream.empty(),
              clientSink,
              failReady: true,
            );
          }
          return FakeWebSocketChannel(serverStream.stream, clientSink);
        }),
      );
      // ignore: discarded_futures
      service.connect();
      // Simulate login prompt to complete the connection future
      serverStream.add('|12:00:00| [@server]: > Type your username:');
    });

    tearDown(() {
      service.disconnect();
      serverStream.close();
    });

    test('Parses /channels response correctly', () async {
      final channelsFuture = service.channels.skip(1).first;

      serverStream.add('|12:00:00| [@server]: #general: 5 users');
      serverStream.add('|12:00:00| [@server]: #random: 2 users');

      final channels = await channelsFuture;
      expect(channels, equals({'#general': 5, '#random': 2}));
    });

    test('Parses /users response correctly', () async {
      final usersFuture = service.users.first;

      serverStream.add('|12:00:00| [@server]: users: Alice, Bob');

      final users = await usersFuture;
      expect(users, containsAll(['Alice', 'Bob']));
    });

    test('Maintains online users properly on join/exit/nick', () async {
      // Setup initial users
      serverStream.add('|12:00:00| [@server]: users: Alice, Bob');

      // Wait a tick for processing
      await Future.delayed(const Duration(milliseconds: 10));

      // Test someone joining
      var usersFuture = service.users.first;
      serverStream.add(
        '|12:00:00| [@server]: The user @Charlie joined to the party!',
      );
      var users = await usersFuture;
      expect(users, containsAll(['Alice', 'Bob', 'Charlie']));

      // Test someone exiting
      usersFuture = service.users.first;
      serverStream.add(
        '|12:00:00| [@server]: The user @Alice exited from the party :(',
      );
      users = await usersFuture;
      expect(users, containsAll(['Bob', 'Charlie']));
      expect(users.contains('Alice'), isFalse);

      // Test nick change (Broadcast)
      usersFuture = service.users.first;
      serverStream.add(
        '|12:00:00| [@server]: User @Bob is now known as @Robert',
      );
      users = await usersFuture;
      expect(users, containsAll(['Robert', 'Charlie']));
      expect(users.contains('Bob'), isFalse);
    });

    test('Reconnects multiple times and then fails', () {
      fakeAsync((async) {
        int connectAttempts = 0;
        final factory = MockWebSocketFactory((uri) {
          connectAttempts++;
          // First attempt succeeds, subsequent attempts fail
          if (connectAttempts == 1) {
            return FakeWebSocketChannel(serverStream.stream, clientSink);
          } else {
            return FakeWebSocketChannel(
              const Stream.empty(),
              clientSink,
              failReady: true,
            );
          }
        });

        final failingService = ChatService(
          serverUrl: Uri.parse('ws://test'),
          nickname: 'TestUser',
          webSocketFactory: factory,
        );

        // Track connection state
        bool? isConnected;
        failingService.connectionState.listen((c) => isConnected = c);

        // Initial connect - ignore error because we know it will eventually fail retries or we'll trigger disconnect
        // Actually, initial connect succeeds here.
        failingService.connect();
        async.flushMicrotasks();
        expect(connectAttempts, 1);

        // Simulate login
        serverStream.add('|12:00:00| [@server]: > Type your username:');
        async.flushMicrotasks();
        
        // Wait for login to be processed (sets _loggedIn = true)
        async.elapse(const Duration(milliseconds: 100));
        expect(failingService.isLoggedIn, isTrue);

        // Trigger disconnect (close the stream)
        serverStream.close();
        async.flushMicrotasks();

        // Now _reconnect should be running.
        // It will call connect() multiple times.
        
        // Advance time significantly to allow all retries to happen.
        async.elapse(const Duration(minutes: 10));
        
        // connectAttempts should be 1 (initial) + 8 (retries) = 9
        expect(connectAttempts, 9);
        
        // Final state should be disconnected
        expect(isConnected, isFalse);
        expect(failingService.isLoggedIn, isFalse);
      });
    });
  });
}
