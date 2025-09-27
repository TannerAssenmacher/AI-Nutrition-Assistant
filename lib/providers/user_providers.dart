import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user_profile.dart';

part 'user_providers.g.dart';

// User profile provider
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  UserProfile? build() {
    // Return null initially, will be loaded from storage
    return null;
  }

  void setProfile(UserProfile profile) {
    state = profile;
  }

  void updateProfile(UserProfile updatedProfile) {
    state = updatedProfile;
  }

  void clearProfile() {
    state = null;
  }

  void updateWeight(double newWeight) {
    if (state != null) {
      state = state!.copyWith(weight: newWeight);
    }
  }

  void updateCalorieGoal(int newGoal) {
    if (state != null) {
      state = state!.copyWith(dailyCalorieGoal: newGoal);
    }
  }
}

// Computed provider to check if user has completed profile
@riverpod
bool isProfileComplete(IsProfileCompleteRef ref) {
  final profile = ref.watch(userProfileNotifierProvider);
  return profile != null;
}

// Computed provider for remaining calories
@riverpod
int remainingCalories(RemainingCaloriesRef ref) {
  final profile = ref.watch(userProfileNotifierProvider);
  // We'll need to import the food providers to calculate consumed calories
  // For now, returning a placeholder
  if (profile == null) return 0;
  
  // This would typically calculate: profile.dailyCalorieGoal - consumedCalories
  return profile.dailyCalorieGoal;
}