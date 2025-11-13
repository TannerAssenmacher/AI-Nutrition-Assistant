import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'db/user.dart';
import 'db/food.dart';
import 'db/firestore_helper.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load the .env before Firebase
    await dotenv.load(fileName: ".env");

    // Initialize Firebase with better error handling
    await _initializeFirebase();

    // Print all Firestore data once at startup (only if needed)
    await FirestoreHelper.printAllData();
  } catch (e) {
    print("❌ Error during initialization: $e");
    // Continue with app launch even if there's an error
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("✅ Firebase initialized for the first time");
    } else {
      // Firebase already exists, try to get the default app
      try {
        Firebase.app(); // This will throw if no default app exists
        print("✅ Firebase already initialized, using existing instance");
      } catch (e) {
        // If getting the app fails, try to initialize anyway
        print(
            "⚠️ Firebase app exists but couldn't access it, reinitializing...");
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print("✅ Firebase reinitialized successfully");
      }
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      print("✅ Firebase already initialized (duplicate-app error caught)");
      // This is fine, Firebase is already working
    } else {
      print("❌ Firebase initialization failed: ${e.message}");
      rethrow;
    }
  } catch (e) {
    print("❌ Unexpected error during Firebase initialization: $e");
    rethrow;
  }
}

// Layout for successful addition of new user
//==========================================
// final user = AppUser(
//   firstname: "Alice",
//   lastname: "Smith",
//   email: "asmith3@yahoo.com",
//   password: "password123",
//   age: 25,
//   sex: "female",
//   height: 165,
//   weight: 130,
//   activityLevel: "moderate",
//   dietaryGoal: "maintain weight",
//   mealProfile: MealProfile(
//     dietaryHabits: ["vegetarian"],
//     allergies: ["nuts"],
//     preferences: Preferences(
//       likes:  ["cheescake", "salad"],
//       dislikes: ["broccoli"]
//     ),
//   ),
//   mealPlans: {},
//   dailyCalorieGoal: 2000,
//   macroGoals: {"protein": 20.0, "carbs": 50.0, "fats": 30.0},
//   createdAt: DateTime.now(),
//   updatedAt: DateTime.now(),
// );

// Print all Firestore data once at startup
// await FirestoreHelper.createUser(user);

// Example of successful addition of new food item
//==========================================
// final beefSirloin = Food(
//   name: "Beef Sirloin (Grilled)",
//   category: "Protein",
//   caloriesPer100g: 271,
//   proteinPer100g: 25.0,
//   carbsPer100g: 0.0,
//   fatPer100g: 19.0,
//   fiberPer100g: 0.0,
//   micronutrients: Micronutrients(
//     calciumMg: 18,
//     ironMg: 2.6,
//     vitaminAMcg: 0,
//     vitaminCMg: 0,
//   ),
//   source: "USDA",
//   consumedAt: DateTime.now(),
//   servingSize: 85.0, // grams (~3 oz cooked steak)
//   servingCount: 1,
// );
//
// await FirebaseFirestore.instance.collection("Food").doc(beefSirloin.id).set(beefSirloin.toJson());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nutrition Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot': (context) => const ForgotPasswordPage(),
        '/profile': (context) => const ProfilePage(),
        '/home': (context) => const HomeScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
