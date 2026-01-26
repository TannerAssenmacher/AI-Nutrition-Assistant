import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/env.dart';
import '../providers/food_providers.dart';
import '../db/firestore_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  //helper
  String _key(String mealType, String cuisineType) => '$mealType|$cuisineType';

  //build() initial state
  @override
  List<ChatMessage> build() {
    final apiKey = Env.require(Env.geminiApiKey, 'GEMINI_API_KEY');
    model = GenerativeModel(
      model: 'gemini-2.5-flash', //fast & free
      apiKey: apiKey,
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

      final contextualPrompt = '''
    User's current nutrition data today:
    - Calories: $totalCalories
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
              "dietary": dietaryHabits,
              "health": healthRestrictions,
              "dislikes": dislikes,
              "mealType": mealType,
              "cuisineType": cuisineType,
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

      final appId = Env.edamamApiId;
      final appKey = Env.edamamApiKey;
      if (appId.isEmpty || appKey.isEmpty) {
        state = [
          ...state,
          ChatMessage(
            content:
                "Recipe search keys are missing. Please set EDAMAM_API_ID and EDAMAM_API_KEY via --dart-define.",
            isUser: false,
          ),
        ];
        return;
      }

      final params = <String>[
        'type=public',
        'mealType=$mealType',
        'app_id=$appId',
        'app_key=$appKey',
      ];

      if (cuisineType.isNotEmpty && cuisineType.toLowerCase() != "none") {
        params.add('cuisineType=${Uri.encodeComponent(cuisineType)}');
      }

      for (final d in dietaryHabits) {
        params.add("diet=$d");
      }
      for (final h in healthRestrictions) {
        params.add("health=$h");
      }
      for (final x in dislikes) {
        params.add("excluded=$x");
      }

      if (forceNewBatch &&
          (_recipeOffsets[_key(mealType, cuisineType)] == null)) {
        _recipeOffsets[_key(mealType, cuisineType)] = 0;
      }

      // new code:
      int from = _recipeOffsets[_key(mealType, cuisineType)] ?? 0;
      int to = from + _batchSize;
      print("from $from and to $to");

      // increment for next batch
      _recipeOffsets[_key(mealType, cuisineType)] = to;

      params.add("from=$from");
      params.add("to=$to");

      final uri = Uri.parse(
          "https://api.edamam.com/api/recipes/v2?${params.join('&')}");

      final response = await http.get(uri);
      final jsonBody = jsonDecode(response.body);
      final hits = (jsonBody["hits"] as List?) ?? [];

      if (hits.isEmpty) {
        state = [
          ...state,
          ChatMessage(
            content:
                "I couldn't find recipes that match your preferences. Try different options?",
            isUser: false,
          )
        ];
        return;
      }

      final List<Map<String, dynamic>> recipeList = [];

      final filteredHits = hits.where((hit) {
        final recipe = hit['recipe'];
        final uri = recipe['uri'] as String;
        final labelLower = (recipe["label"] ?? "").toString().toLowerCase();

        // skip non-meals
        if (nonMeals.any((nm) => labelLower.contains(nm))) return false;

        // skip already shown
        if (_shownRecipeUris.contains(uri)) return false;

        return true;
      }).toList();

      for (final hit in filteredHits.take(3)) {
        final recipe = hit['recipe'];
        _shownRecipeUris.add(recipe['uri'] as String);

        // merge ingredientLines + ingredients[].text
        final rawLines = recipe["ingredientLines"] ?? [];
        final rawIng = recipe["ingredients"] ?? [];

        final allIngredients = [
          ...List<String>.from(rawLines),
          ...rawIng.map<String>((i) => (i["text"] ?? "").toString()).toList(),
        ];

        final ingredients = allIngredients
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
            .cast<String>();

        print('ingredients: $ingredients');
        
        final label = recipe["label"] ?? "Unknown Recipe";
        final calories = (recipe["calories"] as num?)?.round() ?? 0;
        final cuisine =
            (recipe["cuisineType"] != null && recipe["cuisineType"].isNotEmpty)
                ? recipe["cuisineType"][0]
                : "General";
        final url = recipe["url"] ?? "";

        //cooking instructins from gemini
        final instructions =
            await _generateInstructionsWithGemini(label, ingredients, calories);

        recipeList.add({
          "label": label,
          "cuisine": cuisine,
          "ingredients": ingredients,
          "calories": calories,
          "instructions": instructions,
          "url": url,
        });
      }

      state = [
        ...state,
        ChatMessage(
          content:
              "Here are some recipes I found that match your nutrition profile!",
          isUser: false,
        ),
      ];

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
    if (mealType == null || cuisineType == null) {
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
