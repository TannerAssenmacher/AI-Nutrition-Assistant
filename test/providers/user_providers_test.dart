/// Tests for User providers (UserProfileNotifier, isProfileComplete, remainingCalories)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/db/meal_profile.dart';
import 'package:nutrition_assistant/db/preferences.dart';
import 'package:nutrition_assistant/providers/user_providers.dart';
import 'package:nutrition_assistant/providers/food_providers.dart';

void main() {
  late ProviderContainer container;
  late MealProfile mockMealProfile;
  late DateTime testDate;

  setUp(() {
    container = ProviderContainer();
    testDate = DateTime.now();
    mockMealProfile = MealProfile(
      dietaryHabits: ['vegetarian'],
      healthRestrictions: ['peanuts'],
      preferences: Preferences(likes: ['pizza'], dislikes: ['broccoli']),
      macroGoals: {'protein': 150.0, 'carbs': 300.0, 'fat': 70.0},
      dailyCalorieGoal: 2500,
      dietaryGoal: 'muscle_gain',
    );
  });

  tearDown(() {
    container.dispose();
  });

  AppUser createUser({
    String id = 'user_1',
    String firstname = 'John',
    String lastname = 'Doe',
    DateTime? dob,
    String sex = 'male',
    double height = 180,
    double weight = 75,
    String activityLevel = 'lightly_active',
    MealProfile? mealProfile,
  }) {
    return AppUser(
      id: id,
      firstname: firstname,
      lastname: lastname,
      dob: dob ?? DateTime(2000, 1, 1),
      sex: sex,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      mealProfile: mealProfile ?? mockMealProfile,
      createdAt: testDate,
      updatedAt: testDate,
    );
  }

  // ============================================================================
  // USER PROFILE NOTIFIER TESTS
  // ============================================================================
  group('UserProfileNotifier', () {
    test('should initialize with null', () {
      final profile = container.read(userProfileNotifierProvider);
      expect(profile, isNull);
    });

    test('setProfile should set user profile', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile, isNotNull);
      expect(profile!.firstname, 'John');
    });

    test('clearProfile should set profile to null', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);
      notifier.clearProfile();

      final profile = container.read(userProfileNotifierProvider);
      expect(profile, isNull);
    });

    test('updateWeight should update weight and timestamp', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 75);

      notifier.setProfile(user);
      notifier.updateWeight(80);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.weight, 80);
      expect(profile.updatedAt.isAfter(user.updatedAt) ||
          profile.updatedAt.isAtSameMomentAs(user.updatedAt), isTrue);
    });

    test('updateWeight should do nothing if profile is null', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);

      // Should not throw
      notifier.updateWeight(80);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile, isNull);
    });

    test('updateCalorieGoal should update calorie goal', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);
      notifier.updateCalorieGoal(2000);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.mealProfile.dailyCalorieGoal, 2000);
    });

    test('updateCalorieGoal should do nothing if profile is null', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);

      // Should not throw
      notifier.updateCalorieGoal(2000);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile, isNull);
    });

    test('updateCalorieGoal should preserve other meal profile fields', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);
      notifier.updateCalorieGoal(2000);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.mealProfile.dietaryHabits, ['vegetarian']);
      expect(profile.mealProfile.healthRestrictions, ['peanuts']);
      expect(profile.mealProfile.dietaryGoal, 'muscle_gain');
    });

    test('multiple updates should work correctly', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 75);

      notifier.setProfile(user);
      notifier.updateWeight(80);
      notifier.updateCalorieGoal(2000);
      notifier.updateWeight(82);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.weight, 82);
      expect(profile.mealProfile.dailyCalorieGoal, 2000);
    });
  });

  // ============================================================================
  // IS PROFILE COMPLETE PROVIDER TESTS
  // ============================================================================
  group('isProfileComplete Provider', () {
    test('should return false when profile is null', () {
      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return true for complete profile', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(
        firstname: 'John',
        lastname: 'Doe',
        dob: DateTime(2000, 1, 1), // Valid age
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'lightly_active',
      );

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isTrue);
    });

    test('should return false when firstname is empty', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(firstname: '');

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false when lastname is empty', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(lastname: '');

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false when weight is 0', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 0);

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false when height is 0', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(height: 0);

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false when sex is empty', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(sex: '');

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false when activityLevel is empty', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(activityLevel: '');

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false for future DOB (invalid age)', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      // DOB in the future results in age <= 0
      final user = createUser(dob: DateTime.now().add(const Duration(days: 365)));

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return true for user with age of 1', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      // DOB 2 years ago = 2 year old
      final user = createUser(dob: DateTime.now().subtract(const Duration(days: 365 * 2)));

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isTrue);
    });
  });

  // ============================================================================
  // REMAINING CALORIES PROVIDER TESTS
  // ============================================================================
  group('remainingCalories Provider', () {
    test('should return 0 when profile is null', () {
      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, 0);
    });

    test('should return full goal when no food consumed', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final user = createUser(mealProfile: mealProfile);

      notifier.setProfile(user);

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, 2000);
    });

    test('should subtract consumed calories from goal', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      // Add food with 500 calories (100g * 5.0 cal/g)
      foodNotifier.addFoodItem(FoodItem(
        id: 'food_1',
        name: 'Test Food',
        mass_g: 100,
        calories_g: 5.0,
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: DateTime.now(),
      ));

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, 1500); // 2000 - 500
    });

    test('should return negative when over goal', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 1000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      // Add food with 1500 calories
      foodNotifier.addFoodItem(FoodItem(
        id: 'food_1',
        name: 'Big Meal',
        mass_g: 150,
        calories_g: 10.0, // 1500 calories
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'dinner',
        consumedAt: DateTime.now(),
      ));

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, -500); // 1000 - 1500
    });

    test('should only count today\'s food', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      // Add food from yesterday (should not count)
      foodNotifier.addFoodItem(FoodItem(
        id: 'food_yesterday',
        name: 'Yesterday Food',
        mass_g: 100,
        calories_g: 10.0, // 1000 calories
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: DateTime.now().subtract(const Duration(days: 1)),
      ));

      // Add food from today
      foodNotifier.addFoodItem(FoodItem(
        id: 'food_today',
        name: 'Today Food',
        mass_g: 100,
        calories_g: 5.0, // 500 calories
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: DateTime.now(),
      ));

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, 1500); // 2000 - 500 (only today's food)
    });

    test('should update when calorie goal changes', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      expect(container.read(remainingCaloriesProvider), 2000);

      userNotifier.updateCalorieGoal(2500);

      expect(container.read(remainingCaloriesProvider), 2500);
    });

    test('should update when food is added', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      expect(container.read(remainingCaloriesProvider), 2000);

      foodNotifier.addFoodItem(FoodItem(
        id: 'food_1',
        name: 'Food',
        mass_g: 100,
        calories_g: 3.0, // 300 calories
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'snack',
        consumedAt: DateTime.now(),
      ));

      expect(container.read(remainingCaloriesProvider), 1700);
    });
  });

  // ============================================================================
  // EDGE CASES - PROFILE VALIDATION
  // ============================================================================
  group('Profile Validation Edge Cases', () {
    test('should return false for zero height', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(height: 0);

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false for zero weight', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 0);

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false for empty sex', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(sex: '');

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return false for empty activity level', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(activityLevel: '');

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });

    test('should return true for minimal valid profile', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(
        firstname: 'A',
        lastname: 'B',
        dob: DateTime(2000, 1, 1),
        height: 1,
        weight: 1,
        sex: 'x',
        activityLevel: 'a',
      );

      notifier.setProfile(user);

      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isTrue);
    });

    test('should handle future DOB (invalid but model allows)', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(
        dob: DateTime.now().add(const Duration(days: 365)),
      );

      notifier.setProfile(user);

      // Age would be negative/zero - depends on implementation
      final isComplete = container.read(isProfileCompleteProvider);
      expect(isComplete, isFalse);
    });
  });

  // ============================================================================
  // EDGE CASES - WEIGHT UPDATES
  // ============================================================================
  group('Weight Update Edge Cases', () {
    test('should handle very small weight', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 75);

      notifier.setProfile(user);
      notifier.updateWeight(0.1);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.weight, 0.1);
    });

    test('should handle very large weight', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 75);

      notifier.setProfile(user);
      notifier.updateWeight(1000);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.weight, 1000);
    });

    test('should handle decimal weight precision', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 75);

      notifier.setProfile(user);
      notifier.updateWeight(75.5678);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.weight, closeTo(75.5678, 0.0001));
    });

    test('multiple weight updates should track latest', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser(weight: 75);

      notifier.setProfile(user);

      for (int i = 1; i <= 10; i++) {
        notifier.updateWeight(75.0 + i);
      }

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.weight, 85);
    });
  });

  // ============================================================================
  // EDGE CASES - CALORIE GOAL UPDATES
  // ============================================================================
  group('Calorie Goal Edge Cases', () {
    test('should handle zero calorie goal', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);
      notifier.updateCalorieGoal(0);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.mealProfile.dailyCalorieGoal, 0);
    });

    test('should handle very high calorie goal', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);
      notifier.updateCalorieGoal(10000);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.mealProfile.dailyCalorieGoal, 10000);
    });

    test('should handle negative calorie goal (edge case)', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);
      final user = createUser();

      notifier.setProfile(user);
      notifier.updateCalorieGoal(-100);

      final profile = container.read(userProfileNotifierProvider);
      expect(profile!.mealProfile.dailyCalorieGoal, -100);
    });
  });

  // ============================================================================
  // EDGE CASES - REMAINING CALORIES CALCULATIONS
  // ============================================================================
  group('Remaining Calories Edge Cases', () {
    test('should handle negative remaining (overate)', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 1000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      // Add 1500 calories of food (over the goal)
      foodNotifier.addFoodItem(FoodItem(
        id: 'food_1',
        name: 'Big Meal',
        mass_g: 100,
        calories_g: 15.0, // 1500 calories
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: DateTime.now(),
      ));

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, -500); // 1000 - 1500
    });

    test('should handle exactly meeting goal', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 500);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      foodNotifier.addFoodItem(FoodItem(
        id: 'food_1',
        name: 'Exact Meal',
        mass_g: 100,
        calories_g: 5.0, // 500 calories
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: DateTime.now(),
      ));

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, 0);
    });

    test('should handle many small meals', () {
      final userNotifier = container.read(userProfileNotifierProvider.notifier);
      final foodNotifier = container.read(foodLogProvider.notifier);

      final mealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final user = createUser(mealProfile: mealProfile);
      userNotifier.setProfile(user);

      // Add 10 meals of 100 calories each
      for (int i = 0; i < 10; i++) {
        foodNotifier.addFoodItem(FoodItem(
          id: 'food_$i',
          name: 'Snack $i',
          mass_g: 100,
          calories_g: 1.0, // 100 calories
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: 'snack',
          consumedAt: DateTime.now(),
        ));
      }

      final remaining = container.read(remainingCaloriesProvider);
      expect(remaining, 1000); // 2000 - (10 * 100)
    });
  });

  // ============================================================================
  // EDGE CASES - PROFILE LIFECYCLE
  // ============================================================================
  group('Profile Lifecycle Edge Cases', () {
    test('should handle set-clear-set cycle', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);

      // First set
      notifier.setProfile(createUser(firstname: 'First'));
      expect(container.read(userProfileNotifierProvider)?.firstname, 'First');

      // Clear
      notifier.clearProfile();
      expect(container.read(userProfileNotifierProvider), isNull);

      // Second set
      notifier.setProfile(createUser(firstname: 'Second'));
      expect(container.read(userProfileNotifierProvider)?.firstname, 'Second');
    });

    test('should handle replacing profile', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);

      notifier.setProfile(createUser(firstname: 'Original'));
      notifier.setProfile(createUser(firstname: 'Replacement'));

      final profile = container.read(userProfileNotifierProvider);
      expect(profile?.firstname, 'Replacement');
    });

    test('should handle updates after clear gracefully', () {
      final notifier = container.read(userProfileNotifierProvider.notifier);

      notifier.setProfile(createUser());
      notifier.clearProfile();

      // These should not throw
      notifier.updateWeight(80);
      notifier.updateCalorieGoal(2500);

      expect(container.read(userProfileNotifierProvider), isNull);
    });
  });
}
