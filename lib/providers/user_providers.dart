import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/user.dart';
import 'food_providers.dart';

part 'user_providers.g.dart';

// User profile provider
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  AppUser? build() {
    // Return null initially, will be loaded from storage
    return null;
  }

  void setProfile(AppUser profile) {
    state = profile;
  }

  void clearProfile() {
    state = null;
  }

  void updateWeight(double newWeight) {
    if (state != null) {}
  }

  void updateCalorieGoal(int newGoal) {
    if (state != null) {}
  }
}

// Computed provider to check if user has completed profile
@riverpod
bool isProfileComplete(Ref ref) {
  final profile = ref.watch(userProfileNotifierProvider);
  return profile != null &&
      profile.firstname.isNotEmpty &&
      profile.age > 0 &&
      profile.weight > 0 &&
      profile.height > 0;
}

// Computed provider for remaining calories
@riverpod
int remainingCalories(Ref ref) {
  final profile = ref.watch(userProfileNotifierProvider);
  final consumedCalories = ref.watch(totalDailyCaloriesProvider);
  if (profile == null) return 0;

  return profile.dailyCalorieGoal - consumedCalories;
}
