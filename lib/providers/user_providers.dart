import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/user.dart';
import '../db/firestore_helper.dart';

part 'user_providers.g.dart';

// -----------------------------------------------------------------------------
// USER PROFILE STATE
// -----------------------------------------------------------------------------
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  AppUser? build() {
    // Initially null until loaded from storage or Firestore
    return null;
  }

  /// Set the current user's profile (e.g., after login)
  void setProfile(AppUser profile) {
    state = profile;
  }

  /// Clear the current profile (e.g., logout)
  void clearProfile() {
    state = null;
  }

  /// Update the user's weight locally (and refresh timestamp)
  void updateWeight(double newWeight) {
    if (state != null) {
      state = state!.copyWith(
        weight: newWeight,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Update the user's calorie goal inside the MealProfile
  void updateCalorieGoal(int newGoal) {
    if (state != null) {
      final updatedMealProfile = state!.mealProfile.copyWith(
        dailyCalorieGoal: newGoal,
      );
      state = state!.copyWith(
        mealProfile: updatedMealProfile,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Add a logged food item to the user's in-memory and Firestore data
  Future<void> addFoodItem(FoodItem item) async {
    if (state != null) {
      final updatedList = [...state!.loggedFoodItems, item];
      final updatedUser = state!.copyWith(
        loggedFoodItems: updatedList,
        updatedAt: DateTime.now(),
      );

      state = updatedUser;

      // 🔹 Optionally sync to Firestore
      await FirestoreHelper.addFoodToUser(state!.id, item);
    }
  }

  /// Remove a logged food item (by name + timestamp)
  Future<void> removeFoodItem(FoodItem item) async {
    if (state != null) {
      final updatedList = state!.loggedFoodItems.where((f) {
        return !(f.name == item.name && f.consumedAt == item.consumedAt);
      }).toList();

      final updatedUser = state!.copyWith(
        loggedFoodItems: updatedList,
        updatedAt: DateTime.now(),
      );

      state = updatedUser;

      // 🔹 Optionally sync to Firestore
      await FirestoreHelper.removeFoodFromUser(state!.id, item);
    }
  }

  /// Clear all logged food items (e.g., new day reset)
  Future<void> clearLoggedFoodItems() async {
    if (state != null) {
      final clearedUser = state!.copyWith(
        loggedFoodItems: [],
        updatedAt: DateTime.now(),
      );

      state = clearedUser;

      // 🔹 Optionally sync to Firestore
      await FirestoreHelper.clearLoggedFoods(state!.id);
    }
  }
}

// -----------------------------------------------------------------------------
// COMPUTED PROVIDERS
// -----------------------------------------------------------------------------

/// Check if user profile is complete
@riverpod
bool isProfileComplete(Ref ref) {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return false;

  return profile.firstname.isNotEmpty &&
      profile.lastname.isNotEmpty &&
      profile.height > 0 &&
      profile.weight > 0 &&
      profile.dob != null && profile.dob!.isBefore(DateTime.now()) &&
      profile.mealProfile.dietaryGoal.isNotEmpty;
}

/// Remaining calories provider — dynamically computed from logged foods
@riverpod
int remainingCalories(Ref ref) {
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return 0;

  // Calculate total consumed calories from logged foods
  final consumedCalories = profile.loggedFoodItems.fold<double>(
    0,
        (sum, item) => sum + item.calories_g,
  );

  final dailyGoal = profile.mealProfile.dailyCalorieGoal;

  // Ensure integer return type
  return (dailyGoal - consumedCalories).round();
}

/// Macro goals (protein, carbs, fat) convenience provider
@riverpod
Map<String, double> macroGoals(Ref ref) {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return {};
  return profile.mealProfile.macroGoals;
}
