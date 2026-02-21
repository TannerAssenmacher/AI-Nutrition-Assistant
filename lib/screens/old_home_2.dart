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
import '../theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  final bool isInPageView;

  const HomeScreen({super.key, this.isInPageView = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodLog = ref.watch(foodLogProvider);
    final totalCalories = ref.watch(totalDailyCaloriesProvider);
    final dailyMacros = ref.watch(totalDailyMacrosProvider);
    final dailyProtein = dailyMacros['protein'] ?? 0.0;
    final dailyCarbs = dailyMacros['carbs'] ?? 0.0;
    final dailyFat = dailyMacros['fat'] ?? 0.0;
    final totalCaloriesLabel = totalCalories.round();
    final dailyProteinLabel = dailyProtein.round();
    final dailyCarbsLabel = dailyCarbs.round();
    final dailyFatLabel = dailyFat.round();
    final userProfile = ref.watch(userProfileNotifierProvider);
    final foodSuggestionsAsync = ref.watch(foodSuggestionsProvider);
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final dailyStreakAsync =
        userId != null ? ref.watch(dailyStreakProvider(userId)) : null;
    final name = userProfile?.firstname ?? 'User';

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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // --- Card is now intrinsically sized instead of a fixed height ---
                      Container(
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double cardWidth = constraints.maxWidth;
                            // Use screen height as a reference for sizing instead of card height
                            final double screenH = MediaQuery.of(context).size.height;
                            final double topRadius =
                                (screenH * 0.09).clamp(40.0, 90.0).toDouble();
                            final double topLineWidth =
                                (cardWidth * 0.08).clamp(6.0, 18.0).toDouble();
                            final double macroRadius =
                                (screenH * 0.05).clamp(26.0, 50.0).toDouble();
                            final double macroLineWidth =
                                (cardWidth * 0.05).clamp(4.0, 12.0).toDouble();
                            final double headerFont =
                                (screenH * 0.025).clamp(12.0, 22.0).toDouble();
                            final double centerFont =
                                (screenH * 0.022).clamp(12.0, 20.0).toDouble();
                            final double macroFont =
                                (screenH * 0.018).clamp(10.0, 16.0).toDouble();
                            final double spacing =
                                (screenH * 0.012).clamp(8.0, 16.0).toDouble();

                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRect(
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      heightFactor: 0.7,
                                      child: CircularPercentIndicator(
                                        radius: topRadius,
                                        lineWidth: topLineWidth,
                                        arcType: ArcType.HALF,
                                        animation: true,
                                        percent: (totalCalories / 2000)
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                        center: Text(
                                          '$totalCaloriesLabel Cal',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: centerFont,
                                            color: AppColors.brand,
                                          ),
                                        ),
                                        header: Text(
                                          "Calories:",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: headerFont,
                                            color: AppColors.brand,
                                          ),
                                        ),
                                        circularStrokeCap:
                                            CircularStrokeCap.round,
                                        progressColor: AppColors.brand,
                                        arcBackgroundColor:
                                            AppColors.background,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: spacing),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing:
                                        (cardWidth * 0.04).clamp(12.0, 24.0).toDouble(),
                                    runSpacing: 8,
                                    children: [
                                      CircularPercentIndicator(
                                        radius: macroRadius,
                                        lineWidth: macroLineWidth,
                                        animation: true,
                                        percent: (dailyProtein / 150)
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                        header: Text(
                                          "Protein:",
                                          style: TextStyle(
                                            color: AppColors.protein,
                                            fontWeight: FontWeight.bold,
                                            fontSize: macroFont,
                                          ),
                                        ),
                                        footer: Text(
                                          "$dailyProteinLabel g",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: macroFont,
                                            color: AppColors.protein,
                                          ),
                                        ),
                                        circularStrokeCap:
                                            CircularStrokeCap.round,
                                        progressColor: AppColors.protein,
                                        backgroundColor:
                                            AppColors.background,
                                      ),
                                      CircularPercentIndicator(
                                        radius: macroRadius,
                                        lineWidth: macroLineWidth,
                                        animation: true,
                                        percent: (dailyCarbs / 150)
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                        header: Text(
                                          "Carbs:",
                                          style: TextStyle(
                                            color: AppColors.carbs,
                                            fontWeight: FontWeight.bold,
                                            fontSize: macroFont,
                                          ),
                                        ),
                                        footer: Text(
                                          "$dailyCarbsLabel g",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: macroFont,
                                            color: AppColors.carbs,
                                          ),
                                        ),
                                        circularStrokeCap:
                                            CircularStrokeCap.round,
                                        progressColor: AppColors.carbs,
                                        backgroundColor:
                                            AppColors.background,
                                      ),
                                      CircularPercentIndicator(
                                        radius: macroRadius,
                                        lineWidth: macroLineWidth,
                                        animation: true,
                                        percent: (dailyFat / 150)
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                        header: Text(
                                          "Fats:",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: macroFont,
                                            color: AppColors.fat,
                                          ),
                                        ),
                                        footer: Text(
                                          "$dailyFatLabel g",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: macroFont,
                                            color: AppColors.fat,
                                          ),
                                        ),
                                        circularStrokeCap:
                                            CircularStrokeCap.round,
                                        progressColor: AppColors.fat,
                                        backgroundColor:
                                            AppColors.background,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Daily Streak Indicator
                      if (dailyStreakAsync != null) ...[
                        Positioned(
                          top: 0,
                          right: 0,
                          child: dailyStreakAsync.when(
                            data: (streak) => _StreakIndicator(streak: streak),
                            loading: () => SizedBox(
                              width: MediaQuery.of(context).size.width * 0.2,
                              height: MediaQuery.of(context).size.height * 0.1,
                              child: Center(
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.5,
                                  height:
                                      MediaQuery.of(context).size.height * 0.15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 15)),
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

class _StreakIndicator extends StatelessWidget {
  final int streak;

  const _StreakIndicator({required this.streak});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // Wider minimum so "DAY STREAK" never wraps
    final double boxWidth =
        (screenWidth * 0.22).clamp(80.0, 110.0).toDouble();
    final double paddingH = (boxWidth * 0.15).clamp(8.0, 14.0).toDouble();
    final double paddingV = (boxWidth * 0.1).clamp(6.0, 10.0).toDouble();
    final double emojiSize = (boxWidth * 0.28).clamp(18.0, 28.0).toDouble();
    final double countSize = (boxWidth * 0.24).clamp(16.0, 24.0).toDouble();
    final double labelSize = (boxWidth * 0.12).clamp(8.0, 11.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: boxWidth,
        maxWidth: boxWidth,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: paddingH,
          vertical: paddingV,
        ),
        decoration: BoxDecoration(
          color: AppColors.streakBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.carbs,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔥',
              style: TextStyle(fontSize: emojiSize),
            ),
            SizedBox(height: 2),
            Text(
              '$streak',
              style: TextStyle(
                fontSize: countSize,
                fontWeight: FontWeight.bold,
                color: AppColors.carbs,
              ),
            ),
            Text(
              'Daily Streak',
              style: TextStyle(
                fontSize: labelSize,
                color: AppColors.carbs,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
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