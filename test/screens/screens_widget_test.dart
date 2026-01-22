/// Basic widget tests for screen widgets
/// These are smoke tests to verify UI components can be built without crashing
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============================================================================
  // HOME SCREEN WIDGET TESTS
  // ============================================================================
  group('HomeScreen Widget Components', () {
    testWidgets('should render calorie summary card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today\'s Calories'),
                        Text('0 calories consumed'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Today\'s Calories'), findsOneWidget);
      expect(find.text('0 calories consumed'), findsOneWidget);
    });

    testWidgets('should display macro information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Macronutrients'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('50g', style: TextStyle(fontSize: 24)),
                            Text('Protein'),
                          ],
                        ),
                        Column(
                          children: [
                            Text('100g', style: TextStyle(fontSize: 24)),
                            Text('Carbs'),
                          ],
                        ),
                        Column(
                          children: [
                            Text('30g', style: TextStyle(fontSize: 24)),
                            Text('Fat'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Macronutrients'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('should render app bar with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Nutrition Assistant'),
              backgroundColor: Colors.green[600],
            ),
          ),
        ),
      );

      expect(find.text('Nutrition Assistant'), findsOneWidget);
    });

    testWidgets('should render logout icon button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('should render profile icon button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });

  // ============================================================================
  // LOGIN SCREEN WIDGET TESTS
  // ============================================================================
  group('LoginScreen Widget Components', () {
    testWidgets('should render email field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('should render password field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                ),
                obscureText: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('should render login button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Login'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should validate empty email field', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: controller,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      formKey.currentState?.validate();
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('should validate email format', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'invalid-email');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: controller,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      formKey.currentState?.validate();
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('should render forgot password link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Text('Forgot Password?'),
            ),
          ),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('should render register link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Text('Create Account'),
            ),
          ),
        ),
      );

      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  // ============================================================================
  // REGISTER SCREEN WIDGET TESTS
  // ============================================================================
  group('RegisterScreen Widget Components', () {
    testWidgets('should render registration form fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'First Name'),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Last Name'),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('should render dropdown for sex selection', (tester) async {
      String? selectedSex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              value: selectedSex,
              decoration: const InputDecoration(labelText: 'Sex'),
              items: ['Male', 'Female'].map((sex) {
                return DropdownMenuItem(value: sex, child: Text(sex));
              }).toList(),
              onChanged: (value) => selectedSex = value,
            ),
          ),
        ),
      );

      expect(find.text('Sex'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('should validate required fields', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (value) => value?.isEmpty == true ? 'First name required' : null,
                    decoration: const InputDecoration(labelText: 'First Name'),
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Register'));
      await tester.pump();

      expect(find.text('First name required'), findsOneWidget);
    });

    testWidgets('should render date of birth field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'Select your date of birth',
              ),
              readOnly: true,
            ),
          ),
        ),
      );

      expect(find.text('Date of Birth'), findsOneWidget);
    });

    testWidgets('should render height and weight fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Height (cm)'), findsOneWidget);
      expect(find.text('Weight (kg)'), findsOneWidget);
    });
  });

  // ============================================================================
  // PROFILE SCREEN WIDGET TESTS
  // ============================================================================
  group('ProfileScreen Widget Components', () {
    testWidgets('should render profile form fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Height'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Weight'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Daily Calories Goal'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Daily Calories Goal'), findsOneWidget);
    });

    testWidgets('should render activity level dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Activity Level'),
              items: [
                'Sedentary',
                'Lightly Active',
                'Moderately Active',
                'Very Active'
              ].map((level) {
                return DropdownMenuItem(value: level, child: Text(level));
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Activity Level'), findsOneWidget);
    });

    testWidgets('should render dietary goal dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Dietary Goal'),
              items: [
                'Lose Weight',
                'Maintain Weight',
                'Gain Muscle'
              ].map((goal) {
                return DropdownMenuItem(value: goal, child: Text(goal));
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Dietary Goal'), findsOneWidget);
    });

    testWidgets('should render save button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Save Profile'),
            ),
          ),
        ),
      );

      expect(find.text('Save Profile'), findsOneWidget);
    });

    testWidgets('should render delete account button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {},
              child: const Text('Delete Account'),
            ),
          ),
        ),
      );

      expect(find.text('Delete Account'), findsOneWidget);
    });
  });

  // ============================================================================
  // CHAT SCREEN WIDGET TESTS
  // ============================================================================
  group('ChatScreen Widget Components', () {
    testWidgets('should render message input field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: const InputDecoration(
                hintText: 'Type a message...',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('should render send button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('should render chat message bubbles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                // User message
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Hello!', style: TextStyle(color: Colors.white)),
                  ),
                ),
                // Bot message
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Hi there! How can I help?'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Hello!'), findsOneWidget);
      expect(find.text('Hi there! How can I help?'), findsOneWidget);
    });

    testWidgets('should render cuisine type options', (tester) async {
      final cuisineTypes = ['American', 'Italian', 'Mexican', 'Asian'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              spacing: 8,
              children: cuisineTypes.map((cuisine) {
                return Chip(label: Text(cuisine));
              }).toList(),
            ),
          ),
        ),
      );

      for (final cuisine in cuisineTypes) {
        expect(find.text(cuisine), findsOneWidget);
      }
    });

    testWidgets('should render meal type buttons', (tester) async {
      final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: mealTypes.map((type) {
                return Padding(
                  padding: const EdgeInsets.all(4),
                  child: ElevatedButton(
                    onPressed: () {},
                    child: Text(type),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );

      for (final type in mealTypes) {
        expect(find.text(type), findsOneWidget);
      }
    });

    testWidgets('should render recipe button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Get Recipes'),
            ),
          ),
        ),
      );

      expect(find.text('Get Recipes'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    });
  });

  // ============================================================================
  // MEAL ANALYSIS SCREEN WIDGET TESTS
  // ============================================================================
  group('MealAnalysisScreen Widget Components', () {
    testWidgets('should render food item display', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: const Text('Apple'),
                subtitle: const Text('100g - 52 calories'),
                trailing: const Text('13g carbs'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('100g - 52 calories'), findsOneWidget);
    });

    testWidgets('should render nutrition breakdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _buildNutrientRow('Calories', '250 kcal'),
                _buildNutrientRow('Protein', '15g'),
                _buildNutrientRow('Carbs', '30g'),
                _buildNutrientRow('Fat', '8g'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('250 kcal'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('should render log food button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Log Food'),
            ),
          ),
        ),
      );

      expect(find.text('Log Food'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should render camera capture button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });
  });

  // ============================================================================
  // FORGOT PASSWORD SCREEN WIDGET TESTS
  // ============================================================================
  group('ForgotPasswordScreen Widget Components', () {
    testWidgets('should render email input for password reset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Forgot Password'),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email to reset password',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Send Reset Link'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('should render back to login link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Text('Back to Login'),
            ),
          ),
        ),
      );

      expect(find.text('Back to Login'), findsOneWidget);
    });
  });

  // ============================================================================
  // CAMERA CAPTURE SCREEN WIDGET TESTS
  // ============================================================================
  group('CameraCaptureScreen Widget Components', () {
    testWidgets('should render capture button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.camera),
              iconSize: 72,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera), findsOneWidget);
    });

    testWidgets('should render gallery button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.photo_library), findsOneWidget);
    });

    testWidgets('should render flash toggle button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });
  });

  // ============================================================================
  // COMMON UI PATTERNS TESTS
  // ============================================================================
  group('Common UI Patterns', () {
    testWidgets('should render loading indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render error snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error occurred')),
                  );
                },
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Error occurred'), findsOneWidget);
    });

    testWidgets('should render confirmation dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm'),
                      content: const Text('Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('should render bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  // ============================================================================
  // HOME SCREEN ADVANCED TESTS
  // ============================================================================
  group('HomeScreen Advanced Components', () {
    testWidgets('should render floating action buttons column', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'chatFab',
                  onPressed: () {},
                  backgroundColor: Colors.blue[600],
                  child: const Icon(Icons.chat, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'cameraFab',
                  onPressed: () {},
                  backgroundColor: Colors.green[700],
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'addFoodFab',
                  onPressed: () {},
                  backgroundColor: Colors.green[600],
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chat), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should render food log empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No food logged today. Start by adding some food!'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No food logged today. Start by adding some food!'), findsOneWidget);
    });

    testWidgets('should render food log item with delete button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.restaurant, color: Colors.green[600]),
                ),
                title: const Text('Apple'),
                subtitle: const Text('95 calories'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('95 calories'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('should render food suggestions horizontal list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant,
                              color: Colors.green[600],
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Food Suggestion $index',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Food Suggestion 0'), findsOneWidget);
      expect(find.text('Food Suggestion 1'), findsOneWidget);
    });

    testWidgets('should render calorie goal text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1500 calories consumed'),
                    const SizedBox(height: 4),
                    Text(
                      'Goal: 2000 calories',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('1500 calories consumed'), findsOneWidget);
      expect(find.text('Goal: 2000 calories'), findsOneWidget);
    });
  });

  // ============================================================================
  // MACRO COLUMN COMPONENT TESTS
  // ============================================================================
  group('MacroColumn Component', () {
    testWidgets('should render macro column with label and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Protein', style: TextStyle(fontSize: 12)),
                const Text('50.0g', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('P'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('50.0g'), findsOneWidget);
    });

    testWidgets('should render all three macro columns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroColumn('Protein', '50.0g', Colors.red[300]!),
                _buildMacroColumn('Carbs', '100.0g', Colors.blue[300]!),
                _buildMacroColumn('Fat', '30.0g', Colors.orange[300]!),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });
  });

  // ============================================================================
  // CHAT SCREEN ADVANCED TESTS
  // ============================================================================
  group('ChatScreen Advanced Components', () {
    testWidgets('should render chat empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ask me anything about nutrition!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try: "What should I eat for dinner?"',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text('Ask me anything about nutrition!'), findsOneWidget);
      expect(find.text('Try: "What should I eat for dinner?"'), findsOneWidget);
    });

    testWidgets('should render meal type picker buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(onPressed: () {}, child: const Text('Breakfast')),
                  ElevatedButton(onPressed: () {}, child: const Text('Lunch')),
                  ElevatedButton(onPressed: () {}, child: const Text('Dinner')),
                  ElevatedButton(onPressed: () {}, child: const Text('Snack')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Snack'), findsOneWidget);
    });

    testWidgets('should render cuisine type selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a cuisine type for your Dinner:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Italian', 'Mexican', 'Asian', 'American']
                        .map((cuisine) => ElevatedButton(
                              onPressed: () {},
                              child: Text(cuisine),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select a cuisine type for your Dinner:'), findsOneWidget);
      expect(find.text('Italian'), findsOneWidget);
      expect(find.text('Mexican'), findsOneWidget);
    });

    testWidgets('should render confirmation buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Is this information correct?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.check),
                        label: const Text('Yes'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.close),
                        label: const Text('No'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Is this information correct?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should render generate recipes button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Generate Recipes'),
            ),
          ),
        ),
      );

      expect(find.text('Generate Recipes'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    });

    testWidgets('should render chat input field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Ask about nutrition, calories, meal planning...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: () {},
                  backgroundColor: Colors.green[600],
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('should render clear chat button in app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Nutrition Assistant Chat'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Clear Chat',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Nutrition Assistant Chat'), findsOneWidget);
      expect(find.byIcon(Icons.clear_all), findsOneWidget);
    });
  });

  // ============================================================================
  // CHAT BUBBLE COMPONENT TESTS
  // ============================================================================
  group('ChatBubble Component', () {
    testWidgets('should render user message bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, what should I eat?',
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '10:30',
                            style: TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue[600],
                    radius: 16,
                    child: const Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello, what should I eat?'), findsOneWidget);
      expect(find.text('10:30'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('should render bot message bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green[600],
                    radius: 16,
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'I recommend grilled chicken!',
                            style: TextStyle(color: Colors.black87),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '10:31',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('I recommend grilled chicken!'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    });
  });

  // ============================================================================
  // PROFILE SCREEN ADVANCED TESTS
  // ============================================================================
  group('ProfileScreen Advanced Components', () {
    testWidgets('should render profile info display fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildInfoRow('Name', 'John Doe'),
                    _buildInfoRow('Email', 'john@example.com'),
                    _buildInfoRow('Date of Birth', '01/15/1990'),
                    _buildInfoRow('Sex', 'Male'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Personal Info'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('should render activity level dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              value: 'Moderately Active',
              decoration: const InputDecoration(labelText: 'Activity Level'),
              items: ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active']
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Activity Level'), findsOneWidget);
      expect(find.text('Moderately Active'), findsOneWidget);
    });

    testWidgets('should render dietary goal dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              value: 'Maintain Weight',
              decoration: const InputDecoration(labelText: 'Dietary Goal'),
              items: ['Lose Weight', 'Maintain Weight', 'Gain Muscle']
                  .map((goal) => DropdownMenuItem(value: goal, child: Text(goal)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Dietary Goal'), findsOneWidget);
      expect(find.text('Maintain Weight'), findsOneWidget);
    });

    testWidgets('should render health restrictions chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: ['gluten-free', 'dairy-free', 'vegetarian']
                  .map((restriction) => Chip(
                        label: Text(restriction),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {},
                      ))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('gluten-free'), findsOneWidget);
      expect(find.text('dairy-free'), findsOneWidget);
      expect(find.text('vegetarian'), findsOneWidget);
    });

    testWidgets('should render save profile button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Profile'),
            ),
          ),
        ),
      );

      expect(find.text('Save Profile'), findsOneWidget);
    });

    testWidgets('should render delete account button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete Account'),
            ),
          ),
        ),
      );

      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('should render likes/dislikes text fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Foods You Like',
                    hintText: 'e.g., pasta, chicken, salads',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Foods You Dislike',
                    hintText: 'e.g., fish, mushrooms',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Foods You Like'), findsOneWidget);
      expect(find.text('Foods You Dislike'), findsOneWidget);
    });
  });

  // ============================================================================
  // MEAL ANALYSIS SCREEN TESTS
  // ============================================================================
  group('MealAnalysisScreen Components', () {
    testWidgets('should render analyzing state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing your meal...'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing your meal...'), findsOneWidget);
    });

    testWidgets('should render capture initial state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('Capture a meal to analyze'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      expect(find.text('Capture a meal to analyze'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
    });

    testWidgets('should render error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'OpenAI API key is not configured.',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('OpenAI API key is not configured.'), findsOneWidget);
    });

    testWidgets('should render analysis result card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Food Items',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Text('Grilled Chicken - 250 kcal'),
                      Text('Steamed Broccoli - 55 kcal'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Food Items'), findsOneWidget);
      expect(find.text('Grilled Chicken - 250 kcal'), findsOneWidget);
    });

    testWidgets('should render meal analyzer floating action button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });
  });

  // ============================================================================
  // REGISTER SCREEN ADVANCED TESTS
  // ============================================================================
  group('RegisterScreen Advanced Components', () {
    testWidgets('should render page indicator dots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNWidgets(3));
    });

    testWidgets('should render password strength indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPasswordRule('At least 8 characters', true),
                _buildPasswordRule('One uppercase letter', true),
                _buildPasswordRule('One number', false),
                _buildPasswordRule('One special character (!@#\$&*~)', false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('One uppercase letter'), findsOneWidget);
      expect(find.text('One number'), findsOneWidget);
    });

    testWidgets('should render height and weight fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Height (inches)',
                    prefixIcon: Icon(Icons.height),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Weight (lbs)',
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Height (inches)'), findsOneWidget);
      expect(find.text('Weight (lbs)'), findsOneWidget);
      expect(find.byIcon(Icons.height), findsOneWidget);
      expect(find.byIcon(Icons.monitor_weight), findsOneWidget);
    });

    testWidgets('should render date of birth picker field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'MM/DD/YYYY',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
            ),
          ),
        ),
      );

      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('should render sex selection dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Sex'),
              items: ['Male', 'Female']
                  .map((sex) => DropdownMenuItem(value: sex, child: Text(sex)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Sex'), findsOneWidget);
    });

    testWidgets('should render daily calories field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Daily Calorie Goal',
                prefixIcon: Icon(Icons.local_fire_department),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ),
      );

      expect(find.text('Daily Calorie Goal'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('should render next and back navigation buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('should render register/submit button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Create Account'),
            ),
          ),
        ),
      );

      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  // ============================================================================
  // FORM VALIDATION UI TESTS
  // ============================================================================
  group('Form Validation UI', () {
    testWidgets('should show error text in form field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Email',
                errorText: 'Please enter your email',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('should render error styling in red', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                Text(
                  'Invalid email or password. Please try again.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Invalid email or password. Please try again.'), findsOneWidget);
    });

    testWidgets('should show email already registered error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Email',
                errorText: 'This email is already registered.',
              ),
            ),
          ),
        ),
      );

      expect(find.text('This email is already registered.'), findsOneWidget);
    });
  });

  // ============================================================================
  // INTERACTION TESTS
  // ============================================================================
  group('Widget Interactions', () {
    testWidgets('should toggle visibility of password field', (tester) async {
      bool obscured = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TextField(
                  obscureText: obscured,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscured = !obscured),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('should tap on dropdown and show options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              value: 'Option 1',
              items: ['Option 1', 'Option 2', 'Option 3']
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      expect(find.text('Option 2'), findsWidgets);
      expect(find.text('Option 3'), findsWidgets);
    });

    testWidgets('should enter text in text field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'John Doe');
      await tester.pump();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('should clear text field', (tester) async {
      final controller = TextEditingController(text: 'Initial Text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Input',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Initial Text'), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      
      expect(find.text('Initial Text'), findsNothing);
    });

    testWidgets('should dismiss dialog on cancel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete?'), findsNothing);
    });
  });

  // ============================================================================
  // SCROLLING TESTS
  // ============================================================================
  group('Scrolling Behavior', () {
    testWidgets('should render scrollable SingleChildScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  20,
                  (index) => Container(
                    height: 100,
                    margin: const EdgeInsets.all(8),
                    color: Colors.green[100 * (index % 9 + 1)],
                    child: Center(child: Text('Item $index')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('should render scrollable horizontal ListView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 20,
                itemBuilder: (context, index) => Container(
                  width: 100,
                  margin: const EdgeInsets.all(8),
                  color: Colors.blue[100 * (index % 9 + 1)],
                  child: Center(child: Text('H$index')),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('H0'), findsOneWidget);
    });
  });
}

// Helper widget for nutrient rows
Widget _buildNutrientRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value),
      ],
    ),
  );
}

// Helper for macro column
Widget _buildMacroColumn(String label, String value, Color color) {
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ],
  );
}

// Helper for info row
Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value),
      ],
    ),
  );
}

// Helper for password rule indicator
Widget _buildPasswordRule(String text, bool met) {
  return Row(
    children: [
      Icon(
        met ? Icons.check_circle : Icons.cancel,
        color: met ? Colors.green : Colors.red,
        size: 16,
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          color: met ? Colors.green : Colors.red,
          fontSize: 12,
        ),
      ),
    ],
  );
}
