import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/food.dart';
import '../db/user.dart';
import '../navigation/nav_helper.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../providers/food_providers.dart';
import '../services/food_image_service.dart';
import '../theme/app_colors.dart';
import '../widgets/nav_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.isInPageView = false});

  final bool isInPageView;

  static const Color _screenBackground = AppColors.homeBackground;
  static const Color _brandGreen = AppColors.homeBrand;
  static const Color _proteinColor = AppColors.homeProtein;
  static const Color _carbColor = AppColors.homeCarbs;
  static const Color _fatColor = AppColors.homeFat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: _screenBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userProfileAsync = ref.watch(firestoreUserProfileProvider(userId));
    final foodLogAsync = ref.watch(firestoreFoodLogProvider(userId));
    final streakAsync = ref.watch(dailyStreakProvider(userId));

    final profile = userProfileAsync.valueOrNull;
    final foodLog = foodLogAsync.valueOrNull ?? const <FoodItem>[];
    final streak = streakAsync.valueOrNull ?? 0;
    final metrics = _HomeMetrics.fromData(profile: profile, foodLog: foodLog);

    final bodyContent = SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _TopHeader(
                streak: streak,
                onProfileTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _CalorieSummaryCard(metrics: metrics),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _InsightCard(
                name: _displayName(profile),
                message: _tipFor(metrics),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Today\'s Meals',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 188,
              child: metrics.todayMeals.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _NoMealsPlaceholder(),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: metrics.todayMeals.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final meal = metrics.todayMeals[index];
                        return SizedBox(
                          width: math.min(
                            MediaQuery.of(context).size.width * 0.78,
                            300,
                          ),
                          child: _RecentMealCard(food: meal),
                        );
                      },
                    ),
            ),
          ),
          if (foodLogAsync.isLoading && foodLog.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _screenBackground,
      body: bodyContent,
      bottomNavigationBar: isInPageView
          ? null
          : NavBar(
              currentIndex: navIndexHome,
              onTap: (index) => handleNavTap(context, index),
            ),
    );
  }

  static String _displayName(AppUser? profile) {
    final name = profile?.firstname.trim();
    if (name == null || name.isEmpty) {
      return 'there';
    }
    return name;
  }

  static String _tipFor(_HomeMetrics metrics) {
    if (metrics.todayMeals.isEmpty) {
      return 'A quick photo log is the fastest way to keep your streak moving.';
    }

    final proteinGap = metrics.proteinGoal - metrics.currentProtein;
    if (proteinGap > 12) {
      return 'Be sure to eat more protein. You are ${proteinGap.round()}g under your daily goal.';
    }

    if (metrics.calorieDelta > 0 && metrics.calorieDelta <= 300) {
      return 'You are close to your calorie target. Finish with something balanced and filling.';
    }

    if (metrics.calorieDelta < 0) {
      return 'Aim for lighter meals for the rest of the day and keep your protein high.';
    }

    return 'Protein and calories both look steady. Keep the same pace through dinner.';
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.streak, required this.onProfileTap});

  final int streak;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.homeCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.homeTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'WISERBITES',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: HomeScreen._brandGreen,
          ),
        ),
        Semantics(
          button: true,
          label: 'Profile',
          child: GestureDetector(
            onTap: onProfileTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.homeCard,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                color: AppColors.homeTextSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalorieSummaryCard extends StatelessWidget {
  const _CalorieSummaryCard({required this.metrics});

  final _HomeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final chipColor = switch (metrics.calorieStatus) {
      _CalorieStatus.over => const Color(0xFFFF3B30),
      _CalorieStatus.nearGoal => const Color(0xFFFF9500),
      _CalorieStatus.onTrack => HomeScreen._brandGreen,
    };
    final chipLabel = metrics.calorieDelta >= 0
        ? '${metrics.calorieDelta.round()} left'
        : '${metrics.calorieDelta.abs().round()} over';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.homeCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metrics.currentCalories.round().toString(),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              color: AppColors.homeTextPrimary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'of ${metrics.calorieGoal.round()} kcal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.homeTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chipLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Semantics(
                  label:
                      'Calories: ${metrics.currentCalories.round()} of ${metrics.calorieGoal.round()} kilocalories',
                  value: '${(metrics.calorieProgress * 100).round()}%',
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.homeDivider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: metrics.calorieProgress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(chipColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Center(
                    child: _MacroCircle(
                      label: 'Protein',
                      value: '${metrics.currentProtein.round()}g',
                      semanticsLabel:
                          'Protein ${metrics.currentProtein.round()} of ${metrics.proteinGoal.round()} grams',
                      progress: metrics.proteinProgress,
                      color: HomeScreen._proteinColor,
                      icon: Icons.fitness_center,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _MacroCircle(
                      label: 'Carbs',
                      value: '${metrics.currentCarbs.round()}g',
                      semanticsLabel:
                          'Carbs ${metrics.currentCarbs.round()} of ${metrics.carbsGoal.round()} grams',
                      progress: metrics.carbProgress,
                      color: HomeScreen._carbColor,
                      icon: Icons.grain,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _MacroCircle(
                      label: 'Fats',
                      value: '${metrics.currentFat.round()}g',
                      semanticsLabel:
                          'Fat ${metrics.currentFat.round()} of ${metrics.fatGoal.round()} grams',
                      progress: metrics.fatProgress,
                      color: HomeScreen._fatColor,
                      icon: Icons.opacity,
                    ),
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.name, required this.message});

  final String name;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.homeCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HomeScreen._brandGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👋', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hey $name!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.homeTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.homeSubtleSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.homeDivider),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: HomeScreen._brandGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: HomeScreen._brandGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.homeTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
      top: false,
      child: Column(
        children: [
          const top_bar(showProfileButton: true),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentPadding = (constraints.maxHeight * 0.014)
                    .clamp(10.0, 16.0)
                    .toDouble();
                final sectionSpacing = (constraints.maxHeight * 0.015)
                    .clamp(8.0, 14.0)
                    .toDouble();

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    contentPadding,
                    contentPadding,
                    contentPadding * 0.8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Go to profile. $greeting, $name!',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                          child: Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.of(context).size.height * 0.13,
                            ),
                            padding: const EdgeInsets.all(20),
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compactLayout =
                                    constraints.maxWidth < 340;

                                final greetingText = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$greeting,',
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
                                      style: TextStyle(
                                        fontSize: constraints.maxWidth < 280
                                            ? 20
                                            : 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('EEEE, MMM d').format(now),
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
                                  height: compactLayout ? 60 : 80,
                                  width: compactLayout ? 60 : 80,
                                  child: Image.asset(
                                    'lib/assets/icons/WISERBITES_img_only.png',
                                    fit: BoxFit.contain,
                                    color: AppColors.brand,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                );

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: greetingText),
                                    const SizedBox(width: 10),
                                    logo,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: sectionSpacing),
                      Expanded(
                        child: userProfileAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => const SizedBox.shrink(),
                          data: (userProfile) {
                            if (userProfile == null) {
                              return const Center(
                                child: Text('Loading your profile...'),
                              );
                            }

                            return foodLogAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => const SizedBox.shrink(),
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
                                    currentCalories +=
                                        item.calories_g * item.mass_g;
                                    currentProtein +=
                                        item.protein_g * item.mass_g;
                                    currentCarbs += item.carbs_g * item.mass_g;
                                    currentFat += item.fat * item.mass_g;
                                    todaysFoods.add(item);
                                  }
                                }

                                final calorieGoal = userProfile
                                    .mealProfile
                                    .dailyCalorieGoal
                                    .toDouble();
                                final macroGoals =
                                    userProfile.mealProfile.macroGoals;
                                final proteinRaw =
                                    (macroGoals['protein'] ?? 0.0).toDouble();
                                final carbsRaw = (macroGoals['carbs'] ?? 0.0)
                                    .toDouble();
                                final fatRaw =
                                    (macroGoals['fat'] ??
                                            macroGoals['fats'] ??
                                            0.0)
                                        .toDouble();
                                double proteinGoal = proteinRaw;
                                double carbsGoal = carbsRaw;
                                double fatGoal = fatRaw;

                                final values = [
                                  proteinRaw,
                                  carbsRaw,
                                  fatRaw,
                                ].where((v) => v > 0).toList();
                                final looksLikePercentages =
                                    values.isNotEmpty &&
                                    values.every((v) => v <= 100.0);

                                if (looksLikePercentages) {
                                  proteinGoal =
                                      (calorieGoal * (proteinRaw / 100)) / 4;
                                  carbsGoal =
                                      (calorieGoal * (carbsRaw / 100)) / 4;
                                  fatGoal = (calorieGoal * (fatRaw / 100)) / 9;
                                }

                                if (proteinGoal <= 0) proteinGoal = 150;
                                if (carbsGoal <= 0) carbsGoal = 200;
                                if (fatGoal <= 0) fatGoal = 65;

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 18,
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
                                          const SizedBox(height: 14),
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
                                    SizedBox(height: sectionSpacing),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        "Today's Meals:",
                                        style: TextStyle(
                                          fontSize:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.02,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentBrown,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: (sectionSpacing * 0.6)
                                          .clamp(6.0, 10.0)
                                          .toDouble(),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onHorizontalDragStart: (_) {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        onHorizontalDragUpdate: (_) {},
                                        onHorizontalDragEnd: (_) {},
                                        onHorizontalDragCancel: () {},
                                        onHorizontalDragDown: (_) {},
                                        child: todaysFoods.isEmpty
                                            ? PageView(
                                                controller: PageController(
                                                  viewportFraction: 0.85,
                                                ),
                                                children: const [
                                                  _NoMealsPlaceholder(),
                                                ],
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
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCircle extends StatelessWidget {
  const _MacroCircle({
    required this.label,
    required this.value,
    required this.semanticsLabel,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String semanticsLabel;
  final double progress;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.1),
                    strokeWidth: 6,
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.homeTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.homeTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _RecentMealCard extends StatelessWidget {
  const _RecentMealCard({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final calories = (food.calories_g * food.mass_g).round();
    final accentColor = _mealAccentColor(food);
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.35);
    final titleScaler = TextScaler.linear(textScale.clamp(1.0, 1.08));
    final detailScaler = TextScaler.linear(textScale.clamp(1.0, 1.05));
    final titleStyle = _titleStyleFor(food.name);
    final titleLines = textScale > 1.15 ? 4 : 3;
    final imageUrlRaw = (food.imageUrl ?? '').trim();
    final imageUrl =
        imageUrlRaw.isNotEmpty &&
            FoodImageService.shouldShowImageForEntry(food.consumedAt)
        ? imageUrlRaw
        : null;
    final isUserCapturedImage = _isFileImage(imageUrl);

    return Semantics(
      button: true,
      label:
          '${food.name}, $calories calories, ${food.mealType}. Tap for details.',
      child: GestureDetector(
        onTap: () => _showFoodDetails(context),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.homeCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.homeCard,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                    border: Border(
                      right: BorderSide(color: AppColors.homeDivider, width: 1),
                    ),
                  ),
                  child: imageUrl == null
                      ? _MealPlaceholderVisual(
                          emoji: _emojiForFood(food),
                          accentColor: accentColor,
                        )
                      : Padding(
                          padding: EdgeInsets.all(isUserCapturedImage ? 0 : 8),
                          child: _FoodImageHero(
                            imageUrl: imageUrl,
                            fallbackEmoji: _emojiForFood(food),
                            fit: isUserCapturedImage
                                ? BoxFit.cover
                                : BoxFit.contain,
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          food.mealType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: accentColor,
                          ),
                          textScaler: detailScaler,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          food.name,
                          style: titleStyle,
                          textScaler: titleScaler,
                          maxLines: titleLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$calories kcal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.homeTextSecondary,
                        ),
                        textScaler: detailScaler,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFoodDetails(BuildContext context) {
    final imageUrlRaw = (food.imageUrl ?? '').trim();
    final imageUrl =
        imageUrlRaw.isNotEmpty &&
            FoodImageService.shouldShowImageForEntry(food.consumedAt)
        ? imageUrlRaw
        : null;
    final isUserCapturedImage = _isFileImage(imageUrl);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          food.name,
          style: const TextStyle(
            color: HomeScreen._brandGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null) ...[
                  _FoodImagePreview(
                    imageUrl: imageUrl,
                    height: 140,
                    fit: isUserCapturedImage ? BoxFit.cover : BoxFit.contain,
                    padding: EdgeInsets.all(isUserCapturedImage ? 0 : 10),
                  ),
                  const SizedBox(height: 10),
                ],
                _DetailRow(
                  label: 'Calories',
                  value: '${(food.calories_g * food.mass_g).round()} kcal',
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Protein',
                  value:
                      '${(food.protein_g * food.mass_g).toStringAsFixed(1)} g',
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.homeTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  static Color _mealAccentColor(FoodItem food) {
    final mealType = food.mealType.toLowerCase();
    if (mealType.contains('breakfast')) {
      return const Color(0xFFFF9500);
    }
    if (mealType.contains('lunch')) {
      return HomeScreen._brandGreen;
    }
    if (mealType.contains('dinner')) {
      return const Color(0xFF5856D6);
    }
    if (mealType.contains('snack')) {
      return const Color(0xFF007AFF);
    }
    return const Color(0xFF9C27B0);
  }

  static String _emojiForFood(FoodItem food) {
    final normalized = food.name.toLowerCase();
    if (normalized.contains('salad')) return '🥗';
    if (normalized.contains('toast')) return '🍞';
    if (normalized.contains('yogurt')) return '🥛';
    if (normalized.contains('shake') || normalized.contains('smoothie')) {
      return '🥤';
    }
    if (normalized.contains('chicken')) return '🍗';
    if (normalized.contains('avocado')) return '🥑';
    if (normalized.contains('egg')) return '🍳';
    if (normalized.contains('rice')) return '🍚';

    final mealType = food.mealType.toLowerCase();
    if (mealType.contains('breakfast')) return '🍳';
    if (mealType.contains('lunch')) return '🥗';
    if (mealType.contains('dinner')) return '🍽️';
    if (mealType.contains('snack')) return '🍎';
    return '🍴';
  }

  static bool _isFileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(imageUrl);
    return uri != null && uri.scheme == 'file';
  }

  static TextStyle _titleStyleFor(String foodName) {
    final length = foodName.trim().length;
    if (length > 42) {
      return const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.homeTextPrimary,
        height: 1.15,
      );
    }
    if (length > 28) {
      return const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.homeTextPrimary,
        height: 1.15,
      );
    }
    return const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.homeTextPrimary,
      height: 1.15,
    );
  }
}

class _FoodImageHero extends StatelessWidget {
  const _FoodImageHero({
    required this.imageUrl,
    required this.fallbackEmoji,
    this.fit = BoxFit.contain,
  });

  final String imageUrl;
  final String fallbackEmoji;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl);
    final isFileImage = uri != null && uri.scheme == 'file';

    Widget fallback() {
      return Center(
        child: Text(fallbackEmoji, style: const TextStyle(fontSize: 48)),
      );
    }

    if (isFileImage) {
      return Image.file(
        File.fromUri(uri),
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      alignment: Alignment.center,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return fallback();
      },
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}

class _FoodImagePreview extends StatelessWidget {
  const _FoodImagePreview({
    required this.imageUrl,
    this.height = 88,
    this.fit = BoxFit.cover,
    this.padding = EdgeInsets.zero,
  });

  final String imageUrl;
  final double height;
  final BoxFit fit;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl);
    final isFileImage = uri != null && uri.scheme == 'file';

    Widget placeholder() {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: HomeScreen._brandGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          color: HomeScreen._brandGreen,
          size: 26,
        ),
      );
    }

    final imageWidget = isFileImage
        ? Image.file(
            File.fromUri(uri),
            width: double.infinity,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => placeholder(),
          )
        : Image.network(
            imageUrl,
            width: double.infinity,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }
              return placeholder();
            },
            errorBuilder: (_, __, ___) => placeholder(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Padding(padding: padding, child: imageWidget),
      ),
    );
  }
}

class _MealPlaceholderVisual extends StatelessWidget {
  const _MealPlaceholderVisual({
    required this.emoji,
    required this.accentColor,
  });

  final String emoji;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accentColor.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 42)),
    );
  }
}

