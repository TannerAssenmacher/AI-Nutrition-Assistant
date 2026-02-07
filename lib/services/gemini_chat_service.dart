import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/env.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../providers/food_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/firestore_helper.dart';
import 'dart:convert';
import 'package:nutrition_assistant/db/planned_food.dart';
import '../models/planned_food_input.dart';

part 'gemini_chat_service.g.dart';

// Loading state for the chatbot
final chatLoadingProvider = StateProvider<bool>((ref) => false);

//controlling chatflow
enum ChatStage { idle, awaitingMealType, awaitingCuisine }

//chatbot service
@Riverpod(keepAlive: true)
class GeminiChatService extends _$GeminiChatService {
  late final GenerativeModel model;
  ChatStage stage = ChatStage.idle;

  //flags
  final Map<String, int> _recipeOffsets = {};
  final int _batchSize = 3;
  final Set<String> _shownRecipeUris = {};

  /// Stores the last batch of recipes shown to the user (full details)
  /// Used to provide context when user asks about or wants to modify recipes
  List<Map<String, dynamic>> _lastShownRecipes = [];

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
    final apiKey = Env.require(Env.geminiApiKey, 'GEMINI_API_KEY');
    model = GenerativeModel(
      model: 'gemini-2.5-flash', //fast & free
      apiKey: apiKey,
      systemInstruction: Content.text('''You are a helpful nutrition assistant.
        Help users with meal planning, calorie counting, and nutrition advice.
        Be encouraging and provide practical tips.
        Do not use markdown formatting like ** or * in your responses. Use plain text only.

        IMPORTANT: Never generate or invent recipes from your own knowledge. Only discuss recipes that have been explicitly provided to you in the conversation. If a user asks for recipe suggestions, tell them you can help find recipes from the database - they just need to ask for meal suggestions. You can help modify or adapt recipes that have been shown, answer questions about them, and provide cooking tips.

        CRITICAL: When you modify, adjust, or present a recipe (e.g., adjusting servings, substituting ingredients), you MUST output it as JSON in this EXACT format:

        {"type":"recipe_results","recipes":[{"id":"modified_123","label":"Recipe Name","cuisine":"Italian","ingredients":["1 cup flour","2 eggs"],"calories":450,"protein":15,"carbs":60,"fat":12,"fiber":3,"sugar":5,"sodium":200,"servings":2,"readyInMinutes":30,"instructions":"Step by step instructions...","imageUrl":"https://example.com/image.jpg"}]}

        RULES FOR MODIFIED RECIPES:
        - Output ONLY the JSON - no other text before or after
        - Use "modified_" + original recipe id for the id field
        - IMAGE HANDLING (CRITICAL):
          * Copy the EXACT "Image URL" value from the original recipe context
          * NEVER generate, modify, or guess image URLs
          * If the original has no image URL or it's empty, use an empty string: "imageUrl":""
          * Do NOT create new URLs or search for images - only use what's provided
        - Calculate adjusted values when changing servings (multiply/divide all ingredients and macros)
        - Include all required fields: id, label, cuisine, ingredients (as array), calories, protein, carbs, fat, fiber, sugar, sodium, servings, readyInMinutes, instructions, imageUrl
        - For questions or general responses (not presenting a recipe), use plain text as normal'''),
    );
    return [];
  }

  /// Build conversation history for Gemini multi-turn chat.
  /// Takes last 20 messages and converts them to Content objects.
  /// Recipe results are summarized to avoid token bloat.
  List<Content> _buildConversationHistory() {
    final recentMessages = state.length > 20
        ? state.sublist(state.length - 20)
        : state;

    return recentMessages.map((msg) {
      String text = msg.content;

      // Summarize special message types to reduce tokens
      try {
        final parsed = jsonDecode(msg.content);
        if (parsed is Map && parsed['type'] == 'recipe_results') {
          final recipes = parsed['recipes'] as List? ?? [];
          final names = recipes.map((r) => r['label']).join(', ');
          text = 'I showed you these recipes: $names';
        } else if (parsed is Map && parsed['type'] == 'meal_profile_summary') {
          text = 'I showed your meal profile for confirmation.';
        }
      } catch (_) {
        // Not JSON, use as-is
      }

      return Content(
        msg.isUser ? 'user' : 'model',
        [TextPart(text)],
      );
    }).toList();
  }

  /// Check if a message is likely about recipes we've shown.
  /// Returns true if user might be asking about, modifying, or referencing recipes.
  bool _isRecipeRelatedMessage(String message) {
    if (_lastShownRecipes.isEmpty) return false;

    final lower = message.toLowerCase();

    // Keywords suggesting recipe modification or questions
    const modificationKeywords = [
      'substitute', 'instead of', 'replace', 'without', 'no ',
      'don\'t have', 'dont have', 'change', 'modify', 'swap',
      'less ', 'more ', 'spicier', 'milder', 'healthier',
      'vegetarian', 'vegan', 'gluten', 'dairy',
    ];

    // Keywords suggesting questions about the recipe
    const questionKeywords = [
      'recipe', 'ingredients', 'instructions', 'how to make',
      'what\'s in', 'whats in', 'tell me about', 'explain',
      'calories', 'protein', 'nutrition', 'that dish', 'the dish',
      'first one', 'second one', 'third one', 'which one',
    ];

    // Keywords for showing exact recipe again
    const showAgainKeywords = [
      'show me', 'give me', 'see', 'display', 'repeat',
      'again', 'one more time', 'that one',
    ];

    // Check for modification keywords
    for (final keyword in modificationKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Check for question keywords
    for (final keyword in questionKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Check for show again keywords
    for (final keyword in showAgainKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Check if message contains any recipe name
    for (final recipe in _lastShownRecipes) {
      final name = (recipe['label'] as String?)?.toLowerCase() ?? '';
      if (name.isNotEmpty && lower.contains(name.split(' ').first)) {
        return true;
      }
    }

    return false;
  }

  /// Check if user wants to see the exact recipe again (not modified).
  /// Returns true for requests like "show me the first one again"
  bool _wantsExactRecipe(String message) {
    if (_lastShownRecipes.isEmpty) return false;

    final lower = message.toLowerCase();

    // Keywords suggesting user wants exact recipe displayed
    const showAgainPatterns = [
      'show me', 'give me', 'see the', 'display', 'repeat',
      'again', 'one more time', 'show that', 'show the',
      'can i see', 'let me see', 'pull up',
    ];

    // Keywords suggesting user wants to MODIFY (not exact)
    const modificationKeywords = [
      'substitute', 'instead of', 'replace', 'without', 'no ',
      'don\'t have', 'dont have', 'change', 'modify', 'swap',
      'less ', 'more ', 'spicier', 'milder', 'healthier',
      'make it', 'but with', 'but without',
    ];

    // If any modification keyword is present, they don't want exact
    for (final keyword in modificationKeywords) {
      if (lower.contains(keyword)) return false;
    }

    // Check for show again patterns
    for (final pattern in showAgainPatterns) {
      if (lower.contains(pattern)) return true;
    }

    return false;
  }

  /// Extract which recipe index the user is referring to (0-indexed).
  /// Returns null if can't determine, or list of indices for multiple.
  List<int>? _extractRecipeIndices(String message) {
    if (_lastShownRecipes.isEmpty) return null;

    final lower = message.toLowerCase();
    final indices = <int>[];

    // Check for ordinal references
    if (lower.contains('first') || lower.contains('1st') || lower.contains('number 1') || lower.contains('#1')) {
      indices.add(0);
    }
    if (lower.contains('second') || lower.contains('2nd') || lower.contains('number 2') || lower.contains('#2')) {
      indices.add(1);
    }
    if (lower.contains('third') || lower.contains('3rd') || lower.contains('number 3') || lower.contains('#3')) {
      indices.add(2);
    }

    // Check for "all" or "all three"
    if (lower.contains('all') || lower.contains('all three') || lower.contains('all 3')) {
      return List.generate(_lastShownRecipes.length, (i) => i);
    }

    // Check for recipe names
    for (int i = 0; i < _lastShownRecipes.length; i++) {
      final name = (_lastShownRecipes[i]['label'] as String?)?.toLowerCase() ?? '';
      if (name.isNotEmpty) {
        // Check if any significant word from recipe name is in the message
        final words = name.split(' ').where((w) => w.length > 3).toList();
        for (final word in words) {
          if (lower.contains(word) && !indices.contains(i)) {
            indices.add(i);
            break;
          }
        }
      }
    }

    return indices.isEmpty ? null : indices;
  }

  /// Return stored recipe(s) in the exact format they were shown.
  void _returnExactRecipes(List<int> indices) {
    final recipes = indices
        .where((i) => i >= 0 && i < _lastShownRecipes.length)
        .map((i) => _lastShownRecipes[i])
        .toList();

    if (recipes.isEmpty) return;

    state = [
      ...state,
      ChatMessage(
        content: jsonEncode({
          "type": "recipe_results",
          "recipes": recipes,
        }),
        isUser: false,
      ),
    ];
  }

  /// Build a compact recipe context string for the prompt.
  /// Only includes essential info to minimize tokens.
  String _buildRecipeContext() {
    if (_lastShownRecipes.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n--- RECIPES I SHOWED YOU (reference these when answering) ---');
    buffer.writeln('IMPORTANT: When adjusting servings, calculate the multiplier as (desired servings / original servings).');
    buffer.writeln('Example: Recipe serves 4, user wants 2 servings -> multiplier is 2/4 = 0.5 (HALVE ingredients)');
    buffer.writeln('Example: Recipe serves 2, user wants 4 servings -> multiplier is 4/2 = 2.0 (DOUBLE ingredients)');
    buffer.writeln('');

    for (int i = 0; i < _lastShownRecipes.length; i++) {
      final r = _lastShownRecipes[i];
      final servings = r['servings'] ?? r['yield'] ?? 'unknown';
      final cuisine = r['cuisine'] ?? 'General';
      final readyInMinutes = r['readyInMinutes'] ?? 'N/A';
      final imageUrl = r['imageUrl'] ?? '';
      final fiber = r['fiber'];
      final sugar = r['sugar'];
      final sodium = r['sodium'];

      buffer.writeln('Recipe ${i + 1}: ${r['label']}');
      buffer.writeln('  Cuisine: $cuisine');
      buffer.writeln('  SERVINGS: $servings (this is the original serving size - use for calculations!)');
      buffer.writeln('  Ready in: $readyInMinutes minutes');
      buffer.writeln('  Calories: ${r['calories']} | Protein: ${r['protein']}g | Carbs: ${r['carbs']}g | Fat: ${r['fat']}g');
      if (fiber != null) buffer.writeln('  Fiber: ${fiber}g | Sugar: ${sugar}g | Sodium: ${sodium}g');
      buffer.writeln('  Image URL: $imageUrl');
      buffer.writeln('  Ingredients: ${(r['ingredients'] as List?)?.join(', ') ?? 'N/A'}');
      buffer.writeln('  Instructions: ${r['instructions'] ?? 'N/A'}');
      buffer.writeln('');
    }

    buffer.writeln('--- END RECIPES ---');
    buffer.writeln('Use this information to answer questions about the recipes or suggest modifications.');
    buffer.writeln('When adjusting for different serving sizes: ALWAYS check the original SERVINGS first, then multiply/divide ingredients accordingly.');
    return buffer.toString();
  }

  /// Check if user is requesting NEW recipe suggestions (not asking about shown recipes).
  bool _isRecipeRequest(String message) {
    final lower = message.toLowerCase();

    // Keywords indicating user wants recipe suggestions
    const recipeRequestKeywords = [
      'suggest', 'recommend', 'give me', 'show me', 'find me',
      'what should i eat', 'what can i eat', 'what to eat',
      'recipe for', 'recipes for', 'meal idea', 'food idea',
      'what should i cook', 'what can i cook', 'what to cook',
      'i want to eat', 'i\'m hungry', 'im hungry', 'feeling hungry',
      'need a recipe', 'need recipes', 'need a meal', 'need food',
      'looking for recipe', 'looking for meal', 'looking for food',
      'get me a recipe', 'get me some', 'can you suggest',
      'any ideas for', 'ideas for dinner', 'ideas for lunch',
      'ideas for breakfast', 'ideas for snack',
    ];

    // Check for recipe request keywords
    for (final keyword in recipeRequestKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Check for meal type mentions with question context
    const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    const questionWords = ['what', 'any', 'suggest', 'recommend', 'give', 'show', 'find', 'need', 'want'];

    for (final meal in mealTypes) {
      if (lower.contains(meal)) {
        for (final q in questionWords) {
          if (lower.contains(q)) return true;
        }
      }
    }

    return false;
  }

  /// Extract meal type and cuisine from user message using Gemini.
  Future<Map<String, String>> _extractMealAndCuisine(String message) async {
    final extractionPrompt = '''
Extract the meal type and cuisine from this message. Return ONLY a JSON object with two keys.

Message: "$message"

Rules:
- meal_type must be one of: breakfast, lunch, dinner, snack
- If no meal type mentioned, infer from context or time of day, default to "dinner"
- cuisine_type should be the cuisine mentioned, or "any" if not specified
- Common cuisines: italian, mexican, chinese, indian, japanese, thai, american, mediterranean, french, korean, vietnamese, greek, middle eastern

Return ONLY valid JSON like: {"meal_type": "dinner", "cuisine_type": "italian"}
''';

    try {
      final response = await model.generateContent([Content.text(extractionPrompt)]);
      final text = response.text ?? '{}';

      // Extract JSON from response (handle potential markdown code blocks)
      String jsonStr = text;
      if (text.contains('{')) {
        jsonStr = text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1);
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'meal_type': (parsed['meal_type'] as String?) ?? 'dinner',
        'cuisine_type': (parsed['cuisine_type'] as String?) ?? 'any',
      };
    } catch (e) {
      // Default fallback
      return {'meal_type': 'dinner', 'cuisine_type': 'any'};
    }
  }

  //normal chat response
  Future<void> sendMessage(String userMessage) async {
    state = [
      ...state,
      ChatMessage(content: userMessage, isUser: true)
    ]; //add user's message to chat

    ref.read(chatLoadingProvider.notifier).state = true;
    try {
      // First check if user is asking about recipes we already showed
      // (e.g., "give me the first recipe again", "tell me more about that dish")
      // This takes priority over new recipe requests
      final isAboutShownRecipes = _isRecipeRelatedMessage(userMessage);

      // If user wants exact recipe shown again (no modifications), return it directly
      if (isAboutShownRecipes && _wantsExactRecipe(userMessage)) {
        final indices = _extractRecipeIndices(userMessage);
        if (indices != null && indices.isNotEmpty) {
          _returnExactRecipes(indices);
          return; // Exact recipe(s) returned
        }
      }

      // Only fetch new recipes if NOT asking about already-shown recipes
      if (!isAboutShownRecipes && _isRecipeRequest(userMessage)) {
        final params = await _extractMealAndCuisine(userMessage);
        await _fetchRecipes(params['meal_type']!, params['cuisine_type']!);
        return; // Recipe results already added to state by _fetchRecipes
      }

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
          final age = appUser.dob != null
              ? ((DateTime.now().difference(appUser.dob!).inDays) / 365.25)
                  .floor()
              : null;
          profileContext = '''
    User profile:
    - Sex: ${appUser.sex}, Age: ${age ?? 'unknown'}
    - Activity level: ${appUser.activityLevel}
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

      // If the user is asking about recipes we showed, include recipe context
      String recipeContext = '';
      if (isAboutShownRecipes) {
        recipeContext = _buildRecipeContext();
      }

      final fullPrompt = '$contextualPrompt$recipeContext';

      // Use multi-turn chat with conversation history for context
      final history = _buildConversationHistory();
      final chat = model.startChat(history: history);
      final response = await chat.sendMessage(Content.text(fullPrompt));

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
    } finally {
      ref.read(chatLoadingProvider.notifier).state = false;
    }
  }

  //start generate recipe flow!
  //call fetchrecipes
  Future<void> handleMealTypeSelection(
      String mealType, String cuisineType) async {
    await _fetchRecipes(mealType, cuisineType);
  }

  //fetch recipes with mealType, cuisineType
  //fetch with dietary and health restrictions, likes and dislikes
  Future<void> _fetchRecipes(
    String mealType,
    String cuisineType, {
    bool forceNewBatch = false,
  }) async {
    ref.read(chatLoadingProvider.notifier).state = true;
    try {
      //user profile from user signed in
      final user = FirebaseAuth.instance.currentUser;
      print('Current user: $user');

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

      if (!forceNewBatch) {
        _recipeOffsets["$mealType-$cuisineType"] =
            0; // reset when selection changes

        // Show profile summary (informational only)
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
      final todaysFoods = foodLog
          .where((item) =>
              item.consumedAt.year == today.year &&
              item.consumedAt.month == today.month &&
              item.consumedAt.day == today.day)
          .toList();

      final consumedCalories = todaysFoods.fold<int>(
          0, (sum, food) => sum + (food.calories_g * food.mass_g).round());

      double consumedProtein = 0, consumedCarbs = 0, consumedFat = 0;
      for (final item in todaysFoods) {
        consumedProtein += item.protein_g * item.mass_g;
        consumedCarbs += item.carbs_g * item.mass_g;
        consumedFat += item.fat * item.mass_g;
      }

      final consumedMealTypes =
          todaysFoods.map((f) => f.mealType.toLowerCase()).toSet().toList();

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

        final id = recipe['id'];
        final label = recipe['label'] ?? 'Unknown Recipe';
        final calories = (recipe['calories'] as num?)?.round() ?? 0;
        final cuisine = recipe['cuisine'] ?? 'General';
        final url = recipe['imageUrl'] ?? '';

        // Use instructions from Cloud Function (already in Firestore)
        // Fall back to Gemini-generated instructions if not available
        String instructions = recipe['instructions'] ?? '';
        if (instructions.isEmpty) {
          instructions = await _generateInstructionsWithGemini(
              label, ingredients, calories);
        }

        recipeList.add({
          'id': id,
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

      // Save recipes for later reference (recipe editing, questions, etc.)
      _lastShownRecipes = List.from(recipeList);

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
    } finally {
      ref.read(chatLoadingProvider.notifier).state = false;
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

    await _fetchRecipes(mealType, cuisineType, forceNewBatch: true);
  }

  //call firestore provider to add scheduled meals to subcollection
  Future<void> scheduleRecipe(
      String recipeId, List<PlannedFoodInput> plannedInputs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('User not logged in');

    // Add each scheduled meal to the subcollection
    for (final input in plannedInputs) {
      // Normalize date to midnight (remove time component) for consistent comparison
      final normalizedDate =
          DateTime(input.date.year, input.date.month, input.date.day);

      final scheduledMeal = PlannedFood(
        recipeId: recipeId,
        date: normalizedDate,
        mealType: input.mealType,
      );

      // Use the provider notifier to add to Firestore
      await ref
          .read(firestoreScheduledMealsProvider(user.uid).notifier)
          .addScheduledMeal(user.uid, scheduledMeal);
    }
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
