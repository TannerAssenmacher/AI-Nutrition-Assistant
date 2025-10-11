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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env before Firebase
  await dotenv.load(fileName: ".env");

  // Print one variable to confirm
  print("✅ Loaded GOOGLE_API_KEY_ANDROID: ${dotenv.env['GOOGLE_API_KEY_ANDROID']}");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  await FirestoreHelper.printAllData();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

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
          '/home': (context) => const HomeScreen(),
        },
    );
  }
}
