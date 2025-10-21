import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nutrition_assistant/providers/user_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/food_providers.dart';
import '../services/nutrition_service.dart';
import 'dart:convert';

part 'gemini_chat_service.g.dart';

enum ChatStage { idle, awaitingMealType, awaitingCuisine } // like a light switch, it will switch on if awaiting 

// Create chatbot service
@riverpod
class GeminiChatService extends _$GeminiChatService {
  late final GenerativeModel model;

  ChatStage stage = ChatStage.idle;
  String? selectedMealType;
  String? selectedCuisine;

  @override
  List<ChatMessage> build() {
    model = GenerativeModel(
      model: 'gemini-2.5-flash', // Fast and free
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction: Content.text('''You are a helpful nutrition assistant. 
        Help users with meal planning, calorie counting, and nutrition advice.
        Be encouraging and provide practical tips.'''),
    );
    return [
      ChatMessage(
              content: '''
        Hi there! I'm your Nutrition Assistant. I can help you with **meal planning, recipe ideas, and personalized nutrition advice**.

        You can ask me things like:
        • “How much protein should I eat per day?”
        • “Analyze my lunch photo”
        • Or say **“Generate recipes”** to discover delicious meal ideas by cuisine or meal type 🍽️
        ''',
      isUser: false,
      ),
    ];
  }

  //route based on user's input
  Future<void> sendMessage(String userMessage) async {
      state = [...state, ChatMessage(content: userMessage, isUser: true)];

      //generate recipes logic
      if (stage != ChatStage.idle ||
          userMessage.toLowerCase().contains('generate recipes')) {
        await _handleRecipeFlow(userMessage);
        return;
      }

      //normal chat
      await _handleNutritionChat(userMessage);
    }

  // handles breakfast, lunch, dinner choice
  // handles cuisine preference type
  Future<void> _handleRecipeFlow(String userMessage) async {
    if (userMessage.toLowerCase().contains('generate recipes')) {
      stage = ChatStage.awaitingMealType;

      state = [
        ...state,
        ChatMessage(
          content:
              "Sounds good! What type of meal would you like to generate recipes for?\n\nOptions: Breakfast, Lunch, Dinner, Snack, or Teatime.",
          isUser: false,
        ),
      ];
      return;
    }

    if (stage == ChatStage.awaitingMealType) {
      selectedMealType = userMessage.trim();
      stage = ChatStage.awaitingCuisine;

      state = [
        ...state,
        ChatMessage(
          content: '''
          Great choice! 🌎 What cuisine are you in the mood for?

          Options:
          American, Asian, British, Caribbean, Central Europe, Chinese, Eastern Europe, French, Greek, Indian, Italian, Japanese, Korean, Kosher, Mediterranean, Mexican, Middle Eastern, Nordic, South American, South East Asian, or **None**
          ''',
          isUser: false,
        ),
      ];
      return;
    }

    if (stage == ChatStage.awaitingCuisine) {
      selectedCuisine = userMessage.trim();
      stage = ChatStage.idle;

      final meal = selectedMealType ?? "meal";
      final cuisine = selectedCuisine ?? "any";

      state = [
        ...state,
        ChatMessage(
          content:
              "Got it! Generating $cuisine $meal recipes for you. Just a moment...",
          isUser: false,
        ),
      ];

      await _fetchRecipes(meal, cuisine);
      return;
    }
  }

    //normal chat flow that was handled prior to generating recipes!
    Future<void> _handleNutritionChat(String userMessage) async {
    
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

    //fetch recipes with mealType, cuisineType 
    //fetch with dietary and health restrictions, likes and dislikes
    Future<void> _fetchRecipes(String mealType, String cuisineType) async {
      try {
   
        final appUser = ref.read(userProfileProvider);

        // user profile == null then notify them!
        if (appUser == null) {
          state = [
            ...state,
            ChatMessage(
              content:
                  "I couldn’t find your profile. Please log in or set up your nutrition preferences before generating recipes.",
              isUser: false,
            ),
          ];
          return;
        }

        final mealProfile = appUser.mealProfile;

        //default to empty lists if mealprofile == null
        final dietaryHabits = (mealProfile.dietaryHabits
                .where((h) => h.trim().isNotEmpty && h.toLowerCase() != 'none')
                .toList())
            .cast<String>();

        final healthRestrictions = (mealProfile.healthRestrictions
                .where((r) => r.trim().isNotEmpty && r.toLowerCase() != 'none')
                .toList())
            .cast<String>();

        final appId = dotenv.env['EDAMAM_APP_ID'];
        final appKey = dotenv.env['EDAMAM_APP_KEY'];

        //start edamam api
        final params = <String>[
          'type=public',
          'q=$mealType',
          'mealType=$mealType',
          'app_id=$appId',
          'app_key=$appKey',
        ];

        //add cuisine if !none && !empty
        if (cuisineType.isNotEmpty && cuisineType.toLowerCase() != 'none') {
          params.add('cuisineType=${Uri.encodeComponent(cuisineType)}');
        }

        //add diet if !empty && !none
        if (dietaryHabits.isNotEmpty) {
          for (final habit in dietaryHabits) {
            if (habit.trim().isNotEmpty && habit.toLowerCase() != 'none') {
              params.add('diet=${Uri.encodeComponent(habit)}');
            }
          }
        }

        //add health if !none && !empty
        if (healthRestrictions.isNotEmpty) {
          for (final restriction in healthRestrictions) {
            if (restriction.trim().isNotEmpty && restriction.toLowerCase() != 'none') {
              params.add('health=${Uri.encodeComponent(restriction)}');
            }
          }
        }

        //build uri
        final uri = Uri.parse(
          'https://api.edamam.com/api/recipes/v2?${params.join('&')}',
        );
      
        final response = await HttpClient().getUrl(uri).then((req) => req.close());
        final body = await response.transform(SystemEncoding().decoder).join();
        final json = jsonDecode(body);

        final hits = (json['hits'] as List?) ?? []; //recipes that are returned from the call

        if (hits.isEmpty) {
          state = [
            ...state,
            ChatMessage(
              content:
                  "I couldn’t find any recipes matching your meal profile 😕. Try a different cuisine or meal type?",
              isUser: false,
            ),
          ];
          return;
        }

        //choose first 3 recipes for now! - but u SHOULD CALL THE HEURISTIC ALGORITHM!
        final topRecipes = hits.take(3).map((hit) {
          final r = hit['recipe'];
          return "🍴 ${r['label']}\n${r['url']}";
        }).join("\n\n");

        state = [
          ...state,
          ChatMessage(
            content:
                "Here are a few recipes that fit your profile:\n\n$topRecipes",
            isUser: false,
          ),
        ];
      } catch (e) {
        state = [
          ...state,
          ChatMessage(
            content: "Error fetching recipes: $e",
            isUser: false,
          ),
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

    //start planning this!
    void heuristic(){

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
