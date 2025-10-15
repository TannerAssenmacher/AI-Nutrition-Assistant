import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/food_providers.dart';
import '../services/nutrition_service.dart';

part 'gemini_chat_service.g.dart';

// Create chatbot service
@riverpod
class GeminiChatService extends _$GeminiChatService {
  late final GenerativeModel model;

  @override
  List<ChatMessage> build() {
    model = GenerativeModel(
      model: 'gemini-2.5-flash', // Fast and free
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction: Content.text('''You are a helpful nutrition assistant. 
        Help users with meal planning, calorie counting, and nutrition advice.
        Be encouraging and provide practical tips.'''),
    );
    return [];
  }

  Future<void> sendMessage(String userMessage) async {
    // Add user message
    state = [...state, ChatMessage(content: userMessage, isUser: true)];

    try {
      // Get nutrition context from your existing services
      final foodLog = ref.read(foodLogProvider);

      // Create a simple nutrition calculation since NutritionService.calculateNutrition might not exist
      final totalCalories =
          foodLog.fold<int>(0, (sum, food) => sum + food.caloriesPer100g);
      final totalProtein =
          foodLog.fold<double>(0, (sum, food) => sum + food.proteinPer100g);
      final totalCarbs =
          foodLog.fold<double>(0, (sum, food) => sum + food.carbsPer100g);
      final totalFat =
          foodLog.fold<double>(0, (sum, food) => sum + food.fatPer100g);

      final contextualPrompt = '''
      User's current nutrition data today:
      - Calories: $totalCalories
      - Protein: ${totalProtein.toStringAsFixed(1)}g
      - Carbs: ${totalCarbs.toStringAsFixed(1)}g
      - Fat: ${totalFat.toStringAsFixed(1)}g
      
      Foods eaten today: ${foodLog.map((food) => food.name).join(", ")}
      
      User question: $userMessage
      ''';

      final response =
          await model.generateContent([Content.text(contextualPrompt)]);

      // Add AI response
      state = [
        ...state,
        ChatMessage(
          content: response.text ?? "I couldn't process that request.",
          isUser: false,
        )
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          content:
              "Sorry, I'm having trouble right now. Please try again. Error: $e",
          isUser: false,
        )
      ];
    }
  }

  // Analyze food photo
  Future<void> analyzeFoodPhoto(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();

      final response = await model.generateContent([
        Content.multi([
          TextPart(
            'Analyze this food image and estimate its nutritional content. Provide calories, protein, carbs, and fat estimates per serving. Be specific about portion size.',
          ),
          DataPart('image/jpeg', imageBytes),
        ])
      ]);

      state = [
        ...state,
        ChatMessage(
          content: response.text ?? "Couldn't analyze the image.",
          isUser: false,
        )
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          content: "Error analyzing image: $e",
          isUser: false,
        )
      ];
    }
  }

  void clearChat() {
    state = [];
  }

  void removeMessage(int index) {
    if (index >= 0 && index < state.length) {
      final newState = List<ChatMessage>.from(state);
      newState.removeAt(index);
      state = newState;
    }
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ChatMessage(content: $content, isUser: $isUser, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.content == content &&
        other.isUser == isUser &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return content.hashCode ^ isUser.hashCode ^ timestamp.hashCode;
  }

  // Helper methods
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }
}
