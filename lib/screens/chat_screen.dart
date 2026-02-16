import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_chat_service.dart';
import '../models/planned_food_input.dart';
import '../db/food.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import 'package:table_calendar/table_calendar.dart';
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

  //list of cuisine
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

  Widget _buildChatContent(
    BuildContext context,
    List<ChatMessage> chatMessages,
    bool isLoading,
  ) {
    return Column(
      children: [
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
                  itemCount: chatMessages.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show typing indicator as the last item when loading
                    if (index == chatMessages.length) {
                      return const _TypingIndicator();
                    }

                    final message = chatMessages[index];

                    try {
                      final parsed = jsonDecode(message.content);

                      if (parsed is Map &&
                          parsed['type'] == 'meal_profile_summary') {
                        return MealProfileSummaryBubble(
                          data: Map<String, dynamic>.from(parsed),
                        );
                      }

                      if (parsed is Map && parsed['type'] == 'recipe_results') {
                        final recipes = List<Map<String, dynamic>>.from(
                            parsed['recipes'] ?? const []);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...recipes.map((r) => _RecipeCard(
                                  recipe: r,
                                  onSchedule: (recipeId, plannedInputs) {
                                    ref
                                        .read(
                                            geminiChatServiceProvider.notifier)
                                        .scheduleRecipe(
                                            recipeId, plannedInputs);
                                  },
                                )),
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

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(geminiChatServiceProvider);
    final isLoading = ref.watch(chatLoadingProvider);

    // Auto-scroll when typing indicator appears (not when response arrives)
    ref.listen(chatLoadingProvider, (prev, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final bodyContent = SafeArea(
      child: _buildChatContent(context, chatMessages, isLoading),
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger the animations
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _animations[i],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _animations[i].value),
                      child: child,
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[500],
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class MealProfileSummaryBubble extends StatelessWidget {
  final Map<String, dynamic> data;

  const MealProfileSummaryBubble({
    super.key,
    required this.data,
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
                    "Generating recipes with your profile:",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  // Meal & Cuisine
                  Text("🍽️ Meal: $mealType • Cuisine: $cuisineType"),
                  const SizedBox(height: 4),
                  // Goals
                  Text("🎯 Goal: $dietaryGoal"),
                  Text(
                      "🔥 Daily Calories: ${dailyCalorieGoal > 0 ? '$dailyCalorieGoal Cal' : 'Not set'}"),
                  Text("📊 Macros: P $proteinPct% • C $carbsPct% • F $fatPct%"),
                  const SizedBox(height: 4),
                  // Preferences
                  Text(
                      "✅ Dietary: ${dietary.isEmpty ? 'None' : dietary.join(', ')}"),
                  Text(
                      "⚕️ Health: ${health.isEmpty ? 'None' : health.join(', ')}"),
                  Text(
                      "👍 Likes: ${likes.isEmpty ? 'None' : likes.join(', ')}"),
                  Text(
                      "👎 Dislikes: ${dislikes.isEmpty ? 'None' : dislikes.join(', ')}"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final Function(String recipeId, List<PlannedFoodInput>) onSchedule;

  const _RecipeCard({
    required this.recipe,
    required this.onSchedule,
    super.key,
  });

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  Set<DateTime> _selectedDates = {}; // store highlighted dates

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final recipeId = recipe['id'].toString();
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

    String getProxiedImageUrl(String url) {
      if (url.isEmpty) return '';
      final encodedUrl = Uri.encodeComponent(url);
      return 'https://us-central1-ai-nutrition-assistant-e2346.cloudfunctions.net/proxyImage?url=$encodedUrl';
    }

    final proxiedImageUrl = getProxiedImageUrl(imageUrl);

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
          if (proxiedImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                proxiedImageUrl,
                width: 280,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Silently hide image if it fails to load
                  return const SizedBox.shrink();
                },
              ),
            ),
          const SizedBox(height: 12),
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (cuisine.toLowerCase() != 'world') Text('Cuisine: $cuisine'),
          Text('Calories: $calories Cal'),
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
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!mounted) return;

                final Map<DateTime, String> plannedDates = {};

                await showDialog(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setDialogState) => AlertDialog(
                      title: const Text("Select Dates"),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 400,
                        child: TableCalendar(
                          firstDay: DateTime.now(),
                          lastDay: DateTime.now().add(const Duration(days: 30)),
                          focusedDay: DateTime.now(),
                          calendarFormat: CalendarFormat.month,
                          selectedDayPredicate: (day) =>
                              _selectedDates.contains(day),
                          onDaySelected: (day, focusedDay) async {
                            if (!mounted) return;

                            if (!_selectedDates.contains(day)) {
                              // Ask for meal type
                              final mealType = await showDialog<String>(
                                context: ctx,
                                builder: (ctx2) => SimpleDialog(
                                  title: Text(
                                      "Select meal type for ${day.month}/${day.day}"),
                                  children:
                                      ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                                          .map((m) => SimpleDialogOption(
                                                child: Text(m),
                                                onPressed: () =>
                                                    Navigator.pop(ctx2, m),
                                              ))
                                          .toList(),
                                ),
                              );

                              if (mealType != null) {
                                setDialogState(() {
                                  _selectedDates.add(day);
                                  plannedDates[day] = mealType;
                                });
                              }
                            } else {
                              setDialogState(() {
                                _selectedDates.remove(day);
                                plannedDates.remove(day);
                              });
                            }
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Done"),
                        ),
                      ],
                    ),
                  ),
                );

                if (plannedDates.isEmpty) return;

                final plannedInputs = plannedDates.entries
                    .map(
                        (e) => PlannedFoodInput(date: e.key, mealType: e.value))
                    .toList();

                widget.onSchedule(recipeId, plannedInputs);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '$label scheduled for ${plannedInputs.length} date(s)'),
                  ),
                );
              },
              icon: const Icon(Icons.schedule),
              label: const Text("Schedule"),
            ),
          ),
        ],
      ),
    );
  }
}
