import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/user_providers.dart';
import '../db/user.dart';

part 'gemini_chat_service.g.dart';

// -----------------------------------------------------------------------------
// Gemini Chat Service
// -----------------------------------------------------------------------------
@riverpod
class GeminiChatService extends _$GeminiChatService {
  late final GenerativeModel model;

  @override
  List<ChatMessage> build() {
    model = GenerativeModel(
      model: 'gemini-2.5-flash', // Fast and efficient
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction: Content.text('''You are a helpful nutrition assistant. 
      Help users with meal planning, calorie counting, and nutrition advice. 
      Be encouraging, concise, and provide practical guidance.'''),
    );
    return [];
  }

  // ---------------------------------------------------------------------------
  // Send Chat Message with Contextual Nutrition Info
  // ---------------------------------------------------------------------------
  Future<void> sendMessage(String userMessage) async {
    // Add user message
    state = [...state, ChatMessage(content: userMessage, isUser: true)];

    try {
      final userProfile = ref.read(userProfileProvider);
      final foodLog = userProfile?.loggedFoodItems ?? [];

      // Compute totals from FoodItems
      final totalCalories =
      foodLog.fold<double>(0, (sum, f) => sum + f.calories_g);
      final totalProtein =
      foodLog.fold<double>(0, (sum, f) => sum + f.protein_g);
      final totalCarbs =
      foodLog.fold<double>(0, (sum, f) => sum + f.carbs_g);
      final totalFat = foodLog.fold<double>(0, (sum, f) => sum + f.fat);

      final foodList = foodLog.isNotEmpty
          ? foodLog.map((f) => f.name).join(', ')
          : 'No foods logged yet.';

      final contextualPrompt = '''
User's nutrition summary today:
- Calories: ${totalCalories.toStringAsFixed(0)}
- Protein: ${totalProtein.toStringAsFixed(1)}g
- Carbs: ${totalCarbs.toStringAsFixed(1)}g
- Fat: ${totalFat.toStringAsFixed(1)}g

Foods eaten today: $foodList

User question: $userMessage
''';

      final response =
      await model.generateContent([Content.text(contextualPrompt)]);

      // Add AI response
      state = [
        ...state,
        ChatMessage(
          content: response.text ?? "I couldn’t process that request.",
          isUser: false,
        )
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          content:
          "Sorry, I ran into an issue: $e. Please try again shortly.",
          isUser: false,
        )
      ];
    }
  }

  // ---------------------------------------------------------------------------
  // Analyze Food Photo
  // ---------------------------------------------------------------------------
  Future<void> analyzeFoodPhoto(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();

      final response = await model.generateContent([
        Content.multi([
          TextPart(
            'Analyze this food image and estimate its nutritional content. '
                'Provide calories, protein, carbs, and fat estimates per serving, '
                'and describe portion size clearly.',
          ),
          DataPart('image/jpeg', imageBytes),
        ])
      ]);

      state = [
        ...state,
        ChatMessage(
          content: response.text ?? "I couldn’t analyze the image.",
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

  // ---------------------------------------------------------------------------
  // Utility Methods
  // ---------------------------------------------------------------------------
  void clearChat() => state = [];

  void removeMessage(int index) {
    if (index >= 0 && index < state.length) {
      final newState = List<ChatMessage>.from(state)..removeAt(index);
      state = newState;
    }
  }
}

// -----------------------------------------------------------------------------
// ChatMessage Model
// -----------------------------------------------------------------------------
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
  String toString() =>
      'ChatMessage(content: $content, isUser: $isUser, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.content == content &&
        other.isUser == isUser &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => content.hashCode ^ isUser.hashCode ^ timestamp.hashCode;

  // Helpers
  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }
}
