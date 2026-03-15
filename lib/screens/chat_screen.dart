import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/gemini_chat_service.dart';
import '../services/food_search_service.dart';
import '../models/planned_food_input.dart';
import '../db/food.dart';
import '../db/favorite_meal.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../theme/app_colors.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/add_to_favorites_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final bool isInPageView;
  const ChatScreen({super.key, this.isInPageView = false});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  //color palette
  final Color bgColor = AppColors.homeBackground;
  final Color brandColor = AppColors.brand;
  final Color neumorphicShadow = AppColors.neumorphicShadow;

  //data
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    HapticFeedback.lightImpact();
    _messageController.clear();
    ref.read(geminiChatServiceProvider.notifier).sendMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _promptRecipeType() {
    HapticFeedback.mediumImpact();
    ref
        .read(geminiChatServiceProvider.notifier)
        .addLocalBotMessage("What kind of meal would you like?");
    setState(() {
      _showRecipePicker = true;
      _showCuisinePicker = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onRecipeTypeSelected(String type) {
    HapticFeedback.selectionClick();
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

  void _onCuisineSelected(String cuisine) {
    HapticFeedback.selectionClick();
    final notifier = ref.read(geminiChatServiceProvider.notifier);
    notifier.addLocalUserMessage(cuisine);
    setState(() {
      _selectedCuisineType = cuisine;
      _showCuisinePicker = false;
    });
    notifier.handleMealTypeSelection(_selectedMealType ?? 'Meal', cuisine);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  FoodSearchResult _recipeAsFavoriteResult(Map<String, dynamic> recipe) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    final recipeIdRaw = (recipe['id'] ?? '').toString().trim();
    final recipeLabel = (recipe['label'] ?? 'Recipe').toString().trim();
    final recipeImageUrl = (recipe['imageUrl'] ?? '').toString().trim();

    final massG = asDouble(recipe['mass_g']);
    final servingGrams = massG > 0 ? massG : 100.0;

    final caloriesTotal = asDouble(recipe['calories']);
    final proteinTotal = asDouble(recipe['protein']);
    final carbsTotal = asDouble(recipe['carbs']);
    final fatTotal = asDouble(recipe['fat']);

    final caloriesPerGram = caloriesTotal / servingGrams;
    final proteinPerGram = proteinTotal / servingGrams;
    final carbsPerGram = carbsTotal / servingGrams;
    final fatPerGram = fatTotal / servingGrams;

    final normalizedId = recipeIdRaw.isNotEmpty
        ? 'recipe_$recipeIdRaw'
        : 'recipe_${recipeLabel.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    return FoodSearchResult(
      id: normalizedId,
      name: recipeLabel.isEmpty ? 'Recipe' : recipeLabel,
      caloriesPerGram: caloriesPerGram,
      proteinPerGram: proteinPerGram,
      carbsPerGram: carbsPerGram,
      fatPerGram: fatPerGram,
      servingGrams: servingGrams,
      source: 'fatsecret',
      imageUrl: recipeImageUrl.isEmpty ? null : recipeImageUrl,
      servingOptions: [
        FoodServingOption(
          id: 'default',
          description: 'Recipe serving',
          grams: servingGrams,
          caloriesPerGram: caloriesPerGram,
          proteinPerGram: proteinPerGram,
          carbsPerGram: carbsPerGram,
          fatPerGram: fatPerGram,
          isDefault: true,
        ),
      ],
    );
  }

  Future<void> _addRecipeToFavorites(Map<String, dynamic> recipe) async {
    final userId = ref.read(authServiceProvider)?.uid;
    if (userId == null) {
      if (mounted) {
        AppSnackBar.error(context, 'Please sign in to add favorites.');
      }
      return;
    }

    final result = _recipeAsFavoriteResult(recipe);

    final addedMealName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      showDragHandle: true,
      builder: (context) {
        return AddToFavoritesSheet(result: result, userId: userId);
      },
    );

    if (!mounted || addedMealName == null) return;
    AppSnackBar.success(context, 'Saved to favorites: $addedMealName.');
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {},
        onHorizontalDragUpdate: (_) {},
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: options
                .map(
                  (text) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.surface,
                            offset: const Offset(-3, -3),
                            blurRadius: 8,
                          ),
                          BoxShadow(
                            color: neumorphicShadow,
                            offset: const Offset(3, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: AppColors.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => onTap!(text),
                        child: Text(
                          text,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(geminiChatServiceProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final favoriteMealsAsync = userId != null
        ? ref.watch(firestoreFavoriteMealsProvider(userId))
        : const AsyncValue.data(<FavoriteMeal>[]);
    final favoriteSourceIds = favoriteMealsAsync.maybeWhen(
      data: (meals) => meals
          .expand((meal) => meal.items)
          .map((item) => (item.sourceId ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet(),
      orElse: () => <String>{},
    );
    final favoriteNames = favoriteMealsAsync.maybeWhen(
      data: (meals) => meals
          .expand((meal) => meal.items)
          .map((item) => item.name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet(),
      orElse: () => <String>{},
    );
    final mediaQuery = MediaQuery.of(context);
    final navVisualBottomSpacing = mediaQuery.size.height * 0.008;
    final navBottomInset =
        mediaQuery.viewPadding.bottom + navVisualBottomSpacing;
    final navBarHeight = mediaQuery.size.height * 0.07;
    final navTotalHeight = widget.isInPageView
        ? 0.0
        : navBottomInset + navBarHeight;

    ref.listen<List<ChatMessage>>(geminiChatServiceProvider, (prev, next) {
      final prevLength = prev?.length ?? 0;
      if (next.length > prevLength) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    ref.listen(chatLoadingProvider, (prev, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Listener(
      onPointerMove: (PointerMoveEvent event) {
        if (event.delta.dx.abs() > 10 &&
            event.delta.dx.abs() > event.delta.dy.abs()) {
          if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        }
      },

      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: bgColor,
        extendBody: !widget.isInPageView,
        body: SafeArea(
          bottom: widget.isInPageView,
          child: Column(
            children: [
              // Simple Top Bar
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Text(
                  'NutriCoach',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: brandColor,
                  ),
                ),
              ),

              // Chat Area
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: chatMessages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: chatMessages.length + (isLoading ? 1 : 0),
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            if (index == chatMessages.length) {
                              return const _TypingIndicator();
                            }
                            final message = chatMessages[index];
                            return _buildMessageNode(
                              message,
                              favoriteSourceIds: favoriteSourceIds,
                              favoriteNames: favoriteNames,
                            );
                          },
                        ),
                ),
              ),

              // Choice bar for meal/cuisine selection
              _choiceBar(),

              // Bottom Section: Generate Recipes button + Input
              _buildInputBar(extraBottomPadding: navTotalHeight),
            ],
          ),
        ),
        bottomNavigationBar: !widget.isInPageView
            ? NavBar(
                currentIndex: navIndexChat,
                onTap: (index) => handleNavTap(context, index),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: brandColor.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ask me anything about nutrition!',
            style: TextStyle(fontSize: 18, color: AppColors.statusNone),
          ),
          const SizedBox(height: 8),
          Text(
            'Try: "What should I eat for dinner?"',
            style: TextStyle(fontSize: 14, color: AppColors.statusNone),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeResults(
    List<Map<String, dynamic>> recipes, {
    required Set<String> favoriteSourceIds,
    required Set<String> favoriteNames,
  }) {
    return Column(
      children: [
        ...recipes.map((r) {
          final recipeId = (r['id'] ?? '').toString().trim();
          final recipeName = (r['label'] ?? '').toString().trim().toLowerCase();
          final recipeSourceId = recipeId.isNotEmpty ? 'recipe_$recipeId' : '';
          final isFavorited =
              (recipeSourceId.isNotEmpty &&
                  favoriteSourceIds.contains(recipeSourceId)) ||
              favoriteNames.contains(recipeName);

          return _RecipeCard(
            recipe: r,
            brandColor: brandColor,
            isFavorited: isFavorited,
            onFavorite: () => _addRecipeToFavorites(r),
            onSchedule: (id, inputs, ingredientLines) => ref
                .read(geminiChatServiceProvider.notifier)
                .scheduleRecipe(id, inputs, ingredientLines),
          );
        }),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => ref
                .read(geminiChatServiceProvider.notifier)
                .requestMoreRecipes(
                  mealType: _selectedMealType ?? 'Dinner',
                  cuisineType: _selectedCuisineType ?? 'None',
                ),
            icon: const Icon(Icons.refresh),
            label: const Text("More recipes"),
            style: OutlinedButton.styleFrom(
              foregroundColor: brandColor,
              side: BorderSide(color: brandColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageNode(
    ChatMessage message, {
    required Set<String> favoriteSourceIds,
    required Set<String> favoriteNames,
  }) {
    // Try parsing the entire message as JSON first
    try {
      final parsed = jsonDecode(message.content);
      if (parsed is Map && parsed['type'] == 'meal_profile_summary') {
        return MealProfileSummaryBubble(
          data: Map<String, dynamic>.from(parsed),
        );
      }
      if (parsed is Map && parsed['type'] == 'recipe_results') {
        final recipes = List<Map<String, dynamic>>.from(
          parsed['recipes'] ?? const [],
        );
        return _buildRecipeResults(
          recipes,
          favoriteSourceIds: favoriteSourceIds,
          favoriteNames: favoriteNames,
        );
      }
    } catch (_) {}

    // Check if the message contains embedded recipe JSON within surrounding text
    final content = message.content;
    final jsonStart = content.indexOf('{"type":"recipe_results"');
    if (!message.isUser && jsonStart != -1) {
      // Find the matching closing brace for the JSON object
      int depth = 0;
      int? jsonEnd;
      for (int i = jsonStart; i < content.length; i++) {
        if (content[i] == '{') depth++;
        if (content[i] == '}') depth--;
        if (depth == 0) {
          jsonEnd = i + 1;
          break;
        }
      }

      if (jsonEnd != null) {
        try {
          final jsonStr = content.substring(jsonStart, jsonEnd);
          final parsed = jsonDecode(jsonStr);
          if (parsed is Map && parsed['type'] == 'recipe_results') {
            final recipes = List<Map<String, dynamic>>.from(
              parsed['recipes'] ?? const [],
            );
            final textBefore = content.substring(0, jsonStart).trim();
            final textAfter = content.substring(jsonEnd).trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (textBefore.isNotEmpty)
                  _ChatBubble(
                    message: ChatMessage(content: textBefore, isUser: false),
                    brandColor: brandColor,
                  ),
                _buildRecipeResults(
                  recipes,
                  favoriteSourceIds: favoriteSourceIds,
                  favoriteNames: favoriteNames,
                ),
                if (textAfter.isNotEmpty)
                  _ChatBubble(
                    message: ChatMessage(content: textAfter, isUser: false),
                    brandColor: brandColor,
                  ),
              ],
            );
          }
        } catch (_) {}
      }
    }

    return _ChatBubble(message: message, brandColor: brandColor);
  }

  Widget _buildInputBar({double extraBottomPadding = 0}) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(20, 16, 20, extraBottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Generate Recipes Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderLight, width: 1),
                ),
              ),
              child: OutlinedButton.icon(
                onPressed: _promptRecipeType,
                icon: const Icon(Icons.restaurant, size: 18),
                label: const Text('Generate Recipes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  side: BorderSide(color: brandColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask about nutrition...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 16),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: InputBorder.none,
                  suffixIcon: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: brandColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: AppColors.surface,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Color brandColor;
  const _ChatBubble({required this.message, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.surface,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      'NutriCoach',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? brandColor : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isUser ? AppColors.surface : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.statusNone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MealProfileSummaryBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  const MealProfileSummaryBubble({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final Color brandColor = AppColors.brand;
    final macroGoals = Map<String, dynamic>.from(data['macroGoals'] ?? {});
    final protein = (macroGoals['protein'] ?? 0).round();
    final carbs = (macroGoals['carbs'] ?? 0).round();
    final fat = (macroGoals['fat'] ?? 0).round();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: brandColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: brandColor.withValues(alpha: 0.05), blurRadius: 15),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Generating Recipes with your Profile",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Divider(height: 24),

          _row(Icons.restaurant_menu, "Meal", data['mealType']),
          _row(Icons.flag_outlined, "Cuisine", data['cuisineType']),

          //Goals Section
          const SizedBox(height: 12),
          const Text("Goals", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _row(Icons.track_changes, "Dietary Goal", data['dietaryGoal']),
          _row(
            Icons.local_fire_department_outlined,
            "Daily Calories",
            (data['dailyCalorieGoal'] ?? 0) > 0
                ? "${data['dailyCalorieGoal']} Cal"
                : "Not set",
          ),
          _row(
            Icons.pie_chart_outline,
            "Macros",
            "P $protein% • "
                "C $carbs% • "
                "F $fat%",
          ),
          const SizedBox(height: 12),
          //Preferences Section
          const Text(
            "Preferences",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _row(
            Icons.check_circle_outline,
            "Dietary",
            (data['dietary'] as List?)?.isEmpty ?? true
                ? "None"
                : (data['dietary'] as List).join(', '),
          ),
          _row(
            Icons.health_and_safety_outlined,
            "Health",
            (data['health'] as List?)?.isEmpty ?? true
                ? "None"
                : (data['health'] as List).join(', '),
          ),
          _row(
            Icons.thumb_up_alt_outlined,
            "Likes",
            (data['likes'] as List?)?.isEmpty ?? true
                ? "None"
                : (data['likes'] as List).join(', '),
          ),
          _row(
            Icons.thumb_down_alt_outlined,
            "Dislikes",
            (data['dislikes'] as List?)?.isEmpty ?? true
                ? "None"
                : (data['dislikes'] as List).join(', '),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, dynamic val) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.statusNone),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text("$val", style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}

class _RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final Color brandColor;
  final bool isFavorited;
  final VoidCallback onFavorite;
  final Function(String, List<PlannedFoodInput>, List<String>) onSchedule;

  const _RecipeCard({
    required this.recipe,
    required this.brandColor,
    required this.isFavorited,
    required this.onFavorite,
    required this.onSchedule,
  });

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  String getProxiedImageUrl(String url) {
    if (url.isEmpty) return '';
    final encodedUrl = Uri.encodeComponent(url);
    return 'https://us-central1-ai-nutrition-assistant-e2346.cloudfunctions.net/proxyImage?url=$encodedUrl';
  }

  Future<void> _openScheduleDialog(
    Map<String, dynamic> recipe,
    List<String> ingredients,
  ) async {
    final plannedDates = await showDialog<Map<DateTime, String>>(
      context: context,
      builder: (ctx) => const _RecipeScheduleCalendarPicker(),
    );

    if (plannedDates == null || plannedDates.isEmpty) return;

    final inputs = plannedDates.entries
        .map((e) => PlannedFoodInput(date: e.key, mealType: e.value))
        .toList();

    widget.onSchedule(recipe['id'].toString(), inputs, ingredients);

    if (mounted) {
      AppSnackBar.success(
        context,
        '${recipe['label']} scheduled for ${inputs.length} date(s)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final ingredients = List<String>.from(r['ingredients'] ?? const []);
    final readyInMinutes = r['readyInMinutes'];
    final servings = r['servings'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                leading: r['imageUrl'] != null && r['imageUrl'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          getProxiedImageUrl(r['imageUrl']),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: widget.brandColor,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.restaurant, color: widget.brandColor),
                      ),
                title: Text(
                  r['label'] ?? 'Recipe',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      "${r['calories']} Cal \u00b7 P:${r['protein']}g C:${r['carbs']}g F:${r['fat']}g",
                      style: TextStyle(
                        color: widget.brandColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openScheduleDialog(r, ingredients),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Add Meal',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.brandColor,
                          side: BorderSide(color: widget.brandColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          minimumSize: const Size(double.infinity, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (readyInMinutes != null || servings != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            [
                              if (readyInMinutes != null)
                                'Ready in $readyInMinutes min',
                              if (servings != null) 'Serves: $servings',
                            ].join('  |  '),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (r['imageUrl'] != null && r['imageUrl'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          getProxiedImageUrl(r['imageUrl']),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  const Text(
                    'Ingredients',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ingredients
                        .map(
                          (i) => Chip(
                            label: Text(
                              i,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: widget.brandColor.withValues(
                              alpha: 0.05,
                            ),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Instructions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r['instructions'] ?? 'No instructions available.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.brandColor,
                        foregroundColor: AppColors.surface,
                        iconColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await _openScheduleDialog(r, ingredients);
                      },
                      icon: const Icon(Icons.schedule),
                      label: const Text(
                        'Schedule',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: widget.onFavorite,
                tooltip: widget.isFavorited
                    ? 'Already in favorites'
                    : 'Add to favorites',
                icon: Icon(
                  widget.isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                ),
                color: widget.brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeScheduleCalendarPicker extends StatefulWidget {
  const _RecipeScheduleCalendarPicker();

  @override
  State<_RecipeScheduleCalendarPicker> createState() =>
      _RecipeScheduleCalendarPickerState();
}

class _RecipeScheduleCalendarPickerState
    extends State<_RecipeScheduleCalendarPicker> {
  late DateTime _displayMonth;
  final Map<DateTime, String> _plannedDates = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<List<DateTime?>> _getWeeksInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final startDate = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    final weeks = <List<DateTime?>>[];
    var currentDate = startDate;

    while (currentDate.isBefore(lastDay) ||
        currentDate.month == lastDay.month) {
      final week = <DateTime?>[];
      for (int i = 0; i < 7; i++) {
        if (currentDate.month == month.month) {
          week.add(currentDate);
        } else {
          week.add(null);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
      weeks.add(week);

      if (currentDate.month != month.month && currentDate.day > 7) {
        break;
      }
    }

    return weeks;
  }

  Future<String?> _pickMealType(BuildContext context, DateTime date) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Meal for ${date.month}/${date.day}'),
        children: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
            .map(
              (mealType) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, mealType),
                child: Text(mealType),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _toggleDate(DateTime date) async {
    final normalizedDate = _normalizeDate(date);

    if (_plannedDates.containsKey(normalizedDate)) {
      setState(() {
        _plannedDates.remove(normalizedDate);
      });
      return;
    }

    final mealType = await _pickMealType(context, normalizedDate);
    if (mealType == null) return;

    setState(() {
      _plannedDates[normalizedDate] = mealType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _getWeeksInMonth(_displayMonth);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final plannedEntries = _plannedDates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.navBar,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _displayMonth = DateTime(
                        _displayMonth.year,
                        _displayMonth.month - 1,
                      );
                    });
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      DateFormat('MMMM yyyy').format(_displayMonth),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navBar,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.navBar,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _displayMonth = DateTime(
                        _displayMonth.year,
                        _displayMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _ChatCalendarDayHeader('Mon'),
                _ChatCalendarDayHeader('Tue'),
                _ChatCalendarDayHeader('Wed'),
                _ChatCalendarDayHeader('Thu'),
                _ChatCalendarDayHeader('Fri'),
                _ChatCalendarDayHeader('Sat'),
                _ChatCalendarDayHeader('Sun'),
              ],
            ),
            const SizedBox(height: 8),
            ...weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: week.map((date) {
                    if (date == null) {
                      return const SizedBox(width: 32, height: 32);
                    }

                    final normalizedDate = _normalizeDate(date);
                    final isToday = normalizedDate == today;
                    final isSelected = _plannedDates.containsKey(
                      normalizedDate,
                    );

                    return GestureDetector(
                      onTap: () => _toggleDate(normalizedDate),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.selectionColor
                              : isToday
                              ? AppColors.selectionColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.selectionColor,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.surface
                                  : isToday
                                  ? AppColors.selectionColor
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
            if (plannedEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: plannedEntries
                      .map(
                        (entry) => Chip(
                          label: Text(
                            '${DateFormat('MMM d').format(entry.key)} · ${entry.value}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.selectionColor.withValues(
                            alpha: 0.12,
                          ),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _plannedDates),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navBar,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: AppColors.surface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCalendarDayHeader extends StatelessWidget {
  final String label;

  const _ChatCalendarDayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
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
  late List<AnimationController> _controllers;
  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.surface,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -4 * _controllers[i].value),
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.statusNone,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
