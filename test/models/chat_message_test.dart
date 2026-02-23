import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('isServerMessage correctly identifies server', () {
      final msg1 = ChatMessage(from: '@server', content: 'hello');
      final msg2 = ChatMessage(from: 'user', content: 'hello');

      expect(msg1.isServerMessage, isTrue);
      expect(msg2.isServerMessage, isFalse);
    });

    test('fromParsed extracts historical timestamp', () {
      final match = [
        'full string',
        '2023-11-04',
        '10:30',
        '45',
        'Pintass',
        'Hello World',
      ];
      final msg = ChatMessage.fromParsed(match);

      expect(msg.from, 'Pintass');
      expect(msg.content, 'Hello World');
      expect(msg.date, isNotNull);
      expect(msg.date!.year, 2023);
      expect(msg.date!.month, 11);
      expect(msg.date!.day, 4);
      expect(msg.date!.hour, 10);
      expect(msg.date!.minute, 30);
      expect(msg.date!.second, 45);
    });

    test('fromParsed assigns current time for realtime messages', () {
      final match = [
        'full string',
        null,
        null,
        null,
        'Pintass',
        'Realtime message',
      ];
      final msg = ChatMessage.fromParsed(match);

      expect(msg.from, 'Pintass');
      expect(msg.content, 'Realtime message');
      expect(msg.date, isNotNull);

      // Should be roughly close to now
      final now = DateTime.now();
      expect(now.difference(msg.date!).inSeconds, lessThan(2));
    });
  });
}
