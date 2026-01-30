import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_chat_service.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/food.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final bool isInPageView;

  const ChatScreen({super.key, this.isInPageView = false});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showRecipePicker = false;
  bool _showCuisinePicker = false;
  String? _selectedMealType;
  String? _selectedCuisineType;

  final List<String> _cuisineTypes = [
    'No Preference',
    'African',
    'Asian',
    'American',
    'British',
    'Cajun',
    'Caribbean',
    'Chinese',
    'Eastern European',
    'European',
    'French',
    'German',
    'Greek',
    'Indian',
    'Irish',
    'Italian',
    'Japanese',
    'Jewish',
    'Korean',
    'Latin American',
    'Mediterranean',
    'Mexican',
    'Middle Eastern',
    'Nordic',
    'Southern',
    'Spanish',
    'Thai',
    'Vietnamese',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    ref.read(geminiChatServiceProvider.notifier).sendMessage(message);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // user clicks "generate recipes"
  void _promptRecipeType() {
    final notifier = ref.read(geminiChatServiceProvider.notifier);

    notifier.addLocalBotMessage("What kind of meal would you like?");

    setState(() {
      _showRecipePicker = true;
      _showCuisinePicker = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // meal type selected, show more
  void _onRecipeTypeSelected(String type) {
    final notifier = ref.read(geminiChatServiceProvider.notifier);

    notifier.addLocalUserMessage(type);

    notifier.addLocalBotMessage("What cuisine type would you like?");

    setState(() {
      _selectedMealType = type;
      _showRecipePicker = false;
      _showCuisinePicker = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // cuisine type selected, show more
  void _onCuisineSelected(String cuisine) {
    final notifier = ref.read(geminiChatServiceProvider.notifier);

    notifier.addLocalUserMessage(cuisine);

    setState(() {
      _selectedCuisineType = cuisine;
      _showCuisinePicker = false;
    });

    final meal = _selectedMealType ?? 'Meal';
    notifier.handleMealTypeSelection(meal, cuisine);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _addRecipeToLog(Map<String, dynamic> recipe,
      {required String mealType}) async {
    final authUser = ref.read(authServiceProvider);
    final userId = authUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save meals.')),
        );
      }
      return;
    }

    final name = (recipe['label'] ?? 'Meal').toString();
    final caloriesTotal = (recipe['calories'] ?? 0).toDouble();

    // Store as a single serving entry; macros default to 0 if unavailable.
    final item = FoodItem(
      id: 'recipe-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      mass_g: 1,
      calories_g: caloriesTotal,
      protein_g: (recipe['protein'] ?? 0).toDouble(),
      carbs_g: (recipe['carbs'] ?? 0).toDouble(),
      fat: (recipe['fat'] ?? 0).toDouble(),
      mealType: mealType.isNotEmpty ? mealType : 'meal',
      consumedAt: DateTime.now(),
    );

    await ref
        .read(firestoreFoodLogProvider(userId).notifier)
        .addFood(userId, item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "$name" to today\'s log.')),
      );
    }
  }

  // load more recipes based off user's discretion
  void _loadMoreRecipes(String mealType, String cuisineType) {
    final notifier = ref.read(geminiChatServiceProvider.notifier);

    notifier.requestMoreRecipes(mealType: mealType, cuisineType: cuisineType);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // confirm user meal profile with backend logic
  void _confirmMealProfile(bool confirmed) {
    final notifier = ref.read(geminiChatServiceProvider.notifier);

    notifier.confirmMealProfile(confirmed);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Widget _choiceBar() {
    List<String> options = [];
    void Function(String)? onTap;

    if (_showRecipePicker) {
      options = const ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
      onTap = _onRecipeTypeSelected;
    } else if (_showCuisinePicker) {
      options = _cuisineTypes;
      onTap = _onCuisineSelected;
    } else {
      return const SizedBox.shrink();
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green[600],
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.grey[100],
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: options.map((text) {
            return ElevatedButton(
              style: buttonStyle,
              onPressed: () => onTap!(text),
              child: Text(text, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(geminiChatServiceProvider);

    final bodyContent = SafeArea(
      child: _buildChatContent(context, chatMessages),
    );

    if (widget.isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE2),
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexChat,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  Widget _buildChatContent(
      BuildContext context, List<ChatMessage> chatMessages) {
    return Column(
      children: [
        // Clear chat button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Chat'),
              onPressed: () {
                ref.read(geminiChatServiceProvider.notifier).clearChat();
                setState(() {
                  _showRecipePicker = false;
                  _showCuisinePicker = false;
                  _selectedMealType = null;
                });
              },
            ),
          ),
        ),
        Expanded(
          child: chatMessages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Ask me anything about nutrition!',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try: "What should I eat for dinner?"',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = chatMessages[index];

                    try {
                      final parsed = jsonDecode(message.content);

                      if (parsed is Map &&
                          parsed['type'] == 'meal_profile_summary') {
                        return MealProfileSummaryBubble(
                          data: Map<String, dynamic>.from(parsed),
                          onYes: () => _confirmMealProfile(true),
                          onNo: () => _confirmMealProfile(false),
                        );
                      }

                      if (parsed is Map && parsed['type'] == 'recipe_results') {
                        final recipes = List<Map<String, dynamic>>.from(
                            parsed['recipes'] ?? const []);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...recipes.map(
                              (r) => _RecipeCard(
                                recipe: r,
                                mealType: _selectedMealType ?? 'Meal',
                                onAdd: () => _addRecipeToLog(
                                  r,
                                  mealType: _selectedMealType ?? 'meal',
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final meal = _selectedMealType ?? 'Dinner';
                                  final cuisine =
                                      _selectedCuisineType ?? 'None';
                                  _loadMoreRecipes(meal, cuisine);
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text("More recipes"),
                              ),
                            ),
                          ],
                        );
                      }
                    } catch (_) {}

                    return _ChatBubble(message: message);
                  },
                ),
        ),

        // ✅ Only one button area, centered, same color
        _choiceBar(),

        // Input bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _promptRecipeType,
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Generate Recipes'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText:
                            'Ask about nutrition, calories, meal planning...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: Colors.green[600],
                    mini: true,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.green[600],
              radius: 16,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.green[600] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.formattedTime,
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue[600],
              radius: 16,
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class MealProfileSummaryBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const MealProfileSummaryBubble({
    super.key,
    required this.data,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final dietary = List<String>.from(data['dietary'] ?? const []);
    final health = List<String>.from(data['health'] ?? const []);
    final likes = List<String>.from(data['likes'] ?? const []);
    final dislikes = List<String>.from(data['dislikes'] ?? const []);
    final mealType = (data['mealType'] ?? '').toString();
    final cuisineType = (data['cuisineType'] ?? '').toString();
    final dietaryGoal = (data['dietaryGoal'] ?? '').toString();
    final dailyCalorieGoal = data['dailyCalorieGoal'] as int? ?? 0;
    final macroGoals = data['macroGoals'] as Map<String, dynamic>? ?? {};
    
    // Format macro goals as percentages
    final proteinPct = (macroGoals['protein'] as num?)?.round() ?? 0;
    final carbsPct = (macroGoals['carbs'] as num?)?.round() ?? 0;
    final fatPct = (macroGoals['fat'] as num?)?.round() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.green[600],
            radius: 16,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Is this information correct?",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  // Meal & Cuisine
                  Text("🍽️ Meal: $mealType • Cuisine: $cuisineType"),
                  const SizedBox(height: 4),
                  // Goals
                  Text("🎯 Goal: $dietaryGoal"),
                  Text("🔥 Daily Calories: ${dailyCalorieGoal > 0 ? '$dailyCalorieGoal kcal' : 'Not set'}"),
                  Text("📊 Macros: P $proteinPct% • C $carbsPct% • F $fatPct%"),
                  const SizedBox(height: 4),
                  // Preferences
                  Text("✅ Dietary: ${dietary.isEmpty ? 'None' : dietary.join(', ')}"),
                  Text("⚕️ Health: ${health.isEmpty ? 'None' : health.join(', ')}"),
                  Text("👍 Likes: ${likes.isEmpty ? 'None' : likes.join(', ')}"),
                  Text("👎 Dislikes: ${dislikes.isEmpty ? 'None' : dislikes.join(', ')}"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onYes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Yes"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onNo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("No"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final String mealType;
  final VoidCallback onAdd;

  const _RecipeCard(
      {required this.recipe, required this.mealType, required this.onAdd});

  // Capitalize first letter of each word
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final label = recipe['label'] ?? 'Recipe';
    final cuisine = _capitalize((recipe['cuisine'] ?? 'General').toString());
    final calories = recipe['calories'] ?? 0;
    final protein = recipe['protein'] ?? 0;
    final carbs = recipe['carbs'] ?? 0;
    final fat = recipe['fat'] ?? 0;
    final servings = recipe['servings'];
    final readyInMinutes = recipe['readyInMinutes'];
    final ingredients = List<String>.from(recipe['ingredients'] ?? const []);
    final instructions = recipe['instructions'] ?? '';
    final imageUrl = recipe['imageUrl'] ?? '';
    final url = recipe['sourceUrl'] ?? '';

    // Convert Spoonacular URL to use CORS proxy for web
    String getProxiedImageUrl(String url) {
      if (url.isEmpty) return '';
      // Use Cloud Function proxy to avoid CORS issues
      final encodedUrl = Uri.encodeComponent(url);
      return 'https://us-central1-ai-nutrition-assistant-e2346.cloudfunctions.net/proxyImage?url=$encodedUrl';
    }

    final proxiedImageUrl = getProxiedImageUrl(imageUrl.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe image at the top
          if (proxiedImageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 280,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(
                  proxiedImageUrl,
                  width: 280,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // CORS issue on web - show message
                    return Container(
                      width: 280,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Image from Spoonacular',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (cuisine.toLowerCase() != 'world') Text('Cuisine: $cuisine'),
          Text('Calories: $calories kcal'),
          Text('P: ${protein}g  |  C: ${carbs}g  |  F: ${fat}g',
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          if (readyInMinutes != null || servings != null)
            Text(
              [
                if (readyInMinutes != null) 'Ready in $readyInMinutes min',
                if (servings != null) 'Serves: $servings',
              ].join('  |  '),
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          const SizedBox(height: 8),
          const Text('Ingredients',
              style: TextStyle(fontWeight: FontWeight.w600)),
          ...ingredients.map((i) => Text('• $i')),
          const SizedBox(height: 8),
          const Text('Instructions',
              style: TextStyle(fontWeight: FontWeight.w600)),
          Text(instructions),
          if (url.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              url.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.playlist_add),
              label: const Text("Add to today's log"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