class _NoMealsPlaceholder extends StatelessWidget {
  const _NoMealsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.homeCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: HomeScreen._brandGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: HomeScreen._brandGreen,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No meals logged today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.homeTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start with a quick photo to populate today\'s feed.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.homeTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _HomeMetrics {
  const _HomeMetrics({
    required this.currentCalories,
    required this.calorieGoal,
    required this.currentProtein,
    required this.proteinGoal,
    required this.currentCarbs,
    required this.carbsGoal,
    required this.currentFat,
    required this.fatGoal,
    required this.todayMeals,
  });

  factory _HomeMetrics.fromData({
    required AppUser? profile,
    required List<FoodItem> foodLog,
  }) {
    final now = DateTime.now();
    final todayMeals = foodLog.where((item) {
      final consumedAt = item.consumedAt;
      return consumedAt.year == now.year &&
          consumedAt.month == now.month &&
          consumedAt.day == now.day;
    }).toList();

    double currentCalories = 0;
    double currentProtein = 0;
    double currentCarbs = 0;
    double currentFat = 0;

    for (final item in todayMeals) {
      currentCalories += item.calories_g * item.mass_g;
      currentProtein += item.protein_g * item.mass_g;
      currentCarbs += item.carbs_g * item.mass_g;
      currentFat += item.fat * item.mass_g;
    }

    final calorieGoal = (profile?.mealProfile.dailyCalorieGoal ?? 2500)
        .toDouble();
    final macroGoals =
        profile?.mealProfile.macroGoals ?? const <String, double>{};
    final proteinRaw = (macroGoals['protein'] ?? 0).toDouble();
    final carbsRaw = (macroGoals['carbs'] ?? 0).toDouble();
    final fatRaw = (macroGoals['fat'] ?? macroGoals['fats'] ?? 0).toDouble();

    double proteinGoal = proteinRaw;
    double carbsGoal = carbsRaw;
    double fatGoal = fatRaw;

    final providedGoals = [
      proteinRaw,
      carbsRaw,
      fatRaw,
    ].where((v) => v > 0).toList();
    final looksLikePercentages =
        providedGoals.isNotEmpty && providedGoals.every((v) => v <= 100);

    if (looksLikePercentages) {
      proteinGoal = (calorieGoal * (proteinRaw / 100)) / 4;
      carbsGoal = (calorieGoal * (carbsRaw / 100)) / 4;
      fatGoal = (calorieGoal * (fatRaw / 100)) / 9;
    }

    if (proteinGoal <= 0) {
      proteinGoal = 150;
    }
    if (carbsGoal <= 0) {
      carbsGoal = 200;
    }
    if (fatGoal <= 0) {
      fatGoal = 65;
    }

    return _HomeMetrics(
      currentCalories: currentCalories,
      calorieGoal: calorieGoal,
      currentProtein: currentProtein,
      proteinGoal: proteinGoal,
      currentCarbs: currentCarbs,
      carbsGoal: carbsGoal,
      currentFat: currentFat,
      fatGoal: fatGoal,
      todayMeals: todayMeals,
    );
  }

  final double currentCalories;
  final double calorieGoal;
  final double currentProtein;
  final double proteinGoal;
  final double currentCarbs;
  final double carbsGoal;
  final double currentFat;
  final double fatGoal;
  final List<FoodItem> todayMeals;

  double get calorieProgress {
    if (calorieGoal <= 0) {
      return 0;
    }
    return (currentCalories / calorieGoal).clamp(0.0, 1.0);
  }

  double get proteinProgress =>
      proteinGoal <= 0 ? 0 : (currentProtein / proteinGoal).clamp(0.0, 1.0);

  double get carbProgress =>
      carbsGoal <= 0 ? 0 : (currentCarbs / carbsGoal).clamp(0.0, 1.0);

  double get fatProgress =>
      fatGoal <= 0 ? 0 : (currentFat / fatGoal).clamp(0.0, 1.0);

  double get calorieDelta => calorieGoal - currentCalories;

  _CalorieStatus get calorieStatus {
    if (calorieDelta < 0) {
      return _CalorieStatus.over;
    }
    if (calorieProgress >= 0.85) {
      return _CalorieStatus.nearGoal;
    }
    return _CalorieStatus.onTrack;
  }
}

enum _CalorieStatus { onTrack, nearGoal, over }
