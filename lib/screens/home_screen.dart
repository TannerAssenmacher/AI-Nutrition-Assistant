import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/food_providers.dart';
import '../providers/user_providers.dart';
import '../db/food.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodLog = ref.watch(foodLogProvider);
    final totalCalories = ref.watch(totalDailyCaloriesProvider);
    final dailyMacros = ref.watch(totalDailyMacrosProvider);
    final userProfile = ref.watch(userProfileProvider);
    final foodSuggestionsAsync = ref.watch(foodSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Assistant'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
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
                        'Goal: ${userProfile.dailyCalorieGoal} calories',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
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
                          value: '${dailyMacros['protein']?.toStringAsFixed(1)}g',
                          color: Colors.red[300]!,
                        ),
                        _MacroColumn(
                          label: 'Carbs',
                          value: '${dailyMacros['carbs']?.toStringAsFixed(1)}g',
                          color: Colors.blue[300]!,
                        ),
                        _MacroColumn(
                          label: 'Fat',
                          value: '${dailyMacros['fat']?.toStringAsFixed(1)}g',
                          color: Colors.orange[300]!,
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
                                color: Colors.green[600],
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
                  child: Text('No food logged today. Start by adding some food!'),
                ),
              )
            else
              ...foodLog.map((food) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.restaurant, color: Colors.green[600]),
                  ),
                  title: Text(food.name),
                  subtitle: Text('${food.caloriesPer100g} calories'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref.read(foodLogProvider.notifier).removeFoodItem(food.id);
                    },
                  ),
                ),
              )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodDialog(context, ref),
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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
              final sampleFood = Food(
                name: 'Sample Apple',
                category: "Fruit",
                caloriesPer100g: 200,
                proteinPer100g: 2.5,
                carbsPer100g: 10.0,
                fatPer100g: 0.5,
                fiberPer100g: 1.0,
                micronutrients: Micronutrients(
                  calciumMg: 100,
                  ironMg: 0.5,
                  vitaminAMcg: 100,
                  vitaminCMg: 50,
                ),
                source: 'Sample Source',
                consumedAt: DateTime.now(),
                servingSize: 100
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
                color: Colors.white,
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