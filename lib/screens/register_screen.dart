import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../db/user.dart';
import '../db/meal_profile.dart';
import '../db/preferences.dart';
import '../widgets/macro_slider.dart';
import 'package:intl/intl.dart';
import 'package:email_validator/email_validator.dart';
import '../widgets/top_bar.dart';
import '../theme/app_colors.dart';

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

  //default values
  int? _heightFeet = 5;    
  int? _heightInches = 6;  

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

  // Focus + touched tracking
  final Map<TextEditingController, FocusNode> _focusMap = {};
  final Map<TextEditingController, bool> _fieldTouched = {};

  // Dropdowns / selections
  String? _sex;
  String? _activityLevel;
  String? _dietaryGoal;
  List<String> _dietaryHabits = [];
  List<String> _health = [];

  bool _isLoading = false;
  bool _submitted = false;
  String? _emailError; // live email duplication / format error
  String? _passwordError; // firebase weak-password, etc.

  // Password live rules
  bool _passwordTouched = false;
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  // Email debounce
  Timer? _emailDebounce;

  // Macros
  double _protein = 30.0;
  double _carbs = 40.0;
  double _fats = 30.0;

  // Dropdown options
  final _sexOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
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
    'low-sodium'
  ];
  final _healthOptions = [
    'vegan',
    'vegetarian',
    'gluten free',
    'dairy free',
    'ketogenic',
    'lacto-vegetarian',
    'ovo-vegetarian',
    'pescetarian',
    'paleo',
    'primal',
    'low FODMAP',
    'Whole30'
  ];

  @override
  void initState() {
    super.initState();

    // Init focus + touched
    for (final c in [
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
      _focusMap[c] = node;
      _fieldTouched[c] = false;

      node.addListener(() {
        if (node.hasFocus) {
          setState(() => _fieldTouched[c] = true); // hide "required" on focus
        } else {
          if (_submitted) setState(() {}); // revalidate on blur if needed
        }
      });

      // Mark touched on type; keep validators responsive
      c.addListener(() {
        if (_fieldTouched[c] != true) {
          setState(() => _fieldTouched[c] = true);
        } else {
          if (_submitted) setState(() {});
        }
      });
    }

    // Live password rules
    _passwordController.addListener(() {
      final value = _passwordController.text;
      setState(() {
        _passwordTouched = value.isNotEmpty;
        _hasMinLength = value.length >= 8;
        _hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
        _hasNumber = RegExp(r'\d').hasMatch(value);
        _hasSpecial = RegExp(r'[!@#\$&*~]').hasMatch(value);
        if (_passwordError != null) _passwordError = null;
      });
    });

    // Live email duplication check (debounced)
    _emailController.addListener(() {
      // clear any previous msg when typing
      if (_emailError != null) setState(() => _emailError = null);

      _emailDebounce?.cancel();
      _emailDebounce = Timer(const Duration(milliseconds: 400), () async {
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          if (_emailError != null) setState(() => _emailError = null);
          return;
        }
        if (!EmailValidator.validate(email)) {
          // let the validator handle "invalid format" when submitted;
          // do not set an error here to avoid flicker while typing
          return;
        }
        final inUse = await _emailAlreadyInUse(email);
        if (!mounted) return;
        if (inUse) {
          setState(() => _emailError = 'This email is already registered.');
        } else if (_emailError != null) {
          setState(() => _emailError = null);
        }
      });
    });
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    for (final n in _focusMap.values) {
      n.dispose();
    }
    for (final c in [
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
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _emailAlreadyInUse(String email) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Check if user entered valid date of birth
  bool _isValidDate(String input) {
    final regex =
        RegExp(r'^(0[1-9]|1[0-2])\/(0[1-9]|[12][0-9]|3[01])\/(19|20)\d{2}$');
    if (!regex.hasMatch(input)) return false;
    try {
      final parts = input.split('/');
      final date = DateTime(
          int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  // ---- PAGE 1: Validate, then go next
  Future<void> _validatePage1AndNext() async {
    setState(() => _submitted = true);
    setState(() {}); // force rebuild so validators run with _submitted=true

    // If email duplication already detected via live check, block navigation
    if (_emailError != null) return;

    final validLocal = _formKey.currentState?.validate() ?? false;
    if (!validLocal) return;

    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentPage = 1);
  }

  // ---- REGISTER USER (Auth + Firestore Sync)
  Future<void> _registerUser() async {
    setState(() => _submitted = true);
    if (_emailError != null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create user in Firebase Auth
      final authResult =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final userAuth = authResult.user;
      if (userAuth == null)
        throw Exception('User creation failed — no user returned.');
      final uid = userAuth.uid;

      // Prepare DOB (optional)
      DateTime? dob;
      if (_dobController.text.trim().isNotEmpty) {
        final parts = _dobController.text.split('/');
        dob = DateTime(
            int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
      }

      // Build MealProfile + Preferences objects
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
        macroGoals: {'protein': _protein, 'carbs': _carbs, 'fat': _fats},
        dailyCalorieGoal: int.tryParse(_dailyCaloriesController.text) ?? 0,
        dietaryGoal: _dietaryGoal ?? '',
      );

      // Build your AppUser model (use UID instead of random ID)
      final now = DateTime.now();
      // Convert numeric fields safely — null if blank
      double? heightCm;
      
      if (_heightFeet != null && _heightInches != null) {
        heightCm = (_heightFeet! * 12 + _heightInches!) * 2.54;
      }

      final weightValue = _weightController.text.trim().isEmpty
          ? null
          : double.tryParse(_weightController.text);
      final dailyCaloriesValue = _dailyCaloriesController.text.trim().isEmpty
          ? null
          : int.tryParse(_dailyCaloriesController.text);

      // Build AppUser model
      final appUser = AppUser(
        id: uid,
        firstname: _firstnameController.text.trim(),
        lastname: _lastnameController.text.trim(),
        dob: dob ?? DateTime(1900, 1, 1),
        sex: _sex ?? '',
        height: heightCm ?? 0.0, // still required by your model constructor
        weight: weightValue ?? 0.0,
        activityLevel: _activityLevel ?? '',
        mealProfile: mealProfile.copyWith(
          dailyCalorieGoal: dailyCaloriesValue ?? 0,
        ),
        createdAt: now,
        updatedAt: now,
      );

      // Convert to JSON
      final userData = appUser.toJson();

      // Replace placeholder values with null before saving
      if (dob == null) userData['dob'] = null;
      if (heightCm == null) userData['height'] = null;
      if (weightValue == null) userData['weight'] = null;
      if (dailyCaloriesValue == null) {
        // drill down into nested structure
        userData['mealProfile']['dailyCalorieGoal'] = null;
      }

      // If DOB is placeholder, store as null for cleanliness
      if (dob == null) userData['dob'] = null;

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .set(userData);

      // Send verification email
      await userAuth.sendEmailVerification();

      // Done
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Account created! Check your email for verification.'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code}');

      if (e.code == 'email-already-in-use') {
        setState(() => _emailError = 'This email is already registered.');
      } else if (e.code == 'weak-password') {
        setState(() => _passwordError = 'Password is too weak.');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Auth error: ${e.message}')));
      }

      // Rollback Firestore if Auth user created but Firestore write fails later
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && !currentUser.emailVerified) {
        await currentUser.delete(); // cleanup incomplete user
      }
    } catch (e) {
      debugPrint('Registration general error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));

      // Rollback Auth user if Firestore write failed
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && !currentUser.emailVerified) {
        await currentUser.delete();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(
        title: Text(_currentPage == 0 ? 'Create Account' : 'More Info'),
        centerTitle: true,
      ),*/
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode:
              _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
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

  // ---- PAGE 1
  Widget _buildPage1() {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final cardHorizontalPadding =
        (mediaQuery.size.width * 0.1).clamp(20.0, 36.0).toDouble();
    final linkFontSize = (screenHeight * 0.022).clamp(16.0, 22.0).toDouble();
    final logoHeight = (screenHeight * 0.15).clamp(90.0, 140.0).toDouble();

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 24 + mediaQuery.viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const top_bar(),
          SizedBox(
            height: (screenHeight * 0.03).clamp(16.0, 28.0).toDouble(),
          ),
          SizedBox(
            height: logoHeight,
            child: Image.asset(
              'lib/icons/WISERBITES.png',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(
            height: (screenHeight * 0.025).clamp(14.0, 24.0).toDouble(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: EdgeInsets.fromLTRB(
                cardHorizontalPadding,
                30,
                cardHorizontalPadding,
                30,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(48),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.5),
                    spreadRadius: 4,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentBrown,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _textFieldRequired(_firstnameController, 'First Name'),
                  _textFieldRequired(_lastnameController, 'Last Name'),
                  _emailField(), // email with LIVE duplication check
                  _passwordField(), // single-line live hint
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _validatePage1AndNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Already have an account? Login",
                      style: TextStyle(
                        fontSize: linkFontSize,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentBrown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ---- PAGE 2
  Widget _buildPage2() {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final cardHorizontalPadding =
        (mediaQuery.size.width * 0.1).clamp(20.0, 36.0).toDouble();
    final logoHeight = (screenHeight * 0.15).clamp(90.0, 140.0).toDouble();

    // Use the primary scroll controller to avoid Scrollbar having no attached position
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // removes focus from any TextField
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24 + mediaQuery.viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const top_bar(),
            SizedBox(
              height: (screenHeight * 0.03).clamp(16.0, 28.0).toDouble(),
            ),
            SizedBox(
              height: logoHeight,
              child: Image.asset(
                'lib/icons/WISERBITES.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(
              height: (screenHeight * 0.025).clamp(14.0, 24.0).toDouble(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
                padding: EdgeInsets.fromLTRB(
                  cardHorizontalPadding,
                  30,
                  cardHorizontalPadding,
                  30,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.5),
                      spreadRadius: 4,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dobFieldOptional(), // DOB is NOT required
                    _dropdownField('Sex', _sexOptions, (v) => _sex = v),
                    _heightPicker(),
                    _textFieldOptional(_weightController, 'Weight',
                        keyboardType: TextInputType.number, suffixText: "lbs"),
                    _dropdownField('Activity Level', _activityLevels,
                        (v) => _activityLevel = v),
                    _dropdownField(
                        'Dietary Goal', _dietGoals, (v) => _dietaryGoal = v),
                    _textFieldOptional(
                        _dailyCaloriesController, 'Daily Calorie Goal',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 20),
                    const Text('Macronutrient Goals (% of calories)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    MacroSlider(
                      protein: _protein,
                      carbs: _carbs,
                      fats: _fats,
                      onChanged: (p, c, f) => setState(() {
                        _protein = p;
                        _carbs = c;
                        _fats = f;
                      }),
                    ),
                    const SizedBox(height: 25),
                    _centeredMultiSelectField(
                        'Dietary Habits', _dietaryHabitOptions, _dietaryHabits),
                    const SizedBox(height: 24),
                    _centeredMultiSelectField(
                        'Health Restrictions', _healthOptions, _health),
                    const SizedBox(height: 24),
                    _textFieldOptional(
                        _likesController, 'Food Likes (comma-separated)'),
                    _textFieldOptional(
                        _dislikesController, 'Food Dislikes (comma-separated)'),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut);
                            setState(() => _currentPage = 0);
                          },
                          child: const Text('Back'),
                        ),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: _registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                child: const Text('Create Account',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18)),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ---- UI helpers (Page 1 required fields)

  Widget _textFieldRequired(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    final node = _focusMap[c];
    final hasFocus = node?.hasFocus ?? false;
    final showRequired = _submitted && c.text.isEmpty && !hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        focusNode: node,
        keyboardType: keyboardType,
        obscureText: obscure,
        onChanged: (_) => setState(() {}),
        onTap: () => setState(() {}), // hide required on focus
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          errorText: showRequired ? 'This field is required' : null,
        ),
        validator: (val) {
          if (_submitted && (val == null || val.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  // Email field with valid email check and required field
  Widget _emailField() {
    final c = _emailController;
    final node = _focusMap[c];
    final hasFocus = node?.hasFocus ?? false;
    final showRequired = _submitted && c.text.isEmpty && !hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        focusNode: node,
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(() {}), // keep UI responsive
        onTap: () => setState(() {}), // hide required on focus
        decoration: InputDecoration(
          labelText: 'Email',
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          errorText:
              _emailError ?? (showRequired ? 'This field is required' : null),
        ),
        validator: (val) {
          if (_submitted && (val == null || val.isEmpty)) {
            return 'This field is required';
          }
          if (val != null && val.isNotEmpty && !EmailValidator.validate(val)) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  // Password field with live Firebase Auth requirements
  Widget _passwordField() {
    final c = _passwordController;
    final node = _focusMap[c];
    final hasFocus = node?.hasFocus ?? false;
    final showRequired = _submitted && c.text.isEmpty && !hasFocus;

    String? liveHint;
    final value = c.text;
    if (value.isNotEmpty) {
      if (value.length < 8) {
        liveHint = 'Password must be at least 8 characters';
      } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
        liveHint = 'Include at least one uppercase letter';
      } else if (!RegExp(r'\d').hasMatch(value)) {
        liveHint = 'Include at least one number';
      } else if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) {
        liveHint = 'Include at least one special character';
      }
    }

    final effectiveError =
        _passwordError ?? (showRequired ? 'This field is required' : liveHint);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        focusNode: node,
        obscureText: true,
        onChanged: (_) => setState(() {}),
        onTap: () => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Password',
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          errorText: effectiveError,
        ),
        validator: (val) {
          if (_submitted && (val == null || val.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  // ---- Optional text field
  Widget _textFieldOptional(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.inputFill,
          suffixText: suffixText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }


  Widget _heightPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Height',
                style: TextStyle(
                  color: Colors.grey[800], 
                  fontSize: 16,       
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController:
                          FixedExtentScrollController(initialItem: _heightFeet ?? 0),
                      itemExtent: 32,
                      looping: true,
                      onSelectedItemChanged: (val) {
                        setState(() {
                          _heightFeet = val;
                        });
                      },
                      children:
                          List.generate(11, (i) => Center(child: Text('$i ft'))),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: _heightInches ?? 0),
                      itemExtent: 32,
                      looping: true,
                      onSelectedItemChanged: (val) {
                        setState(() {
                          _heightInches = val;
                        });
                      },
                      children:
                          List.generate(12, (i) => Center(child: Text('$i in'))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField(
    String label,
    List<String> options,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: onChanged,
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }

  Widget _centeredMultiSelectField(
    String label,
    List<String> options,
    List<String> selected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                onSelected: (_) => setState(() {
                  isSelected ? selected.remove(option) : selected.add(option);
                }),
                selectedColor: AppColors.brand.withValues(alpha: 0.4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---- DOB (NOT required)
  Widget _dobFieldOptional() {
    final c = _dobController;
    final node = _focusMap[c];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        focusNode: node,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _DOBFormatter(),
        ],
        decoration: InputDecoration(
          labelText: 'Date of Birth (MM/DD/YYYY)',
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (picked != null) {
                _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
                setState(() {});
              }
            },
          ),
        ),
        validator: (val) {
          // NOT required; only validate format if non-empty
          if (val != null && val.isNotEmpty && !_isValidDate(val)) {
            return 'Enter a valid date (MM/DD/YYYY)';
          }
          return null;
        },
      ),
    );
  }
}

// Class for DOB formatter from user input or clickable calendar
class _DOBFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) buffer.write('/');
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}