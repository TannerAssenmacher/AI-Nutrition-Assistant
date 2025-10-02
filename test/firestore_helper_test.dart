import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// Change ai_nutrition_assistant to your pubspec's "name:" if different
import 'package:ai_nutrition_assistant/db/firestore_helper.dart';
import 'package:ai_nutrition_assistant/db/user.dart';
import 'package:ai_nutrition_assistant/db/food.dart';

void main() {
  setUp(() {
    // Inject a fresh in-memory Firestore per test
    FirestoreHelper.useDb(FakeFirebaseFirestore());
  });

  test('create & fetch user works', () async {
    final user = User(
      id: 'user_123',
      firstname: 'John',
      lastname: 'Doe',
      email: 'jd@gmail.com',
      password: 'hashed_pw',
      age: 25,
      sex: 'male',
      height: 180,
      weight: 75,
      activityLevel: 'lightly_active',
      dietaryGoal: 'muscle_gain',
      mealProfile: MealProfile(
        dietaryHabits: ['vegetarian'],
        allergies: ['peanuts'],
        preferences: Preferences(likes: ['rice'], dislikes: ['mushrooms']),
      ),
      mealPlans: {},
    );

    await FirestoreHelper.createUser(user);

    final fetched = await FirestoreHelper.getUser('user_123');
    expect(fetched, isNotNull);
    expect(fetched!.email, 'jd@gmail.com');
    expect(fetched.mealProfile.dietaryHabits, contains('vegetarian'));
  });

  test('update user fails if not exists', () async {
    final ghost = User(
      id: 'nope',
      firstname: 'X',
      lastname: 'Y',
      email: 'x@y.com',
      password: 'p',
      age: 1,
      sex: 'n/a',
      height: 1,
      weight: 1,
      activityLevel: 'none',
      dietaryGoal: 'none',
      mealProfile: MealProfile(
        dietaryHabits: [],
        allergies: [],
        preferences: Preferences(likes: [], dislikes: []),
      ),
      mealPlans: {},
    );

    expect(
          () => FirestoreHelper.updateUser(ghost),
      throwsA(isA<StateError>()),
    );
  });

  test('create & fetch food with micronutrients', () async {
    final food = Food(
      id: 'broccoli_002',
      name: 'Broccoli',
      category: 'vegetable',
      caloriesPer100g: 55,
      proteinPer100g: 3.7,
      carbsPer100g: 11.2,
      fatPer100g: 0.6,
      fiberPer100g: 3.8,
      micronutrients: Micronutrients(
        calciumMg: 47,
        ironMg: 0.7,
        vitaminAMcg: 623,
        vitaminCMg: 89,
      ),
      source: 'USDA FoodData Central',
    );

    await FirestoreHelper.createFood(food);
    final fetched = await FirestoreHelper.getFood('broccoli_002');

    expect(fetched, isNotNull);
    expect(fetched!.micronutrients.calciumMg, 47);
    expect(fetched.micronutrients.vitaminCMg, 89);
  });

  test('delete food removes doc', () async {
    final food = Food(
      id: 'chicken_001',
      name: 'Chicken Breast',
      category: 'protein',
      caloriesPer100g: 165,
      proteinPer100g: 31,
      carbsPer100g: 0,
      fatPer100g: 3.6,
      fiberPer100g: 0,
      micronutrients: Micronutrients(
        calciumMg: 15,
        ironMg: 0.9,
        vitaminAMcg: 13,
        vitaminCMg: 0,
      ),
      source: 'USDA FoodData Central',
    );

    await FirestoreHelper.createFood(food);
    await FirestoreHelper.deleteFood('chicken_001');
    final exists = await FirestoreHelper.foodExists('chicken_001');

    expect(exists, isFalse);
  });
}
