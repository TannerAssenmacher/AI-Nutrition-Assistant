import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/providers/user_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/food_providers.dart';
import '../services/nutrition_service.dart';
import '../db/firestore_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

part 'gemini_chat_service.g.dart';

enum ChatStage { idle, awaitingMealType, awaitingCuisine } // like a light switch, it will switch on if awaiting 

// Create chatbot service
@riverpod
class GeminiChatService extends _$GeminiChatService {
  late final GenerativeModel model;

  ChatStage stage = ChatStage.idle;

  String? _pendingMealType;
  String? _pendingCuisineType;


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

  //call fetchrecipes
  Future<void> handleMealTypeSelection(String mealType, String cuisineType) async {
   
    state = [
      ...state,
      ChatMessage(
        content: "Selected: $mealType${cuisineType != 'None' ? ' ($cuisineType)' : ''}",
        isUser: true,
        timestamp: DateTime.now(),
      ),
    ];

    //call edamam api with user input
    await _fetchRecipes(mealType, cuisineType);
  }

  //confirmation on user profile
  Future<void> confirmMealProfile(bool confirmed) async {
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
        content: "Perfect! Generating your personalized recipes now...",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];

      if (_pendingMealType != null && _pendingCuisineType != null) {
        await _fetchRecipes(_pendingMealType!, _pendingCuisineType!, fromConfirmation: true);
        
        //global variables no longer needed
        _pendingMealType = null;
        _pendingCuisineType = null;
      }
  }


  //fetch recipes with mealType, cuisineType 
  //fetch with dietary and health restrictions, likes and dislikes
  Future<void> _fetchRecipes(String mealType, String cuisineType, {
  bool fromConfirmation = false,   bool forceNewBatch = false,
}) async {
    try {

      final user = FirebaseAuth.instance.currentUser;
      AppUser? appUser; //make null

      if (user != null) {
        print('Current user ID: ${user.uid}');
      
        appUser = await FirestoreHelper.getUser(user.uid);

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
      }
      else{ //no authentication found!
        return;
      }

      final mealProfile = appUser.mealProfile;
      final preferences = mealProfile.preferences;

      //debugging
      print('MealProfile data:');
      print('Dietary: ${mealProfile.dietaryHabits}');
      print('Health: ${mealProfile.healthRestrictions}');
     

      //default to empty lists if mealprofile == null
      final dietaryHabits = (mealProfile.dietaryHabits
              .where((h) => h.trim().isNotEmpty && h.toLowerCase() != 'none')
              .toList())
          .toList();;

      final healthRestrictions = (mealProfile.healthRestrictions
              .where((r) => r.trim().isNotEmpty && r.toLowerCase() != 'none')
              .toList())
          .toList();;

      final dislikes = preferences.dislikes
              .where((d) => d.trim().isNotEmpty && d.toLowerCase() != 'none')
              .toList();


      if (!fromConfirmation) {

        //need to store them since you are leaving the function
      _pendingCuisineType = cuisineType;
      _pendingMealType = mealType;

        final summary = [
          'Dietary habits: ${dietaryHabits.isNotEmpty ? dietaryHabits.join(", ") : "none"}',
          'Health restrictions: ${healthRestrictions.isNotEmpty ? healthRestrictions.join(", ") : "none"}',
          'Excluded ingredients: ${dislikes.isNotEmpty ? dislikes.join(", ") : "none"}',
        ].join('\n');

        // ask for health and diet confirmation
        state = [
          ...state,
          ChatMessage(
            content: "Here’s what I have for you:\n$summary\n\nIs this correct?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ];

        return;
      }

      final appId = dotenv.env['EDAMAM_API_ID'];
      final appKey = dotenv.env['EDAMAM_API_KEY'];

      print('app_id: $appId');
      print('app_key: $appKey');
 

    
     /* String dishType = 'Main course';
      switch (mealType.toLowerCase()) {
        case 'breakfast':
          dishType = 'Breakfast';
          break;
        case 'lunch':
        case 'dinner':
          dishType = 'Main course';
          break;
        case 'snack':
          dishType = 'Snack';
          break;
      }*/

      //start edamam api
      final params = <String>[
        'type=public',
        'mealType=$mealType',
        'app_id=$appId',
        'app_key=$appKey',
      ];

  
      //adding to api call!

      //add cuisine if !none && !empty
      if (cuisineType.isNotEmpty && cuisineType.toLowerCase() != 'none') {
        params.add('cuisineType=${Uri.encodeComponent(cuisineType)}');
      }

      if (dietaryHabits.isNotEmpty) {
        for (final diet in dietaryHabits) {
          params.add('diet=$diet');
        }  
      }      
    
      if (healthRestrictions.isNotEmpty) {
        for (final health in healthRestrictions) {
          params.add('health=$health');
        }
      }

      if (dislikes.isNotEmpty) {
        for (final food in dislikes) {
          params.add('excluded=$food');
        }
      }

      //random offset so each call gets a new slice of recipes
      int from = DateTime.now().millisecondsSinceEpoch % 40; // 0–39 window
      if (!forceNewBatch) from = from % 30; // keep predictable if same session
      final to = from + 3;
      params.add('from=$from');
      params.add('to=$to');


      //build uri
      final uri = Uri.parse(
        'https://api.edamam.com/api/recipes/v2?${params.join('&')}',
      );
    
      final response = await http.get(uri);

      //debugging
      print('${response.statusCode}');
      print(response.body.substring(0, response.body.length > 1500 ? 1500 : response.body.length));



      final json = jsonDecode(response.body);
      final hits = (json['hits'] as List?) ?? []; //recipes that are returned from the call

      if (hits.isEmpty) {
        state = [
          ...state,
          ChatMessage(
            content:
                "I couldn’t find any recipes matching your meal profile. Try a different cuisine or meal type?",
            isUser: false,
          ),
        ];
        return;
      }


      // debugging
      //need to account for chatbot communication with api to demonstrate better

      //showing top 3 recipes
      final topRecipes = hits.take(3).map((hit) {
      final recipe = hit['recipe'];
      final label = recipe['label'] ?? 'Unknown Recipe';
      final calories = (recipe['calories'] as num?)?.round() ?? 0;
      final ingredients = (recipe['ingredientLines'] as List?)
              ?.map((i) => "• $i")
              .join('\n') ??
          'Not available';
      final url = recipe['url'] ?? 'No link available';
      final cuisine = (recipe['cuisineType'] != null && recipe['cuisineType'].isNotEmpty)
          ? recipe['cuisineType'][0].toString().toUpperCase()
          : 'GENERAL';

      return '''
    🍽️  $label  (${cuisine})
    🔥  Overall Calories: ${calories > 0 ? "$calories kcal" : "N/A"}

    🥕  Ingredients:
    $ingredients

    👩‍🍳  Cooking Instructions:
    View full recipe → $url
    ''';
    }).join(
      "\n────────────────────────────────────\n\n", // nice clean divider
    );


    // main bot response
    final botResponse = '''
    Here are a few recipes I found that fit your preferences 👇  

    $topRecipes

    What do you think?  
    I can show you more recipes, adjust by dietary preference, or even plan a full meal for your day! 🍽️
    ''';

    state = [
      ...state,
      ChatMessage(
        content: botResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];

      /*//choose first 3 recipes for now! - but u SHOULD CALL THE HEURISTIC ALGORITHM!
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
      ];*/
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

  //more recipes
  Future<void> fetchMoreRecipes() async {
  if (_pendingMealType == null || _pendingCuisineType == null) {
    state = [
      ...state,
      ChatMessage(
        content: "Please select a meal and cuisine first before fetching more recipes.",
        isUser: false,
      ),
    ];
    return;
  }

  state = [
    ...state,
    ChatMessage(
      content: "Fetching more recipes for you... 🍽️",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  await _fetchRecipes(_pendingMealType!, _pendingCuisineType!, forceNewBatch: true);
}



    // Add this: have the bot speak without hitting the API
    void promptForRecipeType() {
    state = [
      ...state,
      ChatMessage(
        content: "What kind of meal would you like me to find recipes for?",
        isUser: false,
      ),
    ];
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
