import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/models/chat_message.dart';

void main() {
  group('MessageGrouper', () {
    const grouper = MessageGrouper();
    final now = DateTime(2024, 1, 1, 10, 0, 0);
    final sameSecond = DateTime(2024, 1, 1, 10, 0, 0, 500);
    final nextSecond = DateTime(2024, 1, 1, 10, 0, 1, 0);

    test('groups messages from same user at same second', () {
      final messages = [
        ChatMessage(from: 'user1', content: 'msg1', date: now),
        ChatMessage(from: 'user1', content: 'msg2', date: sameSecond),
        ChatMessage(from: 'user2', content: 'msg3', date: now),
      ];

      final grouped = grouper.group(messages);

      expect(grouped.length, 2);
      expect(grouped[0].from, 'user1');
      expect(grouped[0].content, 'msg1\nmsg2');
      expect(grouped[1].from, 'user2');
      expect(grouped[1].content, 'msg3');
    });

    test('does not group messages from different users', () {
      final messages = [
        ChatMessage(from: 'user1', content: 'msg1', date: now),
        ChatMessage(from: 'user2', content: 'msg2', date: now),
      ];

      final grouped = grouper.group(messages);

      expect(grouped.length, 2);
      expect(grouped[0].from, 'user1');
      expect(grouped[1].from, 'user2');
    });

    test('does not group messages with different seconds', () {
      final messages = [
        ChatMessage(from: 'user1', content: 'msg1', date: now),
        ChatMessage(from: 'user1', content: 'msg2', date: nextSecond),
      ];

      final grouped = grouper.group(messages);

      expect(grouped.length, 2);
      expect(grouped[0].content, 'msg1');
      expect(grouped[1].content, 'msg2');
    });

    test('does not group messages without dates', () {
      final messages = [
        ChatMessage(from: 'user1', content: 'msg1', date: null),
        ChatMessage(from: 'user1', content: 'msg2', date: null),
      ];

      final grouped = grouper.group(messages);

      expect(grouped.length, 2);
    });

    test('handles empty list', () {
      expect(grouper.group([]), isEmpty);
    });

    test('groups three sequential messages', () {
      final messages = [
        ChatMessage(from: 'user1', content: '1', date: now),
        ChatMessage(from: 'user1', content: '2', date: now),
        ChatMessage(from: 'user1', content: '3', date: now),
      ];

      final grouped = grouper.group(messages);

      expect(grouped.length, 1);
      expect(grouped[0].content, '1\n2\n3');
    });

    group('canGroup', () {
      test('returns true for same sender and same second', () {
        final a = ChatMessage(from: 'user1', content: 'a', date: now);
        final b = ChatMessage(from: 'user1', content: 'b', date: sameSecond);
        expect(grouper.canGroup(a, b), isTrue);
      });

      test('returns false for different senders', () {
        final a = ChatMessage(from: 'user1', content: 'a', date: now);
        final b = ChatMessage(from: 'user2', content: 'b', date: now);
        expect(grouper.canGroup(a, b), isFalse);
      });

      test('returns false for different seconds', () {
        final a = ChatMessage(from: 'user1', content: 'a', date: now);
        final b = ChatMessage(from: 'user1', content: 'b', date: nextSecond);
        expect(grouper.canGroup(a, b), isFalse);
      });

      test('returns false if date is null', () {
        final a = ChatMessage(from: 'user1', content: 'a', date: null);
        final b = ChatMessage(from: 'user1', content: 'b', date: now);
        expect(grouper.canGroup(a, b), isFalse);
        expect(grouper.canGroup(b, a), isFalse);
      });
    });
  });
}
