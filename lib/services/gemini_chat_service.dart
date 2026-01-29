import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../providers/food_providers.dart';
import '../db/firestore_helper.dart';
import 'dart:convert';

part 'gemini_chat_service.g.dart';

//controlling chatflow
enum ChatStage { idle, awaitingMealType, awaitingCuisine }

//chatbot service
@riverpod
class GeminiChatService extends _$GeminiChatService {
  late final GenerativeModel model;
  ChatStage stage = ChatStage.idle;

  //flags
  String? _pendingMealType;
  String? _pendingCuisineType;
  final Map<String, int> _recipeOffsets = {};
  final int _batchSize = 3;
  final Set<String> _shownRecipeUris = {};

  final nonMeals = [
    "butter",
    "margarine",
    "oil",
    "shake",
    "smoothie",
    "syrup",
    "sauce",
    "condiment",
    "spread",
    "drink",
    "cream"
  ];

  //build() initial state
  @override
  List<ChatMessage> build() {
    model = GenerativeModel(
      model: 'gemini-2.5-flash', //fast & free
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction: Content.text('''You are a helpful nutrition assistant. 
        Help users with meal planning, calorie counting, and nutrition advice.
        Be encouraging and provide practical tips.'''),
    );
    return [];
  }

  //normal chat response
  Future<void> sendMessage(String userMessage) async {
    state = [
      ...state,
      ChatMessage(content: userMessage, isUser: true)
    ]; //add user's message to chat

    try {
      final foodLog = ref.read(foodLogProvider); //read today's food log

      //create a simple nutrition calculation
      final totalCalories = foodLog.fold<int>(
          0, (sum, food) => sum + (food.calories_g * food.mass_g).round());
      final totalProtein =
          foodLog.fold<double>(0, (sum, food) => sum + food.protein_g);
      final totalCarbs =
          foodLog.fold<double>(0, (sum, food) => sum + food.carbs_g);
      final totalFat = foodLog.fold<double>(0, (sum, food) => sum + food.fat);

      // Get user profile for personalized context
      String profileContext = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final appUser = await FirestoreHelper.getUser(user.uid);
        if (appUser != null) {
          final mp = appUser.mealProfile;
          profileContext = '''
    User profile:
    - Sex: ${appUser.sex}, Activity level: ${appUser.activityLevel}
    - Height: ${appUser.height} in, Weight: ${appUser.weight} lbs
    - Daily calorie goal: ${mp.dailyCalorieGoal} kcal
    - Dietary goal: ${mp.dietaryGoal}
    - Macro goals: Protein ${mp.macroGoals['protein']?.round() ?? 20}%, Carbs ${mp.macroGoals['carbs']?.round() ?? 50}%, Fat ${mp.macroGoals['fat']?.round() ?? 30}%
    - Dietary habits: ${mp.dietaryHabits.where((h) => h.trim().isNotEmpty && h.toLowerCase() != 'none').join(', ')}
    - Health restrictions: ${mp.healthRestrictions.where((r) => r.trim().isNotEmpty && r.toLowerCase() != 'none').join(', ')}
    - Food likes: ${mp.preferences.likes.where((l) => l.trim().isNotEmpty && l.toLowerCase() != 'none').join(', ')}
    - Food dislikes: ${mp.preferences.dislikes.where((d) => d.trim().isNotEmpty && d.toLowerCase() != 'none').join(', ')}
    ''';
        }
      }

      final contextualPrompt = '''
    $profileContext
    User's current nutrition data today:
    - Calories consumed: $totalCalories
    - Protein: ${totalProtein.toStringAsFixed(1)}g
    - Carbs: ${totalCarbs.toStringAsFixed(1)}g
    - Fat: ${totalFat.toStringAsFixed(1)}g

    Foods eaten today: ${foodLog.map((food) => food.name).join(", ")}

    User question: $userMessage
    ''';

      final response = await model
          .generateContent([Content.text(contextualPrompt)]); //call gemini

      //add gemini's response
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

  //start generate recipe flow!
  //call fetchrecipes
  Future<void> handleMealTypeSelection( String mealType, String cuisineType) async {
    await _fetchRecipes(mealType, cuisineType);
  }

  //confirmation on user profile
  Future<void> confirmMealProfile(bool confirmed) async {

    final notifier = ref.read(geminiChatServiceProvider.notifier);

    notifier.addLocalUserMessage(confirmed ? "Yes" : "No");

    if (!confirmed) {
      // "No"
      state = [
        ...state,
        ChatMessage(
          content:
              "Got it. Please update your dietary preferences in your profile before continuing.",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
      // clear pending values so we don’t accidentally reuse them later
      _pendingMealType = null;
      _pendingCuisineType = null;
      return;
    }

    // "Yes"
    state = [
      ...state,
      ChatMessage(
        content: "Perfect! Generating your personalized recipes now.",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];

    if (_pendingMealType != null && _pendingCuisineType != null) {
      await _fetchRecipes(_pendingMealType!, _pendingCuisineType!,
          fromConfirmation: true);

      //global variables no longer needed
      _pendingMealType = null;
      _pendingCuisineType = null;
    }
  }

  //fetch recipes with mealType, cuisineType
  //fetch with dietary and health restrictions, likes and dislikes
  Future<void> _fetchRecipes(
    String mealType,
    String cuisineType, {
    bool fromConfirmation = false,
    bool forceNewBatch = false,
  }) async {

    try {
      //user profile from user signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appUser = await FirestoreHelper.getUser(user.uid);
      if (appUser == null) {
        state = [
          ...state,
          ChatMessage(
            content:
                "I couldn’t find your profile. Please set up your nutrition preferences before generating recipes.",
            isUser: false,
          ),
        ];
        return;
      }

      final mealProfile = appUser.mealProfile;
      final preferences = mealProfile.preferences;

      final dietaryHabits = mealProfile.dietaryHabits
          .where((h) => h.trim().isNotEmpty && h.toLowerCase() != 'none')
          .toList();

      final healthRestrictions = mealProfile.healthRestrictions
          .where((r) => r.trim().isNotEmpty && r.toLowerCase() != 'none')
          .toList();

      final dislikes = preferences.dislikes
          .where((d) => d.trim().isNotEmpty && d.toLowerCase() != 'none')
          .toList();

      final likes = preferences.likes
          .where((l) => l.trim().isNotEmpty && l.toLowerCase() != 'none')
          .toList();

      //user confirmation on meal profile
      if (!fromConfirmation) {
        _pendingMealType = mealType;
        _pendingCuisineType = cuisineType;
        _recipeOffsets["$mealType-$cuisineType"] =
            0; // reset when selection changes

        state = [
          ...state,
          ChatMessage(
            content: jsonEncode({
              "type": "meal_profile_summary",
              "mealType": mealType,
              "cuisineType": cuisineType,
              "dietary": dietaryHabits,
              "health": healthRestrictions,
              "likes": likes,
              "dislikes": dislikes,
              "dietaryGoal": mealProfile.dietaryGoal,
              "dailyCalorieGoal": mealProfile.dailyCalorieGoal,
              "macroGoals": mealProfile.macroGoals,
            }),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ];

        return;
      } else {
        _pendingMealType = mealType;
        _pendingCuisineType = cuisineType;
      }

      // Prepare macro goals as percentages
      final macroGoals = {
        'protein': mealProfile.macroGoals['protein'] ?? 20.0,
        'carbs': mealProfile.macroGoals['carbs'] ?? 50.0,
        'fat': mealProfile.macroGoals['fat'] ?? 30.0,
      };

      // Compute today's consumption data for smart calorie targeting
      final foodLog = ref.read(foodLogProvider);
      final today = DateTime.now();
      final todaysFoods = foodLog.where((item) =>
          item.consumedAt.year == today.year &&
          item.consumedAt.month == today.month &&
          item.consumedAt.day == today.day).toList();

      final consumedCalories = todaysFoods.fold<int>(
          0, (sum, food) => sum + (food.calories_g * food.mass_g).round());

      double consumedProtein = 0, consumedCarbs = 0, consumedFat = 0;
      for (final item in todaysFoods) {
        consumedProtein += item.protein_g * item.mass_g;
        consumedCarbs += item.carbs_g * item.mass_g;
        consumedFat += item.fat * item.mass_g;
      }

      final consumedMealTypes = todaysFoods
          .map((f) => f.mealType.toLowerCase())
          .toSet()
          .toList();

      // Call RAG-based searchRecipes Cloud Function with full user profile
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('searchRecipes');

      final result = await callable.call({
        // Meal context
        'mealType': mealType,
        'cuisineType': cuisineType,

        // Dietary restrictions and preferences
        'healthRestrictions': healthRestrictions,
        'dietaryHabits': dietaryHabits,
        'dislikes': dislikes,
        'likes': likes,

        // User profile data for personalized filtering
        'sex': appUser.sex,
        'activityLevel': appUser.activityLevel,
        'dietaryGoal': mealProfile.dietaryGoal,
        'dailyCalorieGoal': mealProfile.dailyCalorieGoal,
        'macroGoals': macroGoals,

        // Today's consumption data for smart calorie targeting
        'consumedCalories': consumedCalories,
        'consumedMealTypes': consumedMealTypes,
        'consumedMacros': {
          'protein': consumedProtein,
          'carbs': consumedCarbs,
          'fat': consumedFat,
        },

        // Physical profile for context
        'dob': appUser.dob?.toIso8601String(),
        'height': appUser.height,
        'weight': appUser.weight,

        // Pagination
        'excludeIds': _shownRecipeUris.toList(),
        'limit': 10,
      });

      final data = result.data as Map<String, dynamic>;
      final recipes = (data['recipes'] as List?) ?? [];
      final isExactMatch = data['isExactMatch'] as bool? ?? true;

      if (recipes.isEmpty) {
        state = [
          ...state,
          ChatMessage(
            content:
                "I couldn't find any recipes right now. Please try adjusting your preferences or selecting a different cuisine.",
            isUser: false,
          )
        ];
        return;
      }

      // Show different message based on whether results are exact matches
      if (!isExactMatch) {
        state = [
          ...state,
          ChatMessage(
            content:
                "I couldn't find recipes that match all your preferences exactly. Here are some close alternatives that you might enjoy:",
            isUser: false,
          ),
        ];
      } else {
        state = [
          ...state,
          ChatMessage(
            content:
                "Here are some recipes I found that match your nutrition profile!",
            isUser: false,
          ),
        ];
      }

      final List<Map<String, dynamic>> recipeList = [];

      final filteredRecipes = recipes.where((recipe) {
        final id = recipe['id'] as String;
        final label = (recipe['label'] ?? '').toString().toLowerCase();

        // skip non-meals
        if (nonMeals.any((nm) => label.contains(nm))) return false;

        // skip already shown
        if (_shownRecipeUris.contains(id)) return false;

        return true;
      }).toList();

      for (final recipe in filteredRecipes.take(3)) {
        _shownRecipeUris.add(recipe['id'] as String);

        // Get ingredients from Cloud Function response
        final rawIngredients = recipe['ingredients'] ?? [];
        final ingredients = List<String>.from(rawIngredients)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        print('ingredients: $ingredients');
        
        final label = recipe['label'] ?? 'Unknown Recipe';
        final calories = (recipe['calories'] as num?)?.round() ?? 0;
        final cuisine = recipe['cuisine'] ?? 'General';
        final url = recipe['imageUrl'] ?? '';

        // Use instructions from Cloud Function (already in Firestore)
        // Fall back to Gemini-generated instructions if not available
        String instructions = recipe['instructions'] ?? '';
        if (instructions.isEmpty) {
          instructions = await _generateInstructionsWithGemini(label, ingredients, calories);
        }

        recipeList.add({
          'label': label,
          'cuisine': cuisine,
          'ingredients': ingredients,
          'calories': calories,
          'protein': (recipe['protein'] as num?)?.round() ?? 0,
          'carbs': (recipe['carbs'] as num?)?.round() ?? 0,
          'fat': (recipe['fat'] as num?)?.round() ?? 0,
          'fiber': (recipe['fiber'] as num?)?.round(),
          'sugar': (recipe['sugar'] as num?)?.round(),
          'sodium': (recipe['sodium'] as num?)?.round(),
          'servings': recipe['servings'],
          'readyInMinutes': recipe['readyInMinutes'],
          'instructions': instructions,
          'imageUrl': url,
          'matchScore': recipe['matchScore'],
        });
      }

      // If no recipes passed filtering, inform user
      if (recipeList.isEmpty) {
        state = [
          ...state,
          ChatMessage(
            content:
                "I've shown you all the matching recipes I have. Try different options or adjust your preferences for more variety!",
            isUser: false,
          )
        ];
        return;
      }

      // Add the recipe results (intro message was already added above)
      state = [
        ...state,
        ChatMessage(
          content: jsonEncode({
            "type": "recipe_results",
            "recipes": recipeList,
          }),
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

  //instructions with gemini
  Future<String> _generateInstructionsWithGemini(
      String title, List<String> ingredients, int calories,
      {int retries = 3}) async {
    final prompt = '''
        You are a nutrition and cooking expert.
        ONLY output plain text numbered step-by-step cooking instructions for the recipe below.
        Do NOT include any introductions, greetings, bold/markdown formatting, or commentary.

        Recipe name: $title
        Estimated calories: $calories kcal

        Ingredients:
        ${ingredients.map((i) => "- $i").join("\n")}

        Requirements:
        - Write only numbered cooking steps
        - Keep steps simple and beginner-friendly
        - Maximum 10 steps
        - Do NOT repeat ingredient list
        - No extra commentary
        ''';

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await model.generateContent([Content.text(prompt)]);
        return response.text?.trim() ?? "Instructions unavailable.";
      } catch (e) {
        print("Attempt ${attempt + 1} failed: $e");
        if (attempt == retries - 1) {
          return "Instructions unavailable right now. Please try again later.";
        }
        await Future.delayed(Duration(seconds: 2)); // wait before retrying
      }
    }
    return "Instructions unavailable.";
  }

  //request more recipes - if they dont like the ones already shown!
  Future<void> requestMoreRecipes({
    required String mealType,
    required String cuisineType,
  }) async {
    if (mealType.isEmpty || cuisineType.isEmpty) {
      state = [
        ...state,
        ChatMessage(
          content:
              "I need a meal type and cuisine before I can fetch more recipes.",
          isUser: false,
        ),
      ];
      return;
    }

    state = [
      ...state,
      ChatMessage(
        content: "Generating More Recipes!",
        isUser: false,
      ),
    ];

    await _fetchRecipes(mealType, cuisineType,
        fromConfirmation: true, forceNewBatch: true);
  }

  //analyze food photo
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

  //adds a user bubble directly without gemini
  void addLocalUserMessage(String text) {
    state = [
      ...state,
      ChatMessage(content: text, isUser: true),
    ];
  }

  //adds a bot bubble directly without gemini
  void addLocalBotMessage(String text) {
    state = [
      ...state,
      ChatMessage(content: text, isUser: false),
    ];
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