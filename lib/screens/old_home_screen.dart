import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/food.dart';
import '../providers/food_providers.dart';
import '../providers/user_providers.dart';
import '../theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodLog = ref.watch(foodLogProvider);
    final totalCalories = ref.watch(totalDailyCaloriesProvider);
    final dailyMacros = ref.watch(totalDailyMacrosProvider);
    final userProfile = ref.watch(userProfileNotifierProvider);
    final foodSuggestionsAsync = ref.watch(foodSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Assistant'),
        backgroundColor: AppColors.success,
        foregroundColor: AppColors.surface, 
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calorie Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Calories',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalCalories calories consumed',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (userProfile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Goal: ${userProfile.mealProfile.dailyCalorieGoal} calories',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Macros Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macronutrients',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MacroColumn(
                          label: 'Protein',
                          value:
                              '${dailyMacros['protein']?.toStringAsFixed(1)}g',
                          color: AppColors.protein,
                        ),
                        _MacroColumn(
                          label: 'Carbs',
                          value: '${dailyMacros['carbs']?.toStringAsFixed(1)}g',
                          color: AppColors.carbs,
                        ),
                        _MacroColumn(
                          label: 'Fat',
                          value: '${dailyMacros['fat']?.toStringAsFixed(1)}g',
                          color: AppColors.fat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Food Suggestions
            Text(
              'Food Suggestions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            foodSuggestionsAsync.when(
              data: (suggestions) => SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant,
                                color: AppColors.success,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                suggestions[index],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error: $error'),
            ),

            const SizedBox(height: 16),

            // Today's Food Log
            Text(
              'Today\'s Food Log',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (foodLog.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child:
                      Text('No food logged today. Start by adding some food!'),
                ),
              )
            else
              ...foodLog.map((food) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.success.withValues(alpha: 0.15),
                        child: Icon(Icons.restaurant, color: AppColors.success),
                      ),
                      title: Text(food.name),
                      subtitle: Text('${food.calories_g} calories'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () {
                          ref
                              .read(foodLogProvider.notifier)
                              .removeFoodItem(food.id);
                        },
                      ),
                    ),
                  )),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Add Chat FAB
          FloatingActionButton(
            heroTag: 'chatFab',
            onPressed: () {
              Navigator.pushNamed(context, '/chat');
            },
            backgroundColor: AppColors.selectionColor,
            child: const Icon(Icons.chat, color: AppColors.surface),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'cameraFab',
            onPressed: () => _openMealAnalyzer(context),
            backgroundColor: AppColors.success,
            child: const Icon(Icons.camera_alt, color: AppColors.surface),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addFoodFab',
            onPressed: () => _showAddFoodDialog(context, ref),
            backgroundColor: AppColors.success,
            child: const Icon(Icons.add, color: AppColors.surface),
          ),
        ],
      ),
    );
  }

  Future<void> _openMealAnalyzer(BuildContext context) async {
    await Navigator.of(context).pushNamed('/camera');
  }

  void _showAddFoodDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Food'),
        content: const Text('This would open a food search/add dialog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Example: Add a sample food item
              final sampleFood = FoodItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: 'Sample Apple',
                mass_g: 100,
                calories_g: 2.0,   // 200 cal / 100g = 2.0 cal/g
                protein_g: 0.025,  // 2.5 / 100
                carbs_g: 0.10,     // 10 / 100
                fat: 0.005,        // 0.5 / 100
                mealType: 'snack',
                consumedAt: DateTime.now(),
              );

              ref.read(foodLogProvider.notifier).addFoodItem(sampleFood);
              Navigator.of(context).pop();
            },
            child: const Text('Add Sample'),
          ),
        ],
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label[0],
              style: const TextStyle(
                color: AppColors.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
