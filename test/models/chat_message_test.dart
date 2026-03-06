import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/models/chat_message.dart';

void main() {
  group('ChatMessage.fromParsed', () {
    test('parses message with date and time', () {
      final groups = [
        '|2026-03-06 17:15:30| [bob]: hello',
        '2026-03-06',
        '17:15',
        '30',
        'bob',
        'hello',
      ];
      final message = ChatMessage.fromParsed(groups);

      expect(message.content, 'hello');
      expect(message.from, 'bob');
      expect(message.date, DateTime(2026, 3, 6, 17, 15, 30));
    });

    test('parses message with only time', () {
      final now = DateTime.now();
      final groups = [
        '|17:15:30| [alice]: hi',
        null,
        '17:15',
        '30',
        'alice',
        'hi',
      ];
      final message = ChatMessage.fromParsed(groups);

      expect(message.content, 'hi');
      expect(message.from, 'alice');
      // Should default to today's date
      expect(message.date!.hour, 17);
      expect(message.date!.minute, 15);
      expect(message.date!.second, 30);
      expect(message.date!.year, now.year);
      expect(message.date!.month, now.month);
      expect(message.date!.day, now.day);
    });

    test('handles server messages correctly', () {
      final groups = [
        '|17:15:30| [@server]: Welcome',
        null,
        '17:15',
        '30',
        '@server',
        'Welcome',
      ];
      final message = ChatMessage.fromParsed(groups);

      expect(message.isServerMessage, isTrue);
      expect(message.isSystemMessage, isTrue);
      expect(message.from, '@server');
    });

    test('handles command messages correctly', () {
      final groups = [
        '|17:15:30| [@command]: Result',
        null,
        '17:15',
        '30',
        '@command',
        'Result',
      ];
      final message = ChatMessage.fromParsed(groups);

      expect(message.isCommandMessage, isTrue);
      expect(message.isSystemMessage, isTrue);
    });
  });
}
