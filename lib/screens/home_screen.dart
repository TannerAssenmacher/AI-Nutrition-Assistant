import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:carousel_slider/carousel_slider.dart';
import '../db/food.dart';
import '../providers/food_providers.dart';
import '../providers/user_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/top_bar.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodLog = ref.watch(foodLogProvider);
    final totalCalories = ref.watch(totalDailyCaloriesProvider);
    final dailyMacros = ref.watch(totalDailyMacrosProvider);
    final dailyProtein = dailyMacros['protein'] ?? 0.0;
    final dailyCarbs = dailyMacros['carbs'] ?? 0.0;
    final dailyFat = dailyMacros['fat'] ?? 0.0;
    final userProfile = ref.watch(userProfileNotifierProvider);
    final foodSuggestionsAsync = ref.watch(foodSuggestionsProvider);
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final dailyStreakAsync =
        userId != null ? ref.watch(dailyStreakProvider(userId)) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE2),
      body: Column(
        children: [
          const top_bar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                            //WELCOME USER BOX -----------------------
                            alignment: Alignment.center,
                            height: MediaQuery.of(context).size.height * 0.15,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Stack(children: [
                              Positioned(
                                  top: 20,
                                  left: 20,
                                  right: 20,
                                  child: Text('Welcome back, User!',
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        height: 1.2,
                                      ))),
                              /*Positioned(
                                  bottom: 20,
                                  left: 20,
                                  child: TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      'Click here view today\'s score:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF967460),
                                      ),
                                    ),
                                  ))*/
                            ])),
                      ),
                      // Daily Streak Indicator
                      if (dailyStreakAsync != null) ...[
                        const SizedBox(width: 16),
                        dailyStreakAsync.when(
                          data: (streak) => _StreakIndicator(streak: streak),
                          loading: () => const SizedBox(
                            width: 80,
                            height: 60,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 15)),
                  /*Text( //CONSUMPTION STATS TITLE -----------------------
                  'Today\'s Progress:',

                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A3A2A),
                  )
                ),
                Padding(padding: const EdgeInsets.symmetric(vertical: 5)),*/

                  Container(
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 14,
                        children: [
                          CircularPercentIndicator(
                            radius: 40.0,
                            lineWidth: 10.0,
                            animation: true,
                            percent: totalCalories / 2000,
                            header: Text(
                              "Calories:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                                color: const Color(0xFF5F9735),
                              ),
                            ),
                            footer: Text(
                              "$totalCalories" "kcal",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: const Color(0xFF5F9735),
                              ),
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: const Color(0xFF5F9735),
                            backgroundColor: const Color(0xFFF5EDE2),
                          ),
                          CircularPercentIndicator(
                            radius: 40.0,
                            lineWidth: 10.0,
                            animation: true,
                            percent: dailyProtein / 150,
                            header: Text(
                              "Protein:",
                              style: TextStyle(
                                color: const Color(0xFFC2482B),
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                              ),
                            ),
                            footer: Text(
                              "$dailyProtein" "g",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: const Color(0xFFC2482B),
                              ),
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: const Color(0xFFC2482B),
                            backgroundColor: const Color(0xFFF5EDE2),
                          ),
                          CircularPercentIndicator(
                            radius: 40.0,
                            lineWidth: 10.0,
                            animation: true,
                            percent: dailyCarbs / 150,
                            header: Text(
                              "Carbs:",
                              style: TextStyle(
                                color: const Color(0xFFE0A100),
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                              ),
                            ),
                            footer: Text(
                              "$dailyCarbs" "g",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: const Color(0xFFE0A100),
                              ),
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: const Color(0xFFE0A100),
                            backgroundColor: const Color(0xFFF5EDE2),
                          ),
                          CircularPercentIndicator(
                            radius: 40.0,
                            lineWidth: 10.0,
                            animation: true,
                            percent: dailyFat / 150,
                            header: Text(
                              "Fats:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                                color: const Color(0xFF3A6FB8),
                              ),
                            ),
                            footer: Text(
                              "$dailyFat" "g",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: const Color(0xFF3A6FB8),
                              ),
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: const Color(0xFF3A6FB8),
                            backgroundColor: const Color(0xFFF5EDE2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 15)),
                  /*Text( //TODAYS MEALS TITLE --------------------------
                  'Today\'s Meals:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Padding(padding: const EdgeInsets.symmetric(vertical: 10)),*/
                  /*Container(
                  child: CarouselSlider(
                    items: [1, 2, 3].map((e) {
                      return Container(
                        width: MediaQuery.of(context).size.width  * 1,
                        margin: EdgeInsets.symmetric(horizontal: 0.0),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      );
                    
                    }).toList(),
                    options: CarouselOptions(
                      height: MediaQuery.of(  context).size.height * 0.3,
                      enlargeCenterPage: true,
                      aspectRatio: 4/5,
                      autoPlayCurve: Curves.fastOutSlowIn,
                      autoPlayAnimationDuration: Duration(milliseconds: 800),
                      viewportFraction: 0.8,
                    ),
                  )
                )*/
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavBar(
        currentIndex: navIndexHome,
        onTap: (index) => handleNavTap(context, index),
      ),
    );

    /*return Scaffold(
      /*appBar: AppBar(
        title: const Text('AI Nutrition Assistant', textAlign: TextAlign.center),
        backgroundColor: const Color(0xFF3E2F26),
        foregroundColor: const Color(0xFFF5EDE2),
        /*actions: [
          /*IconButton(
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
          ),*/
          /*IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),*/
        ],*/
      ),*/
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
                          value:
                              '${dailyMacros['protein']?.toStringAsFixed(1)}g',
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
                  child:
                      Text('No food logged today. Start by adding some food!'),
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
                      subtitle: Text('${food.calories_g} calories'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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
            backgroundColor: Colors.blue[600],
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'cameraFab',
            onPressed: () => _openMealAnalyzer(context),
            backgroundColor: Colors.green[700],
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addFoodFab',
            onPressed: () => _showAddFoodDialog(context, ref),
            backgroundColor: Colors.green[600],
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );*/
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
                calories_g: 2.0, // 200 cal / 100g = 2.0 cal/g
                protein_g: 0.025, // 2.5 / 100
                carbs_g: 0.10, // 10 / 100
                fat: 0.005, // 0.5 / 100
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

class _StreakIndicator extends StatelessWidget {
  final int streak;

  const _StreakIndicator({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE0A100),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE0A100),
            ),
          ),
          const Text(
            'day streak',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFE0A100),
              fontWeight: FontWeight.w500,
            ),
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
