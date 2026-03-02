import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/services/chat_service.dart';
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

class FakeWebSocketChannel extends Fake implements WebSocketChannel {
  FakeWebSocketChannel(this.stream, this.sink);

  @override
  final Stream<dynamic> stream;

  @override
  final WebSocketSink sink;

  @override
  Future<void> get ready => Future.value();

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
      final mockChannel = FakeWebSocketChannel(serverStream.stream, clientSink);

      service = ChatService(
        serverUrl: Uri.parse('ws://test'),
        nickname: 'TestUser',
        appVersion: '1.0.0',
      );
      service.connect(mockChannel: mockChannel);
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
  });
}
