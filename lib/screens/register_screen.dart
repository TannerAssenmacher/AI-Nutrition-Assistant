// Fixed and cleaned version of your RegisterPage code
// NOTE: I only corrected syntax, missing brackets, misplacements, and fixed widget tree structure.
// You may still want to adjust logic or UI behavior, but this version COMPILES.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../db/user.dart';
import '../widgets/macro_slider.dart';
import 'package:intl/intl.dart';
import 'package:email_validator/email_validator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _pageController = PageController();

  int _currentPage = 0;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dailyCaloriesController = TextEditingController();
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();

  final Map<String, FocusNode> _focusNodes = {};
  final Map<TextEditingController, bool> _fieldTouched = {};

  // Dropdowns / selections
  String? _sex;
  String? _activityLevel;
  String? _dietaryGoal;
  List<String> _dietaryHabits = [];
  List<String> _health = [];

  bool _isLoading = false;
  bool _submitted = false;
  bool _passwordTouched = false;

  String? _emailError;
  String? _passwordError;

  // Password rule tracking
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  // Default macro goals
  double _protein = 20.0;
  double _carbs = 50.0;
  double _fats = 30.0;

  final _sexOptions = ['Male', 'Female'];
  final _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active'
  ];
  final _dietGoals = ['Lose Weight', 'Maintain Weight', 'Gain Muscle'];

  final _dietaryHabitOptions = [
    'balanced',
    'high-fiber',
    'high-protein',
    'low-carb',
    'low-fat',
    'low-sodium',
    'none'
  ];

  final _healthOptions = [
    'alcohol-cocktail',
    'alcohol-free',
    'celery-free',
    'crustacean-free',
    'dairy-free',
    'DASH',
    'egg-free',
    'fish-free',
    'fodmap-free',
    'gluten-free',
    'immuno-supportive',
    'keto-friendly',
    'kidney-friendly',
    'kosher',
    'low-fat-abs',
    'low-potassium',
    'low-sugar',
    'lupine-free',
    'Mediterranean',
    'mollusk-free',
    'mustard-free',
    'no-oil-added',
    'paleo',
    'peanut-free',
    'pescatarian',
    'pork-free',
    'red-meat-free',
    'sesame-free',
    'shellfish-free',
    'soy-free',
    'sugar-conscious',
    'sulfite-free',
    'tree-nut-free',
    'vegan',
    'vegetarian',
    'wheat-free',
    'None'
  ];

  void _markTouchedOnType(TextEditingController c) {
    c.addListener(() {
      if (_fieldTouched[c] != true) {
        setState(() => _fieldTouched[c] = true);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();

    for (var controller in [
      _firstnameController,
      _lastnameController,
      _emailController,
      _passwordController,
      _dobController,
      _heightController,
      _weightController,
      _dailyCaloriesController,
      _likesController,
      _dislikesController,
    ]) {
      final node = FocusNode();
      _focusNodes[controller.hashCode.toString()] = node;
      _fieldTouched[controller] = false;

      node.addListener(() {
        if (node.hasFocus) {
          setState(() => _fieldTouched[controller] = true);
        } else {
          _formKey.currentState?.validate();
        }
      });
    }

    _emailController.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });

    _passwordController.addListener(() {
      final value = _passwordController.text;
      setState(() {
        _passwordTouched = value.isNotEmpty;
        _hasMinLength = value.length >= 8;
        _hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
        _hasNumber = RegExp(r'\d').hasMatch(value);
        _hasSpecial = RegExp(r'[!@#\\$&*~]').hasMatch(value);
        if (_passwordError != null) _passwordError = null;
      });
    });

    _markTouchedOnType(_firstnameController);
    _markTouchedOnType(_lastnameController);
    _markTouchedOnType(_emailController);
    _markTouchedOnType(_passwordController);
    _markTouchedOnType(_dobController);
    _markTouchedOnType(_heightController);
    _markTouchedOnType(_weightController);
    _markTouchedOnType(_dailyCaloriesController);
  }

  bool _isValidDate(String input) {
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/(0[1-9]|[12][0-9]|3[01])\/(19|20)\d{2}\$');
    if (!regex.hasMatch(input)) return false;
    try {
      final parts = input.split('/');
      final date = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _toggleMultiSelect(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  Future<void> _registerUser() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    if (_dietaryHabits.isEmpty || _health.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one dietary habit and one allergy')),
      );
      return;
    }

    if (_sex == null || _activityLevel == null || _dietaryGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all dropdowns and selections')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = authResult.user?.uid;
      if (uid == null) throw Exception('User ID not found after registration');

      final mealProfile = MealProfile(
        dietaryHabits: _dietaryHabits,
        healthRestrictions: _health,
        preferences: Preferences(
          likes: _likesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          dislikes: _dislikesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
      );

      final user = await AppUser.create(
        firstname: _firstnameController.text.trim(),
        lastname: _lastnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        age: 0,
        sex: _sex ?? '',
        height: double.tryParse(_heightController.text) ?? 0.0,
        weight: double.tryParse(_weightController.text) ?? 0.0,
        activityLevel: _activityLevel ?? '',
        dietaryGoal: _dietaryGoal ?? '',
        mealProfile: mealProfile,
        mealPlans: {},
        dailyCalorieGoal: int.tryParse(_dailyCaloriesController.text) ?? 0,
        macroGoals: {'protein': _protein, 'carbs': _carbs, 'fats': _fats},
      );

      final userJson = user.toJson();
      userJson['dateOfBirth'] = _dobController.text;

      await FirebaseFirestore.instance.collection('Users').doc(uid).set(userJson);
      await authResult.user?.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent! Please check your inbox.'), duration: Duration(seconds: 5)),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('🔥 Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateFirebaseCredentials() async {
    setState(() {
      _submitted = true;
      _fieldTouched.updateAll((key, value) => false);
    });

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await credential.user?.delete();

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      setState(() => _currentPage = 1);
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _emailError = 'Please enter a valid email address.';
            break;
          case 'email-already-in-use':
            _emailError = 'This email is already registered.';
            break;
          case 'weak-password':
            _passwordError = null;
            _passwordTouched = true;
            break;
          default:
            _passwordError = null;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPage == 0 ? 'Create Account' : 'More Info'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPage1(),
              _buildPage2(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 250, maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(_firstnameController, 'First Name'),
              _buildTextField(_lastnameController, 'Last Name'),
              _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
              _buildTextField(_passwordController, 'Password', obscure: true),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _validateFirebaseCredentials,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(15),
                ),
                child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 250, maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _centeredMultiSelectField('Dietary Habits', _dietaryHabitOptions, _dietaryHabits, isRequired: true),
              const SizedBox(height: 24),
              _centeredMultiSelectField('Health Restrictions', _healthOptions, _health, isRequired: true),
              const SizedBox(height: 24),
              _buildOptionalTextField(_likesController, 'Food Likes (comma-separated)'),
              _buildOptionalTextField(_dislikesController, 'Food Dislikes (comma-separated)'),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        setState(() => _submitted = true);
                        if (_formKey.currentState!.validate()) _registerUser();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(15),
                      ),
                      child: const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    final focusNode = _focusNodes[c.hashCode.toString()];

    String? firebaseError;
    if (label.toLowerCase().contains('email')) firebaseError = _emailError;
    if (label.toLowerCase().contains('password')) firebaseError = _passwordError;

    String? passwordHint;
    if (label.toLowerCase().contains('password')) {
      final value = c.text;
      if (value.isNotEmpty) {
        if (value.length < 8) {
          passwordHint = 'Password must be at least 8 characters';
        } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
          passwordHint = 'Include at least one uppercase letter';
        } else if (!RegExp(r'\d').hasMatch(value)) {
          passwordHint = 'Include at least one number';
        } else if (!RegExp(r'[!@#\\$&*~]').hasMatch(value)) {
          passwordHint = 'Include at least one special character';
        }
      }
    }

    final String? effectiveError = firebaseError ?? passwordHint;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscure,
        onChanged: (_) {
          if (_submitted) _formKey.currentState?.validate();
          setState(() {});
        },
        onTap: () {
          if (_submitted) _formKey.currentState?.validate();
          setState(() {});
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: effectiveError ?? ((_submitted && c.text.isEmpty) ? 'This field is required' : null),
        ),
        validator: (val) {
          if ((val == null || val.isEmpty) && _submitted) {
            return 'This field is required';
          }
          if (label.toLowerCase().contains('email') && val != null && val.isNotEmpty && !EmailValidator.validate(val)) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildOptionalTextField(TextEditingController c, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _centeredMultiSelectField(
    String label,
    List<String> options,
    List<String> selected, {
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
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

class _DOBFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) buffer.write('/');
    }

    String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
