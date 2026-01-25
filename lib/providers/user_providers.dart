import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/user.dart';
import 'food_providers.dart';

part 'user_providers.g.dart';

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  AppUser? build() {
    // Initially null (user not loaded yet)
    return null;
  }

  void setProfile(AppUser profile) {
    state = profile;
  }

  void clearProfile() {
    state = null;
  }

  void updateWeight(double newWeight) {
    if (state == null) return;

    state = state!.copyWith(
      weight: newWeight,
      updatedAt: DateTime.now(),
    );
  }

  void updateCalorieGoal(int newGoal) {
    if (state == null) return;

    state = state!.copyWith(
      mealProfile: state!.mealProfile.copyWith(
        dailyCalorieGoal: newGoal,
      ),
      updatedAt: DateTime.now(),
    );
  }
}

// Helper to compute age from DOB
int _ageFromDob(DateTime dob) {
  final now = DateTime.now();
  int age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age;
}

// Checks if user profile contains empty fields
@riverpod
bool isProfileComplete(Ref ref) {
  final profile = ref.watch(userProfileNotifierProvider);

  if (profile == null) return false;

  return profile.firstname.isNotEmpty &&
      profile.lastname.isNotEmpty &&
      _ageFromDob(profile.dob) > 0 &&
      profile.weight > 0 &&
      profile.height > 0 &&
      profile.sex.isNotEmpty &&
      profile.activityLevel.isNotEmpty;
}

// Returns calories left until daily goal is met
@riverpod
int remainingCalories(Ref ref) {
  final profile = ref.watch(userProfileNotifierProvider);
  final consumed = ref.watch(totalDailyCaloriesProvider);

  if (profile == null) return 0;

  final goal = profile.mealProfile.dailyCalorieGoal;
  return (goal - consumed).toInt();
}