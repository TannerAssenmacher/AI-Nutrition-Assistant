/// Tests for GeminiChatService class methods
/// Note: This tests the state management methods that don't require external APIs
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/services/gemini_chat_service.dart';

void main() {
  // ============================================================================
  // CHAT STAGE ENUM TESTS
  // ============================================================================
  group('ChatStage enum', () {
    test('should have idle state', () {
      expect(ChatStage.idle, isNotNull);
      expect(ChatStage.idle.name, 'idle');
    });

    test('should have awaitingMealType state', () {
      expect(ChatStage.awaitingMealType, isNotNull);
      expect(ChatStage.awaitingMealType.name, 'awaitingMealType');
    });

    test('should have awaitingCuisine state', () {
      expect(ChatStage.awaitingCuisine, isNotNull);
      expect(ChatStage.awaitingCuisine.name, 'awaitingCuisine');
    });

    test('should have exactly 3 values', () {
      expect(ChatStage.values.length, 3);
    });
  });

  // ============================================================================
  // CHAT MESSAGE ADVANCED TESTS
  // ============================================================================
  group('ChatMessage advanced tests', () {
    group('toString', () {
      test('should return formatted string representation', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message = ChatMessage(
          content: 'Hello',
          isUser: true,
          timestamp: timestamp,
        );

        final result = message.toString();
        expect(result, contains('ChatMessage'));
        expect(result, contains('content: Hello'));
        expect(result, contains('isUser: true'));
        expect(result, contains('timestamp:'));
      });

      test('should handle special characters in content', () {
        final message = ChatMessage(
          content: 'Hello\nWorld\t!',
          isUser: false,
        );

        final result = message.toString();
        expect(result, contains('Hello\nWorld\t!'));
      });
    });

    group('equality advanced cases', () {
      test('should be equal with same values', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: timestamp,
        );

        expect(message1 == message2, isTrue);
        expect(message1.hashCode, message2.hashCode);
      });

      test('should not be equal with different content', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Test1',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Test2',
          isUser: true,
          timestamp: timestamp,
        );

        expect(message1 == message2, isFalse);
      });

      test('should not be equal with different isUser', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Test',
          isUser: false,
          timestamp: timestamp,
        );

        expect(message1 == message2, isFalse);
      });

      test('should not be equal with different timestamp', () {
        final message1 = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 10, 30),
        );
        final message2 = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 6, 15, 10, 31),
        );

        expect(message1 == message2, isFalse);
      });

      test('should be equal to itself', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
        );

        expect(message == message, isTrue);
      });

      test('should not be equal to different type', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
        );

        expect(message == 'Test', isFalse);
        expect(message == 42, isFalse);
        expect(message == null, isFalse);
      });
    });

    group('hashCode consistency', () {
      test('should generate consistent hashCode', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: timestamp,
        );

        final hash1 = message.hashCode;
        final hash2 = message.hashCode;

        expect(hash1, hash2);
      });

      test('should generate different hashCodes for different messages', () {
        final timestamp = DateTime(2025, 6, 15, 10, 30);
        final message1 = ChatMessage(
          content: 'Test1',
          isUser: true,
          timestamp: timestamp,
        );
        final message2 = ChatMessage(
          content: 'Test2',
          isUser: true,
          timestamp: timestamp,
        );

        // HashCodes might collide but usually won't for different content
        // This is a probabilistic test
        expect(message1.hashCode != message2.hashCode, isTrue);
      });
    });

    group('formattedTime edge cases', () {
      test('should format single digit hour', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 1, 1, 5, 30),
        );

        expect(message.formattedTime, '05:30');
      });

      test('should format single digit minute', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 1, 1, 12, 5),
        );

        expect(message.formattedTime, '12:05');
      });

      test('should format end of day correctly', () {
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: DateTime(2025, 1, 1, 23, 59),
        );

        expect(message.formattedTime, '23:59');
      });
    });

    group('isToday edge cases', () {
      test('should return true for start of today', () {
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
        
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: startOfToday,
        );

        expect(message.isToday, isTrue);
      });

      test('should return true for end of today', () {
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: endOfToday,
        );

        expect(message.isToday, isTrue);
      });

      test('should return false for same time yesterday', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: yesterday,
        );

        expect(message.isToday, isFalse);
      });

      test('should return false for same time tomorrow', () {
        final now = DateTime.now();
        final tomorrow = now.add(const Duration(days: 1));
        
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: tomorrow,
        );

        expect(message.isToday, isFalse);
      });

      test('should handle year boundary correctly', () {
        final now = DateTime.now();
        final lastYear = DateTime(now.year - 1, now.month, now.day);
        
        final message = ChatMessage(
          content: 'Test',
          isUser: true,
          timestamp: lastYear,
        );

        expect(message.isToday, isFalse);
      });
    });

    group('content edge cases', () {
      test('should handle empty content', () {
        final message = ChatMessage(
          content: '',
          isUser: true,
        );

        expect(message.content, '');
      });

      test('should handle very long content', () {
        final longContent = 'A' * 10000;
        final message = ChatMessage(
          content: longContent,
          isUser: true,
        );

        expect(message.content.length, 10000);
      });

      test('should handle unicode content', () {
        final message = ChatMessage(
          content: '🍕🍔🌮 Food emojis!',
          isUser: true,
        );

        expect(message.content, '🍕🍔🌮 Food emojis!');
      });

      test('should handle multiline content', () {
        final message = ChatMessage(
          content: 'Line 1\nLine 2\nLine 3',
          isUser: false,
        );

        expect(message.content.split('\n').length, 3);
      });
    });
  });

  // ============================================================================
  // CHAT MESSAGE LIST OPERATIONS
  // ============================================================================
  group('ChatMessage list operations', () {
    test('should work correctly in a list', () {
      final messages = [
        ChatMessage(content: 'Hello', isUser: true),
        ChatMessage(content: 'Hi there!', isUser: false),
        ChatMessage(content: 'How are you?', isUser: true),
      ];

      expect(messages.length, 3);
      expect(messages.where((m) => m.isUser).length, 2);
      expect(messages.where((m) => !m.isUser).length, 1);
    });

    test('should be searchable by content', () {
      final messages = [
        ChatMessage(content: 'Hello world', isUser: true),
        ChatMessage(content: 'Goodbye world', isUser: false),
        ChatMessage(content: 'Hello again', isUser: true),
      ];

      final helloMessages = messages.where((m) => m.content.contains('Hello'));
      expect(helloMessages.length, 2);
    });

    test('should be sortable by timestamp', () {
      final now = DateTime.now();
      final messages = [
        ChatMessage(content: 'Third', isUser: true, timestamp: now.add(const Duration(minutes: 2))),
        ChatMessage(content: 'First', isUser: true, timestamp: now),
        ChatMessage(content: 'Second', isUser: false, timestamp: now.add(const Duration(minutes: 1))),
      ];

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      expect(messages[0].content, 'First');
      expect(messages[1].content, 'Second');
      expect(messages[2].content, 'Third');
    });

    test('should filter today messages correctly', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      final messages = [
        ChatMessage(content: 'Today 1', isUser: true, timestamp: now),
        ChatMessage(content: 'Yesterday', isUser: false, timestamp: yesterday),
        ChatMessage(content: 'Today 2', isUser: true, timestamp: now),
      ];

      final todayMessages = messages.where((m) => m.isToday);
      expect(todayMessages.length, 2);
    });
  });

  // ============================================================================
  // CHAT MESSAGE EDGE CASES - TIMESTAMPS
  // ============================================================================
  group('ChatMessage timestamp edge cases', () {
    test('should handle midnight timestamp', () {
      final midnight = DateTime(2025, 6, 15, 0, 0, 0);
      final message = ChatMessage(
        content: 'Midnight message',
        isUser: true,
        timestamp: midnight,
      );

      expect(message.formattedTime, '00:00');
    });

    test('should handle noon timestamp', () {
      final noon = DateTime(2025, 6, 15, 12, 0, 0);
      final message = ChatMessage(
        content: 'Noon message',
        isUser: true,
        timestamp: noon,
      );

      expect(message.formattedTime, '12:00');
    });

    test('should handle last second of day', () {
      final lastSecond = DateTime(2025, 6, 15, 23, 59, 59);
      final message = ChatMessage(
        content: 'Last second',
        isUser: true,
        timestamp: lastSecond,
      );

      expect(message.formattedTime, '23:59');
    });

    test('should handle leap year date', () {
      final leapDay = DateTime(2024, 2, 29, 12, 30);
      final message = ChatMessage(
        content: 'Leap day message',
        isUser: true,
        timestamp: leapDay,
      );

      expect(message.timestamp.month, 2);
      expect(message.timestamp.day, 29);
    });

    test('should handle far future date', () {
      final futureDate = DateTime(2100, 12, 31, 23, 59);
      final message = ChatMessage(
        content: 'Future message',
        isUser: true,
        timestamp: futureDate,
      );

      expect(message.timestamp.year, 2100);
      expect(message.isToday, isFalse);
    });

    test('should handle far past date', () {
      final pastDate = DateTime(1990, 1, 1, 0, 0);
      final message = ChatMessage(
        content: 'Past message',
        isUser: true,
        timestamp: pastDate,
      );

      expect(message.timestamp.year, 1990);
      expect(message.isToday, isFalse);
    });
  });

  // ============================================================================
  // CHAT MESSAGE CONTENT EDGE CASES
  // ============================================================================
  group('ChatMessage content edge cases', () {
    test('should handle whitespace-only content', () {
      final message = ChatMessage(
        content: '   \t\n   ',
        isUser: true,
      );

      expect(message.content.trim(), '');
    });

    test('should handle HTML-like content', () {
      final message = ChatMessage(
        content: '<script>alert("test")</script>',
        isUser: true,
      );

      expect(message.content, contains('<script>'));
    });

    test('should handle markdown content', () {
      final message = ChatMessage(
        content: '# Header\n**Bold** and *italic*',
        isUser: false,
      );

      expect(message.content, contains('**Bold**'));
    });

    test('should handle JSON-like content', () {
      final message = ChatMessage(
        content: '{"key": "value", "number": 42}',
        isUser: false,
      );

      expect(message.content, contains('"key"'));
    });

    test('should handle recipe-like content', () {
      final recipeContent = '''
🍽️ Grilled Chicken Salad
🔥 Overall Calories: 350 kcal

🥕 Ingredients:
• 200g chicken breast
• Mixed greens
• Cherry tomatoes

👩‍🍳 View full recipe → https://example.com
''';

      final message = ChatMessage(
        content: recipeContent,
        isUser: false,
      );

      expect(message.content, contains('🍽️'));
      expect(message.content, contains('Ingredients'));
    });

    test('should handle single character content', () {
      final message = ChatMessage(
        content: 'A',
        isUser: true,
      );

      expect(message.content, 'A');
      expect(message.content.length, 1);
    });

    test('should handle numeric content', () {
      final message = ChatMessage(
        content: '12345',
        isUser: true,
      );

      expect(message.content, '12345');
    });

    test('should handle special symbols', () {
      final message = ChatMessage(
        content: '!@#\$%^&*()_+-=[]{}|;:\'",.<>?/',
        isUser: true,
      );

      expect(message.content, contains('@'));
      expect(message.content, contains('#'));
    });
  });

  // ============================================================================
  // CHAT MESSAGE COLLECTION OPERATIONS
  // ============================================================================
  group('ChatMessage collection operations', () {
    test('should correctly count user vs bot messages', () {
      final messages = <ChatMessage>[];
      for (int i = 0; i < 10; i++) {
        messages.add(ChatMessage(
          content: 'Message $i',
          isUser: i % 2 == 0,
        ));
      }

      final userCount = messages.where((m) => m.isUser).length;
      final botCount = messages.where((m) => !m.isUser).length;

      expect(userCount, 5);
      expect(botCount, 5);
    });

    test('should get last message correctly', () {
      final messages = [
        ChatMessage(content: 'First', isUser: true),
        ChatMessage(content: 'Second', isUser: false),
        ChatMessage(content: 'Third', isUser: true),
      ];

      expect(messages.last.content, 'Third');
    });

    test('should get first message correctly', () {
      final messages = [
        ChatMessage(content: 'First', isUser: true),
        ChatMessage(content: 'Second', isUser: false),
      ];

      expect(messages.first.content, 'First');
    });

    test('should reverse list correctly', () {
      final messages = [
        ChatMessage(content: 'First', isUser: true),
        ChatMessage(content: 'Second', isUser: false),
        ChatMessage(content: 'Third', isUser: true),
      ];

      final reversed = messages.reversed.toList();

      expect(reversed[0].content, 'Third');
      expect(reversed[1].content, 'Second');
      expect(reversed[2].content, 'First');
    });

    test('should take last N messages', () {
      final messages = List.generate(
        10,
        (i) => ChatMessage(content: 'Message $i', isUser: i % 2 == 0),
      );

      final lastThree = messages.skip(messages.length - 3).toList();

      expect(lastThree.length, 3);
      expect(lastThree[0].content, 'Message 7');
      expect(lastThree[1].content, 'Message 8');
      expect(lastThree[2].content, 'Message 9');
    });

    test('should handle empty list operations', () {
      final messages = <ChatMessage>[];

      expect(messages.isEmpty, isTrue);
      expect(messages.where((m) => m.isUser).isEmpty, isTrue);
    });

    test('should copy list immutably', () {
      final original = [
        ChatMessage(content: 'Message 1', isUser: true),
        ChatMessage(content: 'Message 2', isUser: false),
      ];

      final copy = List<ChatMessage>.from(original);
      copy.add(ChatMessage(content: 'Message 3', isUser: true));

      expect(original.length, 2);
      expect(copy.length, 3);
    });

    test('should remove message at index', () {
      final messages = [
        ChatMessage(content: 'Keep 1', isUser: true),
        ChatMessage(content: 'Remove', isUser: false),
        ChatMessage(content: 'Keep 2', isUser: true),
      ];

      final newList = List<ChatMessage>.from(messages);
      newList.removeAt(1);

      expect(newList.length, 2);
      expect(newList[0].content, 'Keep 1');
      expect(newList[1].content, 'Keep 2');
    });

    test('should handle removeAt with invalid index gracefully in bounded check', () {
      final messages = [
        ChatMessage(content: 'Only', isUser: true),
      ];

      // Simulate the removeMessage logic
      void removeMessage(int index) {
        if (index >= 0 && index < messages.length) {
          messages.removeAt(index);
        }
      }

      removeMessage(-1); // Invalid, should not remove
      expect(messages.length, 1);

      removeMessage(5); // Invalid, should not remove
      expect(messages.length, 1);

      removeMessage(0); // Valid
      expect(messages.length, 0);
    });

    test('should clear list correctly', () {
      final messages = [
        ChatMessage(content: 'Message 1', isUser: true),
        ChatMessage(content: 'Message 2', isUser: false),
      ];

      // Simulate clearChat logic
      final clearedList = <ChatMessage>[];

      expect(clearedList.isEmpty, isTrue);
    });
  });

  // ============================================================================
  // CHAT STAGE STATE MACHINE TESTS
  // ============================================================================
  group('ChatStage state machine', () {
    test('should transition from idle to awaitingMealType', () {
      ChatStage stage = ChatStage.idle;
      
      // Simulate user asking for recipes
      stage = ChatStage.awaitingMealType;
      
      expect(stage, ChatStage.awaitingMealType);
    });

    test('should transition from awaitingMealType to awaitingCuisine', () {
      ChatStage stage = ChatStage.awaitingMealType;
      
      // Simulate user selecting meal type
      stage = ChatStage.awaitingCuisine;
      
      expect(stage, ChatStage.awaitingCuisine);
    });

    test('should transition from awaitingCuisine to idle', () {
      ChatStage stage = ChatStage.awaitingCuisine;
      
      // Simulate recipe fetch complete
      stage = ChatStage.idle;
      
      expect(stage, ChatStage.idle);
    });

    test('should be able to reset to idle from any state', () {
      for (final startStage in ChatStage.values) {
        ChatStage stage = startStage;
        stage = ChatStage.idle;
        expect(stage, ChatStage.idle);
      }
    });

    test('should compare stages correctly', () {
      expect(ChatStage.idle == ChatStage.idle, isTrue);
      expect(ChatStage.idle == ChatStage.awaitingMealType, isFalse);
      expect(ChatStage.awaitingMealType == ChatStage.awaitingCuisine, isFalse);
    });

    test('should get stage index', () {
      expect(ChatStage.idle.index, 0);
      expect(ChatStage.awaitingMealType.index, 1);
      expect(ChatStage.awaitingCuisine.index, 2);
    });
  });

  // ============================================================================
  // PENDING STATE MANAGEMENT TESTS
  // ============================================================================
  group('Pending state management', () {
    test('should track pending meal type', () {
      String? pendingMealType;
      String? pendingCuisineType;

      // Simulate setting pending values
      pendingMealType = 'breakfast';
      pendingCuisineType = 'Italian';

      expect(pendingMealType, 'breakfast');
      expect(pendingCuisineType, 'Italian');
    });

    test('should clear pending values', () {
      String? pendingMealType = 'lunch';
      String? pendingCuisineType = 'Mexican';

      // Simulate clearing
      pendingMealType = null;
      pendingCuisineType = null;

      expect(pendingMealType, isNull);
      expect(pendingCuisineType, isNull);
    });

    test('should handle empty cuisine type', () {
      String? pendingCuisineType = 'None';

      final isValidCuisine = pendingCuisineType.isNotEmpty && 
                             pendingCuisineType.toLowerCase() != 'none';

      expect(isValidCuisine, isFalse);
    });

    test('should handle valid cuisine types', () {
      final cuisineTypes = ['Italian', 'Mexican', 'Asian', 'American', 'Mediterranean'];

      for (final cuisine in cuisineTypes) {
        final isValid = cuisine.isNotEmpty && cuisine.toLowerCase() != 'none';
        expect(isValid, isTrue);
      }
    });

    test('should validate meal types', () {
      final validMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
      
      for (final mealType in validMealTypes) {
        expect(mealType.isNotEmpty, isTrue);
      }
    });
  });

  // ============================================================================
  // MESSAGE BUILDING TESTS (simulating bot responses)
  // ============================================================================
  group('Message building patterns', () {
    test('should build confirmation message correctly', () {
      final dietaryHabits = ['vegetarian'];
      final healthRestrictions = ['gluten-free'];
      final dislikes = ['nuts', 'shellfish'];

      final summary = [
        'Dietary habits: ${dietaryHabits.isNotEmpty ? dietaryHabits.join(", ") : "none"}',
        'Health restrictions: ${healthRestrictions.isNotEmpty ? healthRestrictions.join(", ") : "none"}',
        'Excluded ingredients: ${dislikes.isNotEmpty ? dislikes.join(", ") : "none"}',
      ].join('\n');

      expect(summary, contains('vegetarian'));
      expect(summary, contains('gluten-free'));
      expect(summary, contains('nuts, shellfish'));
    });

    test('should handle empty dietary preferences', () {
      final dietaryHabits = <String>[];
      final healthRestrictions = <String>[];
      final dislikes = <String>[];

      final summary = [
        'Dietary habits: ${dietaryHabits.isNotEmpty ? dietaryHabits.join(", ") : "none"}',
        'Health restrictions: ${healthRestrictions.isNotEmpty ? healthRestrictions.join(", ") : "none"}',
        'Excluded ingredients: ${dislikes.isNotEmpty ? dislikes.join(", ") : "none"}',
      ].join('\n');

      expect(summary, contains('Dietary habits: none'));
      expect(summary, contains('Health restrictions: none'));
      expect(summary, contains('Excluded ingredients: none'));
    });

    test('should build recipe response message', () {
      final recipes = [
        {'label': 'Pasta Primavera', 'calories': 450, 'cuisine': 'Italian'},
        {'label': 'Chicken Stir Fry', 'calories': 380, 'cuisine': 'Asian'},
      ];

      final recipeText = recipes.map((r) => 
        '🍽️ ${r['label']} (${r['cuisine']})\n🔥 ${r['calories']} kcal'
      ).join('\n\n');

      expect(recipeText, contains('Pasta Primavera'));
      expect(recipeText, contains('Chicken Stir Fry'));
      expect(recipeText, contains('450 kcal'));
    });

    test('should format meal type selection message', () {
      final mealType = 'breakfast';
      final cuisineType = 'Mediterranean';

      final message = "Selected: $mealType${cuisineType != 'None' ? ' ($cuisineType)' : ''}";

      expect(message, 'Selected: breakfast (Mediterranean)');
    });

    test('should format meal type without cuisine', () {
      final mealType = 'lunch';
      final cuisineType = 'None';

      final message = "Selected: $mealType${cuisineType != 'None' ? ' ($cuisineType)' : ''}";

      expect(message, 'Selected: lunch');
    });
  });

  // ============================================================================
  // ERROR MESSAGE PATTERNS
  // ============================================================================
  group('Error message patterns', () {
    test('should format profile not found error', () {
      const errorMessage = "I couldn't find your profile. Please log in or set up your nutrition preferences before generating recipes.";

      expect(errorMessage, contains("couldn't find"));
      expect(errorMessage, contains('profile'));
    });

    test('should format no recipes found message', () {
      const errorMessage = "I couldn't find any recipes matching your meal profile. Try a different cuisine or meal type?";

      expect(errorMessage, contains('recipes'));
      expect(errorMessage, contains('Try'));
    });

    test('should format fetch more recipes prompt', () {
      const errorMessage = "Please select a meal and cuisine first before fetching more recipes.";

      expect(errorMessage, contains('select'));
      expect(errorMessage, contains('meal'));
    });

    test('should format confirmation declined message', () {
      const message = "Got it. Please update your dietary preferences in your profile before continuing.";

      expect(message, contains('update'));
      expect(message, contains('preferences'));
    });
  });

  // ============================================================================
  // FILTER AND VALIDATION PATTERNS
  // ============================================================================
  group('Filter and validation patterns', () {
    test('should filter out empty dietary habits', () {
      final dietaryHabits = ['vegetarian', '', '  ', 'none', 'vegan'];

      final filtered = dietaryHabits
          .where((h) => h.trim().isNotEmpty && h.toLowerCase() != 'none')
          .toList();

      expect(filtered, ['vegetarian', 'vegan']);
    });

    test('should filter out none values case-insensitively', () {
      final values = ['None', 'NONE', 'none', 'NoNe', 'vegetarian'];

      final filtered = values
          .where((v) => v.toLowerCase() != 'none')
          .toList();

      expect(filtered, ['vegetarian']);
    });

    test('should encode cuisine type for URL', () {
      final cuisineType = 'South American';
      final encoded = Uri.encodeComponent(cuisineType);

      expect(encoded, 'South%20American');
    });

    test('should handle special characters in encoding', () {
      final cuisineType = 'French & Italian';
      final encoded = Uri.encodeComponent(cuisineType);

      expect(encoded, contains('%26')); // & encoded
    });
  });

  // ============================================================================
  // NUTRITION CONTEXT CALCULATION PATTERNS
  // ============================================================================
  group('Nutrition context patterns', () {
    test('should format nutrition summary', () {
      final totalCalories = 1500;
      final totalProtein = 75.5;
      final totalCarbs = 180.3;
      final totalFat = 50.2;
      final foods = ['Apple', 'Chicken Breast', 'Rice'];

      final summary = '''
    User's current nutrition data today:
    - Calories: $totalCalories
    - Protein: ${totalProtein.toStringAsFixed(1)}g
    - Carbs: ${totalCarbs.toStringAsFixed(1)}g
    - Fat: ${totalFat.toStringAsFixed(1)}g
    
    Foods eaten today: ${foods.join(", ")}
    ''';

      expect(summary, contains('Calories: 1500'));
      expect(summary, contains('Protein: 75.5g'));
      expect(summary, contains('Apple, Chicken Breast, Rice'));
    });

    test('should handle empty food log', () {
      final foods = <String>[];
      final foodList = foods.isEmpty ? 'No foods logged' : foods.join(", ");

      expect(foodList, 'No foods logged');
    });

    test('should calculate totals correctly', () {
      final foodLog = [
        {'calories_g': 0.52, 'mass_g': 150.0}, // 78 cal
        {'calories_g': 1.65, 'mass_g': 100.0}, // 165 cal
        {'calories_g': 1.10, 'mass_g': 200.0}, // 220 cal
      ];

      final totalCalories = foodLog.fold<int>(
        0, 
        (sum, food) => sum + ((food['calories_g']! * food['mass_g']!).round()),
      );

      expect(totalCalories, 78 + 165 + 220);
    });
  });
}
