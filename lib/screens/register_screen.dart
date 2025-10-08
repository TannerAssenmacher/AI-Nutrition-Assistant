import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../db/user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dailyCaloriesController = TextEditingController();
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();

  // Dropdowns / selections
  String? _sex;
  String? _activityLevel;
  String? _dietaryGoal;
  List<String> _dietaryHabits = [];
  List<String> _allergies = [];

  bool _isLoading = false;

  // Default macronutrient goals
  double _protein = 20.0;
  double _carbs = 50.0;
  double _fats = 30.0;

  // Dropdown options
  final _sexOptions = ['Male', 'Female'];
  final _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active'
  ];
  final _dietGoals = ['Lose Weight', 'Maintain Weight', 'Gain Muscle'];
  final _dietaryHabitOptions = [
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Keto',
    'Paleo',
    'None'
  ];
  final _allergyOptions = [
    'Peanuts',
    'Tree Nuts',
    'Dairy',
    'Gluten',
    'Shellfish',
    'Soy',
    'Eggs',
    'None'
  ];

  void _toggleMultiSelect(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sex == null ||
        _activityLevel == null ||
        _dietaryGoal == null ||
        _dietaryHabits.isEmpty ||
        _allergies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all dropdowns and selections')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔹 1. Create Firebase Auth user
      final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = authResult.user?.uid;
      if (uid == null) throw Exception('User ID not found after registration');

      // 🔹 2. Build MealProfile + AppUser
      final mealProfile = MealProfile(
        dietaryHabits: _dietaryHabits,
        allergies: _allergies,
        preferences: Preferences(
          likes: _likesController.text.split(',').map((e) => e.trim()).toList(),
          dislikes: _dislikesController.text.split(',').map((e) => e.trim()).toList(),
        ),
      );

      final user = await AppUser.create(
        firstname: _firstnameController.text.trim(),
        lastname: _lastnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(), // TODO: hash later
        age: int.parse(_ageController.text),
        sex: _sex!,
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        activityLevel: _activityLevel!,
        dietaryGoal: _dietaryGoal!,
        mealProfile: mealProfile,
        mealPlans: {},
        dailyCalorieGoal: int.parse(_dailyCaloriesController.text),
        macroGoals: {
          'protein': _protein,
          'carbs': _carbs,
          'fats': _fats,
        },
      );

      // 🔹 3. Save to Firestore
      await FirebaseFirestore.instance.collection('Users').doc(uid).set(user.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      // 🔹 Log detailed FirebaseAuth error to console
      print('🔥 FirebaseAuthException: ${e.code} → ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth Error: ${e.message ?? e.code}')),
      );
    } on FirebaseException catch (e) {
      // 🔹 Log detailed Firestore error to console
      print('🔥 FirebaseException: ${e.code} → ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database Error: ${e.message ?? e.code}')),
      );
    } catch (e, stack) {
      // 🔹 Log all other unexpected errors
      print('🔥 Unexpected error: $e');
      print('🔍 Stack trace:\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(_firstnameController, 'First Name'),
                _buildTextField(_lastnameController, 'Last Name'),
                _buildTextField(_emailController, 'Email',
                    keyboardType: TextInputType.emailAddress),
                _buildTextField(_passwordController, 'Password', obscure: true),
                _buildTextField(_ageController, 'Age',
                    keyboardType: TextInputType.number),
                _dropdownField('Sex', _sexOptions, (val) => _sex = val),
                _buildTextField(_heightController, 'Height (inches)',
                    keyboardType: TextInputType.number),
                _buildTextField(_weightController, 'Weight (lbs)',
                    keyboardType: TextInputType.number),
                _dropdownField('Activity Level', _activityLevels,
                        (val) => _activityLevel = val),
                _dropdownField('Dietary Goal', _dietGoals,
                        (val) => _dietaryGoal = val),
                _buildTextField(_dailyCaloriesController, 'Daily Calorie Goal',
                    keyboardType: TextInputType.number),

                const SizedBox(height: 20),
                const Text('Macronutrient Goals (% of calories)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),

                // Default macro fields (editable)
                Row(
                  children: [
                    Expanded(
                      child: _macroField('Protein', _protein, (val) {
                        setState(() => _protein = val);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _macroField('Carbs', _carbs, (val) {
                        setState(() => _carbs = val);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _macroField('Fats', _fats, (val) {
                        setState(() => _fats = val);
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _multiSelectField(
                    'Dietary Habits', _dietaryHabitOptions, _dietaryHabits),
                _multiSelectField('Allergies', _allergyOptions, _allergies),
                _buildTextField(_likesController,
                    'Food Likes (comma-separated, e.g. "chicken, rice")'),
                _buildTextField(_dislikesController,
                    'Food Dislikes (comma-separated, e.g. "broccoli, tofu")'),

                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(15),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI helper widgets ---

  Widget _buildTextField(TextEditingController c, String label,
      {TextInputType? keyboardType, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (val) =>
        val == null || val.isEmpty ? 'This field is required' : null,
      ),
    );
  }

  Widget _macroField(String label, double value, Function(double) onChanged) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label (%)',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final val = double.tryParse(v);
        if (val != null) onChanged(val);
      },
      validator: (val) {
        if (val == null || val.isEmpty) return 'Required';
        final n = double.tryParse(val);
        if (n == null || n < 0 || n > 100) return '0–100 only';
        return null;
      },
    );
  }

  Widget _dropdownField(
      String label, List<String> options, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: null,
        onChanged: onChanged,
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        validator: (val) =>
        val == null || val.isEmpty ? 'Please select an option' : null,
      ),
    );
  }

  Widget _multiSelectField(
      String label, List<String> options, List<String> selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Wrap(
            spacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => _toggleMultiSelect(selected, option),
                selectedColor: Colors.green[200],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
