import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/food_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/top_bar.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';

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
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final dailyStreakAsync =
        userId != null ? ref.watch(dailyStreakProvider(userId)) : null;

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
                      Container(
                        width: MediaQuery.of(context).size.width * 1,
                        height: MediaQuery.of(context).size.height * 0.35,
                        clipBehavior: Clip.none,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRect(
                                child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: 0.7,
                                    child: CircularPercentIndicator(
                                      radius:
                                          MediaQuery.of(context).size.height *
                                              0.1,
                                      lineWidth:
                                          MediaQuery.of(context).size.width *
                                              0.04,
                                      arcType: ArcType.HALF,
                                      animation: true,
                                      percent: totalCalories / 2000,
                                      center: Text(
                                        '$totalCalories' 'kcal',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.025,
                                          color: const Color(0xFF5F9735),
                                        ),
                                      ),
                                      header: Text(
                                        "Calories:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.03,
                                          color: const Color(0xFF5F9735),
                                        ),
                                      ),
                                      /*footer: Text(
                              "$totalCalories" "kcal",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: MediaQuery.of(context).size.width * 0.05,
                                color: const Color(0xFF5F9735),
                              ),
                            ),*/
                                      circularStrokeCap:
                                          CircularStrokeCap.round,
                                      progressColor: const Color(0xFF5F9735),
                                      arcBackgroundColor:
                                          const Color(0xFFF5EDE2),
                                    )),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  CircularPercentIndicator(
                                    radius: MediaQuery.of(context).size.height *
                                        0.05,
                                    lineWidth:
                                        MediaQuery.of(context).size.width *
                                            0.03,
                                    animation: true,
                                    percent: dailyProtein / 150,
                                    header: Text(
                                      "Protein:",
                                      style: TextStyle(
                                        color: const Color(0xFFC2482B),
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025,
                                      ),
                                    ),
                                    footer: Text(
                                      "$dailyProtein" "g",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025,
                                        color: const Color(0xFFC2482B),
                                      ),
                                    ),
                                    circularStrokeCap: CircularStrokeCap.round,
                                    progressColor: const Color(0xFFC2482B),
                                    backgroundColor: const Color(0xFFF5EDE2),
                                  ),
                                  CircularPercentIndicator(
                                    radius: MediaQuery.of(context).size.height *
                                        0.05,
                                    lineWidth:
                                        MediaQuery.of(context).size.width *
                                            0.03,
                                    animation: true,
                                    percent: dailyCarbs / 150,
                                    header: Text(
                                      "Carbs:",
                                      style: TextStyle(
                                        color: const Color(0xFFE0A100),
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025,
                                      ),
                                    ),
                                    footer: Text(
                                      "$dailyCarbs" "g",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025,
                                        color: const Color(0xFFE0A100),
                                      ),
                                    ),
                                    circularStrokeCap: CircularStrokeCap.round,
                                    progressColor: const Color(0xFFE0A100),
                                    backgroundColor: const Color(0xFFF5EDE2),
                                  ),
                                  CircularPercentIndicator(
                                    radius: MediaQuery.of(context).size.height *
                                        0.05,
                                    lineWidth:
                                        MediaQuery.of(context).size.width *
                                            0.03,
                                    animation: true,
                                    percent: dailyFat / 150,
                                    header: Text(
                                      "Fats:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025,
                                        color: const Color(0xFF3A6FB8),
                                      ),
                                    ),
                                    footer: Text(
                                      "$dailyFat" "g",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025,
                                        color: const Color(0xFF3A6FB8),
                                      ),
                                    ),
                                    circularStrokeCap: CircularStrokeCap.round,
                                    progressColor: const Color(0xFF3A6FB8),
                                    backgroundColor: const Color(0xFFF5EDE2),
                                  ),
                                ],
                              ),
                            ]),
                      ),

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
                  /*Text( //CONSUMPTION STATS TITLE -----------------------
                  'Today\'s Progress:',

                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A3A2A),
                  )
                ),
                Padding(padding: const EdgeInsets.symmetric(vertical: 5)),*/

                  Padding(padding: const EdgeInsets.symmetric(vertical: 15)),
                  Text('Today\'s Meals:',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10)),
                  // Meals Carousel
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.28,
                    width: MediaQuery.of(context).size.width * 1,
                    child: foodLog.isEmpty
                        ? _buildEmptyMealCard(context)
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: foodLog.length + 1,
                            itemBuilder: (context, index) {
                              // Last item is the add button
                              if (index == foodLog.length) {
                                return _buildAddMealCard(context);
                              }
                              final food = foodLog[index];
                              return _buildMealCard(
                                context,
                                food.mealType,
                                food.name,
                                (food.calories_g * food.mass_g).toInt(),
                                food.protein_g * food.mass_g,
                                food.carbs_g * food.mass_g,
                                food.fat * food.mass_g,
                                food.imageUrl,
                              );
                            },
                          ),
                  )
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
      backgroundColor: const Color(0xFFF5EDE2),
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexHome,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    String mealType,
    String foodName,
    int calories,
    double protein,
    double carbs,
    double fat,
    String imageUrl,
  ) {
    return GestureDetector(
      onTap: () {
        _showMacroDetails(context, mealType, foodName, calories, protein, carbs, fat);
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image or placeholder
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.fastfood,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.fastfood,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
            // Dark overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Text content
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealType.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    foodName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$calories kcal',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMealCard(BuildContext context) {
    final TextEditingController mealController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Add Your First Meal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mealController,
                decoration: InputDecoration(
                  hintText: 'e.g., Chicken & Rice',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  if (mealController.text.trim().isNotEmpty) {
                    // Call AI analysis with the meal title
                    _analyzeMealByTitle(context, mealController.text.trim());
                    mealController.clear();
                  }
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Analyze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5F9735),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMealCard(BuildContext context) {
    final TextEditingController mealController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: const Color(0xFF5F9735),
              ),
              const SizedBox(height: 12),
              Text(
                'Add New Meal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mealController,
                decoration: InputDecoration(
                  hintText: 'e.g., Chicken & Rice',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  if (mealController.text.trim().isNotEmpty) {
                    // Call AI analysis with the meal title
                    _analyzeMealByTitle(context, mealController.text.trim());
                    mealController.clear();
                  }
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Analyze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5F9735),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _analyzeMealByTitle(BuildContext context, String mealTitle) {
    // Navigate to meal analysis screen with the meal title as argument
    Navigator.pushNamed(
      context,
      '/camera',
      arguments: mealTitle,
    );
  }

  void _showMacroDetails(
    BuildContext context,
    String mealType,
    String foodName,
    int calories,
    double protein,
    double carbs,
    double fat,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mealType,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                foodName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A3A2A),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EDE2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _macroItem('Calories', '$calories kcal', const Color(0xFF5F9735)),
                        _macroItem('Protein', '${protein.toStringAsFixed(1)}g', const Color(0xFFC2482B)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _macroItem('Carbs', '${carbs.toStringAsFixed(1)}g', const Color(0xFFE0A100)),
                        _macroItem('Fat', '${fat.toStringAsFixed(1)}g', const Color(0xFF8B6F47)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _macroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StreakIndicator extends StatelessWidget {
  final int streak;

  const _StreakIndicator({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.04,
        vertical: MediaQuery.of(context).size.height * 0.01,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE0A100),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔥',
            style:
                TextStyle(fontSize: MediaQuery.of(context).size.height * 0.05),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.0025),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.03,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE0A100),
            ),
          ),
          Text(
            'DAY STREAK',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.012,
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