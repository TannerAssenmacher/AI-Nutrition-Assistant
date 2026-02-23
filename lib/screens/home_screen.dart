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
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  final bool isInPageView;

  const HomeScreen({super.key, this.isInPageView = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final userProfileAsync = userId != null
        ? ref.watch(firestoreUserProfileProvider(userId))
        : const AsyncValue.loading();
    final foodLogAsync = userId != null
        ? ref.watch(firestoreFoodLogProvider(userId))
        : const AsyncValue.loading();
    final foodSuggestionsAsync = ref.watch(foodSuggestionsProvider);
    final name = userProfileAsync.valueOrNull?.firstname ?? 'User';

    final bodyContent = SafeArea(
      top: false,
      child: Column(
        children: [
          const top_bar(showProfileButton: true),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.height * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Go to profile. Good Morning, $name!',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height * 0.16,
                          ),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1.0);
                              final stackVertically =
                                  textScale > 1.15 ||
                                  constraints.maxWidth < 340;

                              final greetingText = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Good Morning,',
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.height *
                                          0.02,
                                      color: AppColors.accentBrown,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$name!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat(
                                      'EEEE, MMM d',
                                    ).format(DateTime.now()),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.height *
                                          0.015,
                                      color: AppColors.accentBrown,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );

                              final logo = SizedBox(
                                height: 80,
                                width: 80,
                                child: Image.asset(
                                  'lib/icons/WISERBITES_img_only.png',
                                  fit: BoxFit.contain,
                                ),
                              );

                              if (stackVertically) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    greetingText,
                                    const SizedBox(height: 14),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: logo,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: greetingText),
                                  const SizedBox(width: 12),
                                  logo,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ), // closes Semantics
                    const SizedBox(height: 20),
                    foodLogAsync.when(
                      data: (foodLog) {
                        final today = DateTime.now();
                        double currentCalories = 0;
                        double currentProtein = 0;
                        double currentCarbs = 0;
                        double currentFat = 0;
                        final todaysFoods = <FoodItem>[];

                        for (final item in foodLog) {
                          if (item.consumedAt.year == today.year &&
                              item.consumedAt.month == today.month &&
                              item.consumedAt.day == today.day) {
                            currentCalories += item.calories_g * item.mass_g;
                            currentProtein += item.protein_g * item.mass_g;
                            currentCarbs += item.carbs_g * item.mass_g;
                            currentFat += item.fat * item.mass_g;
                            todaysFoods.add(item);
                          }
                        }

                        final userProfile = userProfileAsync.valueOrNull;
                        final calorieGoal =
                            userProfile?.mealProfile.dailyCalorieGoal
                                .toDouble() ??
                            2000.0;
                        final macroGoals =
                            userProfile?.mealProfile.macroGoals ?? {};
                        final proteinRaw = (macroGoals['protein'] ?? 0.0)
                            .toDouble();
                        final carbsRaw = (macroGoals['carbs'] ?? 0.0)
                            .toDouble();
                        final fatRaw =
                            (macroGoals['fat'] ?? macroGoals['fats'] ?? 0.0)
                                .toDouble();

                        double proteinGoal = proteinRaw;
                        double carbsGoal = carbsRaw;
                        double fatGoal = fatRaw;

                        // Heuristic for percentages vs grams
                        final values = [
                          proteinRaw,
                          carbsRaw,
                          fatRaw,
                        ].where((v) => v > 0).toList();
                        final looksLikePercentages =
                            values.isNotEmpty &&
                            values.every((v) => v <= 100.0);

                        if (looksLikePercentages) {
                          proteinGoal = (calorieGoal * (proteinRaw / 100)) / 4;
                          carbsGoal = (calorieGoal * (carbsRaw / 100)) / 4;
                          fatGoal = (calorieGoal * (fatRaw / 100)) / 9;
                        }

                        if (proteinGoal <= 0) proteinGoal = 150;
                        if (carbsGoal <= 0) carbsGoal = 200;
                        if (fatGoal <= 0) fatGoal = 65;

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.black.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _CalorieProgressBar(
                                    current: currentCalories,
                                    goal: calorieGoal,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: _MacroIndicator(
                                            label: 'Protein',
                                            current: currentProtein,
                                            goal: proteinGoal,
                                            color: AppColors.protein,
                                            unit: 'g',
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: _MacroIndicator(
                                            label: 'Carbs',
                                            current: currentCarbs,
                                            goal: carbsGoal,
                                            color: AppColors.carbs,
                                            unit: 'g',
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: _MacroIndicator(
                                            label: 'Fat',
                                            current: currentFat,
                                            goal: fatGoal,
                                            color: AppColors.fat,
                                            unit: 'g',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  "Today's Meals:",
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.height *
                                        0.02,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentBrown,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.2,
                              child: todaysFoods.isEmpty
                                  ? PageView(
                                      controller: PageController(
                                        viewportFraction: 0.85,
                                      ),
                                      children: const [_NoMealsPlaceholder()],
                                    )
                                  : PageView.builder(
                                      controller: PageController(
                                        viewportFraction: 0.85,
                                      ),
                                      itemCount: todaysFoods.length,
                                      itemBuilder: (context, index) {
                                        return _FoodCarouselCard(
                                          food: todaysFoods[index],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
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
}

class _CalorieProgressBar extends StatelessWidget {
  final double current;
  final double goal;

  const _CalorieProgressBar({required this.current, required this.goal});

  @override
  Widget build(BuildContext context) {
    final double percent = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final useStackedLabel =
                textScale > 1.15 || constraints.maxWidth < 300;

            if (useStackedLabel) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${current.round()} / ${goal.round()} Cal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Calories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentBrown,
                  ),
                ),
                Text(
                  '${current.round()} / ${goal.round()} Cal',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Calories: ${current.round()} of ${goal.round()} kilocalories',
          value: '${(percent * 100).round()}%',
          child: LinearPercentIndicator(
            lineHeight: 18.0,
            percent: percent,
            backgroundColor: AppColors.brand.withValues(alpha: 0.2),
            progressColor: AppColors.brand,
            barRadius: const Radius.circular(10),
            animation: true,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _FoodCarouselCard extends StatelessWidget {
  final FoodItem food;

  const _FoodCarouselCard({required this.food});

  @override
  Widget build(BuildContext context) {
    final calories = (food.calories_g * food.mass_g).round();
    return Semantics(
      button: true,
      label:
          '${food.name}, $calories calories, ${food.mealType}. Tap for details.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _showFoodDetails(context, food),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentBrown,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(food.calories_g * food.mass_g).round()} Cal',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
                Text(
                  food.mealType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFoodDetails(BuildContext context, FoodItem food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          food.name,
          style: const TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(
              label: 'Calories',
              value: '${(food.calories_g * food.mass_g).round()} Cal',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Protein',
              value: '${(food.protein_g * food.mass_g).toStringAsFixed(1)} g',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Carbs',
              value: '${(food.carbs_g * food.mass_g).toStringAsFixed(1)} g',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Fat',
              value: '${(food.fat * food.mass_g).toStringAsFixed(1)} g',
            ),
            const SizedBox(height: 8),
            _DetailRow(label: 'Mass', value: '${food.mass_g.round()} g'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.accentBrown),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMealsPlaceholder extends StatelessWidget {
  const _NoMealsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          "No meals logged yet",
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width / 3;
        final radius = (width * 0.42).clamp(42.0, 58.0).toDouble();
        final lineWidth = (radius * 0.22).clamp(9.0, 13.0).toDouble();

        return Semantics(
          label: '$label: ${current.toInt()} of ${goal.toInt()} grams',
          child: CircularPercentIndicator(
            radius: radius,
            lineWidth: lineWidth,
            percent: percent,
            center: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${current.toInt()}$unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ),
            ),
            progressColor: color,
            backgroundColor: color.withValues(alpha: 0.25),
            //circularStrokeCap: CircularStrokeCap.round,
            animation: true,
          ),
        );
      },
    );
  }
}
