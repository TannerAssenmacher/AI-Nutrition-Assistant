/// Tests for ChatMessage class from GeminiChatService
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/services/gemini_chat_service.dart';

void main() {
  // ============================================================================
  // CHAT MESSAGE TESTS
  // ============================================================================
  group('ChatMessage', () {
    test('should create message with required fields', () {
      final message = ChatMessage(
        content: 'Hello, world!',
        isUser: true,
      );

      expect(message.content, 'Hello, world!');
      expect(message.isUser, isTrue);
      expect(message.timestamp, isNotNull);
    });

    test('should create message with custom timestamp', () {
      final timestamp = DateTime(2025, 6, 15, 10, 30);
      final message = ChatMessage(
        content: 'Test message',
        isUser: false,
        timestamp: timestamp,
      );

      expect(message.timestamp, timestamp);
    });

    test('should auto-generate timestamp if not provided', () {
      final before = DateTime.now();
      final message = ChatMessage(
        content: 'Test',
        isUser: true,
      );
      final after = DateTime.now();

      expect(message.timestamp.isAfter(before) || 
             message.timestamp.isAtSameMomentAs(before), isTrue);
      expect(message.timestamp.isBefore(after) || 
             message.timestamp.isAtSameMomentAs(after), isTrue);
    });

    test('should correctly identify user messages', () {
      final userMessage = ChatMessage(content: 'User says hi', isUser: true);
      final botMessage = ChatMessage(content: 'Bot responds', isUser: false);

      expect(userMessage.isUser, isTrue);
      expect(botMessage.isUser, isFalse);
    });

    group('formattedTime', () {
      test('should format time with leading zeros', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 9, 5),
        );

        expect(message.formattedTime, '09:05');
      });

      test('should format afternoon time correctly', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 14, 30),
        );

        expect(message.formattedTime, '14:30');
      });

      test('should format midnight correctly', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 0, 0),
        );

        expect(message.formattedTime, '00:00');
      });
    });

    group('isToday', () {
      test('should return true for today\'s message', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime.now(),
        );

        expect(message.isToday, isTrue);
      });

      test('should return false for yesterday\'s message', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: yesterday,
        );

        expect(message.isToday, isFalse);
      });

      test('should return false for message from last year', () {
        final lastYear = DateTime.now().subtract(const Duration(days: 365));
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: lastYear,
        );

        expect(message.isToday, isFalse);
      });
    });

    group('equality', () {
      test('should be equal to identical message', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );

        expect(message1, equals(message2));
      });

      test('should not be equal if content differs', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'World',
          isUser: true,
          timestamp: timestamp,
        );

        expect(message1, isNot(equals(message2)));
      });

      test('should not be equal if isUser differs', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Hello',
          isUser: false,
          timestamp: timestamp,
        );

        expect(message1, isNot(equals(message2)));
      });

      test('should not be equal if timestamp differs', () {
        final message1 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 10, 30),
        );
        final message2 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 10, 31),
        );

        expect(message1, isNot(equals(message2)));
      });
    });

    group('hashCode', () {
      test('should have same hashCode for equal messages', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );

        expect(message1.hashCode, equals(message2.hashCode));
      });

      test('should have different hashCode for different messages', () {
        final message1 = ChatMessage(content: 'Hello', isUser: true);
        final message2 = ChatMessage(content: 'World', isUser: false);

        expect(message1.hashCode, isNot(equals(message2.hashCode)));
      });
    });

    group('toString', () {
      test('should produce readable string representation', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );

        final str = message.toString();

        expect(str, contains('ChatMessage'));
        expect(str, contains('content: Hello'));
        expect(str, contains('isUser: true'));
        expect(str, contains('timestamp:'));
      });
    });

    test('should handle empty content', () {
      final message = ChatMessage(content: '', isUser: true);

      expect(message.content, '');
    });

    test('should handle very long content', () {
      final longContent = 'A' * 10000;
      final message = ChatMessage(content: longContent, isUser: true);

      expect(message.content, longContent);
      expect(message.content.length, 10000);
    });

    test('should handle special characters in content', () {
      final specialContent = 'Hello! 👋 \n\t "quotes" <html>';
      final message = ChatMessage(content: specialContent, isUser: true);

      expect(message.content, specialContent);
    });
  });
}
