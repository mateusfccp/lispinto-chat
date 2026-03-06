import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/models/chat_message.dart';

void main() {
  const grouper = MessageGrouper();

  group('MessageGrouper', () {
    test('returns empty list for empty input', () {
      expect(grouper.group([]), []);
    });

    test('returns single message as is', () {
      final message = ChatMessage(from: 'alice', content: 'hello');
      expect(grouper.group([message]), [message]);
    });

    test('does not group messages from different users', () {
      final now = DateTime.now();
      final m1 = ChatMessage(date: now, from: 'alice', content: 'hello');
      final m2 = ChatMessage(date: now, from: 'bob', content: 'hi');

      final result = grouper.group([m1, m2]);
      expect(result.length, 2);
      expect(result[0].from, 'alice');
      expect(result[1].from, 'bob');
    });

    test('does not group messages from same user with different times', () {
      final now = DateTime.now();
      final later = now.add(const Duration(seconds: 1));
      final m1 = ChatMessage(date: now, from: 'alice', content: 'hello');
      final m2 = ChatMessage(date: later, from: 'alice', content: 'world');

      final result = grouper.group([m1, m2]);
      expect(result.length, 2);
      expect(result[0].content, 'hello');
      expect(result[1].content, 'world');
    });

    test('groups messages from same user at the exact same time', () {
      final now = DateTime(2026, 3, 6, 18, 0, 0);
      final m1 = ChatMessage(date: now, from: 'alice', content: 'hello');
      final m2 = ChatMessage(date: now, from: 'alice', content: 'world');

      final result = grouper.group([m1, m2]);
      expect(result.length, 1);
      expect(result[0].from, 'alice');
      expect(result[0].content, 'hello\nworld');
      expect(result[0].date, now);
    });

    test('groups multiple sequences of messages', () {
      final now = DateTime(2026, 3, 6, 18, 0, 0);
      final later = now.add(const Duration(seconds: 1));
      
      final m1 = ChatMessage(date: now, from: 'alice', content: 'a1');
      final m2 = ChatMessage(date: now, from: 'alice', content: 'a2');
      final m3 = ChatMessage(date: now, from: 'bob', content: 'b1');
      final m4 = ChatMessage(date: later, from: 'bob', content: 'b2');
      final m5 = ChatMessage(date: later, from: 'bob', content: 'b3');

      final result = grouper.group([m1, m2, m3, m4, m5]);
      expect(result.length, 3);
      expect(result[0].content, 'a1\na2');
      expect(result[1].content, 'b1');
      expect(result[2].content, 'b2\nb3');
    });
  });
}
