import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:carousel_slider/carousel_slider.dart';
import '../db/food.dart';
import '../providers/food_providers.dart';
import '../providers/user_providers.dart';
import '../providers/firestore_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/top_bar.dart';
import '../theme/app_colors.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  final bool isInPageView;

  const HomeScreen({super.key, this.isInPageView = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final userProfileAsync = userId != null ? ref.watch(firestoreUserProfileProvider(userId)) : const AsyncValue.loading();
    final foodLogAsync = userId != null ? ref.watch(firestoreFoodLogProvider(userId)) : const AsyncValue.loading();
    final foodSuggestionsAsync = ref.watch(foodSuggestionsProvider);
    final name = userProfileAsync.valueOrNull?.firstname ?? 'User';

    final bodyContent = SafeArea(
      top: false,
      child: Column(
        children: [
          const top_bar(),
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.all(MediaQuery.of(context).size.height * 0.02),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Good Morning,',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF967460),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$name!',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5F9735),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('EEEE, MMM d').format(DateTime.now()),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF967460),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 80,
                            width: 80,
                            child: Image.asset(
                              'lib/icons/WISERBITES_img_only.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  foodLogAsync.when(
                    data: (foodLog) {
                      final today = DateTime.now();
                      double currentCalories = 0;
                      double currentProtein = 0;
                      double currentCarbs = 0;
                      double currentFat = 0;

                      for (final item in foodLog) {
                        if (item.consumedAt.year == today.year &&
                            item.consumedAt.month == today.month &&
                            item.consumedAt.day == today.day) {
                          currentCalories += item.calories_g * item.mass_g;
                          currentProtein += item.protein_g * item.mass_g;
                          currentCarbs += item.carbs_g * item.mass_g;
                          currentFat += item.fat * item.mass_g;
                        }
                      }

                      final userProfile = userProfileAsync.valueOrNull;
                      final calorieGoal = userProfile?.mealProfile.dailyCalorieGoal.toDouble() ?? 2000.0;
                      final macroGoals = userProfile?.mealProfile.macroGoals ?? {};
                      final proteinRaw = (macroGoals['protein'] ?? 0.0).toDouble();
                      final carbsRaw = (macroGoals['carbs'] ?? 0.0).toDouble();
                      final fatRaw = (macroGoals['fat'] ?? macroGoals['fats'] ?? 0.0).toDouble();

                      double proteinGoal = proteinRaw;
                      double carbsGoal = carbsRaw;
                      double fatGoal = fatRaw;

                      // Heuristic for percentages vs grams
                      final values = [proteinRaw, carbsRaw, fatRaw].where((v) => v > 0).toList();
                      final looksLikePercentages = values.isNotEmpty && values.every((v) => v <= 100.0);

                      if (looksLikePercentages) {
                        proteinGoal = (calorieGoal * (proteinRaw / 100)) / 4;
                        carbsGoal = (calorieGoal * (carbsRaw / 100)) / 4;
                        fatGoal = (calorieGoal * (fatRaw / 100)) / 9;
                      }

                      if (proteinGoal <= 0) proteinGoal = 150;
                      if (carbsGoal <= 0) carbsGoal = 200;
                      if (fatGoal <= 0) fatGoal = 65;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MacroIndicator(label: 'Calories', current: currentCalories, goal: calorieGoal, color: const Color(0xFF5F9735), unit: 'kcal'),
                            _MacroIndicator(label: 'Protein', current: currentProtein, goal: proteinGoal, color: const Color(0xFFC2482B), unit: 'g'),
                            _MacroIndicator(label: 'Carbs', current: currentCarbs, goal: carbsGoal, color: const Color(0xFFE0A100), unit: 'g'),
                            _MacroIndicator(label: 'Fat', current: currentFat, goal: fatGoal, color: const Color(0xFF3A6FB8), unit: 'g'),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexHome,
        onTap: (index) => handleNavTap(context, index),
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
              final sampleFood = FoodItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: 'Sample Apple',
                mass_g: 100,
                calories_g: 2.0,
                protein_g: 0.025,
                carbs_g: 0.10,
                fat: 0.005,
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

class _MacroIndicator extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  final String unit;

  const _MacroIndicator({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final double percent = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return CircularPercentIndicator(
      radius: MediaQuery.of(context).size.width * 0.1,
      lineWidth: 12,
      percent: percent,
      center: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Text(
          '${current.toInt()}$unit',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
        ),
      ),
      progressColor: color,
      backgroundColor: color.withValues(alpha: 0.25),
      //circularStrokeCap: CircularStrokeCap.round,
      animation: true,
    );
  }
}