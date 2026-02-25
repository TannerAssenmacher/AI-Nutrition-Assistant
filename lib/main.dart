import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
//import 'db/user.dart';
//import 'db/food.dart';
import 'screens/login_screen.dart';
import 'theme/app_colors.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/profile_screen.dart';
import 'navigation/nav_helper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initial page route if no user is logged in.
  String initialRoute = '/login';

  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Initialize Firebase with better error handling
    await _initializeFirebase();
    await _activateFirebaseAppCheck();

    // Initialize notification service
    await NotificationService.initialize();

    // Schedule daily reminders
    await NotificationService.scheduleStreakReminder();
    await NotificationService.scheduleMacroCheckReminder();

    // On web, Firebase restores auth state from IndexedDB asynchronously.
    // Reading currentUser synchronously can return null even when the user IS
    // authenticated, causing the app to incorrectly land on /login and then
    // show a stuck spinner on the home screen after the email-verification
    // redirect.  Awaiting the first authStateChanges() emission gives Firebase
    // time to hydrate its state before we decide the initial route.
    User? currentUser;
    try {
      currentUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Timeout or stream error – fall back to the synchronous cache.
      currentUser = FirebaseAuth.instance.currentUser;
    }

    // After an email-confirmation redirect the cached token may still carry
    // emailVerified=false.  A reload() fetches the latest claim from the
    // server so the route decision is always based on fresh state.
    if (currentUser != null && !currentUser.isAnonymous) {
      try {
        await currentUser.reload();
        currentUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        // If reload fails (e.g. offline), proceed with cached state.
      }
    }

    // If we have a verified user or a persisted anonymous user, skip login.
    if (currentUser != null &&
        (currentUser.emailVerified || currentUser.isAnonymous)) {
      initialRoute = '/home';
    }

    // Print all Firestore data once at startup (only if needed)
    // await FirestoreHelper.printAllData(); // Commented out to reduce terminal output
  } catch (e) {
    print("Error during initialization: $e");
    // Continue with app launch even if there's an error
  }

  runApp(ProviderScope(child: MyApp(initialRoute: initialRoute)));
}

Future<void> _initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Firebase initialized for the first time");
    } else {
      // Firebase already exists, try to get the default app
      try {
        Firebase.app(); // This will throw if no default app exists
        print("Firebase already initialized, using existing instance");
      } catch (e) {
        // If getting the app fails, try to initialize anyway
        print("Firebase app exists but couldn't access it, reinitializing...");
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print("Firebase reinitialized successfully");
      }
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      print("Firebase already initialized (duplicate-app error caught)");
      // This is fine, Firebase is already working
    } else {
      print("Firebase initialization failed: ${e.message}");
      rethrow;
    }
  } catch (e) {
    print("Unexpected error during Firebase initialization: $e");
    rethrow;
  }
}

Future<void> _activateFirebaseAppCheck() async {
  const enableAppCheck = bool.fromEnvironment(
    'ENABLE_APP_CHECK',
    defaultValue: kReleaseMode,
  );
  if (!enableAppCheck) {
    debugPrint('Firebase App Check disabled (ENABLE_APP_CHECK=false).');
    return;
  }

  const webRecaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_V3_SITE_KEY',
    defaultValue: '',
  );

  try {
    if (kIsWeb && webRecaptchaSiteKey.isEmpty) {
      debugPrint(
        'Firebase App Check skipped on web: set --dart-define=RECAPTCHA_V3_SITE_KEY=...',
      );
      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleDeviceCheckProvider()
          : const AppleDebugProvider(),
      providerWeb: kIsWeb ? ReCaptchaV3Provider(webRecaptchaSiteKey) : null,
    );
    debugPrint('Firebase App Check activated');
  } catch (e) {
    debugPrint('Firebase App Check activation failed: $e');
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
  const MyApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nutrition Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot': (context) => const ForgotPasswordPage(),
        '/home': (context) =>
            const MainNavigationScreen(initialIndex: navIndexHome),
        '/chat': (context) =>
            const MainNavigationScreen(initialIndex: navIndexChat),
        '/calendar': (context) =>
            const MainNavigationScreen(initialIndex: navIndexHistory),
        '/camera': (context) =>
            const MainNavigationScreen(initialIndex: navIndexCamera),
        '/search': (context) =>
            const MainNavigationScreen(initialIndex: navIndexSearch),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
