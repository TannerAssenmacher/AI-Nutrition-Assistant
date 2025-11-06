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
  List<String> _allergies = [];

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

  void _markTouchedOnType(TextEditingController c) {
    c.addListener(() {
      if (_fieldTouched[c] != true) {
        setState(() => _fieldTouched[c] = true);
      } else {
        // still setState so error hides as soon as user types
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
        // When user clicks into the field, hide error right away
        if (node.hasFocus) {
          setState(() {
            _fieldTouched[controller] = true;
          });
        } else {
          // When focus leaves, trigger validation again
          _formKey.currentState?.validate();
        }
      });
    }

    // keep these existing listeners:
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
        _hasSpecial = RegExp(r'[!@#\$&*~]').hasMatch(value);
        if (_passwordError != null) _passwordError = null;
      });
    });

    // NEW: mark required fields as touched on type so their own error hides
    _markTouchedOnType(_firstnameController);
    _markTouchedOnType(_lastnameController);
    _markTouchedOnType(_emailController);
    _markTouchedOnType(_passwordController);
    _markTouchedOnType(_dobController);
    _markTouchedOnType(_heightController);
    _markTouchedOnType(_weightController);
    _markTouchedOnType(_dailyCaloriesController);
    // likes/dislikes are optional — you can skip them
  }


  void _toggleMultiSelect(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  bool _isValidDate(String input) {
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/(0[1-9]|[12][0-9]|3[01])\/(19|20)\d{2}$');
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

  Future<void> _registerUser() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    if (_dietaryHabits.isEmpty || _allergies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select at least one dietary habit and one allergy')));
      return;
    }

    if (_sex == null || _activityLevel == null || _dietaryGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete all dropdowns and selections')));
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
        allergies: _allergies,
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
        sex: _sex!,
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        activityLevel: _activityLevel!,
        dietaryGoal: _dietaryGoal!,
        mealProfile: mealProfile,
        mealPlans: {},
        dailyCalorieGoal: int.parse(_dailyCaloriesController.text),
        macroGoals: {'protein': _protein, 'carbs': _carbs, 'fats': _fats},
      );

      final userJson = user.toJson();
      userJson['dateOfBirth'] = _dobController.text;

      await FirebaseFirestore.instance.collection('Users').doc(uid).set(userJson);
      await authResult.user?.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verification email sent! Please check your inbox.'),
          duration: Duration(seconds: 5),
        ));
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('🔥 Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateFirebaseCredentials() async {
    // Mark form as submitted and reset all field touch states
    setState(() {
      _submitted = true;
      _fieldTouched.updateAll((key, value) => false);
    });

    // Run validation — stops here if any empty or invalid fields
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Clear any previous Firebase errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    try {
      // 🔍 Try creating a temp Firebase user (enforces Firebase rules)
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // ✅ If successful, delete the temp user immediately
      await credential.user?.delete();

      // Move to next page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = 1);
    } on FirebaseAuthException catch (e) {
      // 🔴 Handle Firebase-specific validation errors
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _emailError = 'Please enter a valid email address.';
            break;
          case 'email-already-in-use':
            _emailError = 'This email is already registered.';
            break;
          case 'weak-password':
          // 👇 Don’t show Firebase’s message — just trigger local validation
            print('Firebase weak password error: ${e.message}');
            _passwordError = null;
            _passwordTouched = true; // ensures local hint shows
            break;
          default:
            print('Firebase Auth error: ${e.code} — ${e.message}');
            _passwordError = null; // never display Firebase text
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
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPage1(),
            _buildPage2(),
          ],
        ),
      ),
    );
  }

  // --- PAGE 1 ---
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 250, maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(_firstnameController, 'First Name'),
                _buildTextField(_lastnameController, 'Last Name'),
                _buildTextField(_emailController, 'Email',
                    keyboardType: TextInputType.emailAddress),
                _buildTextField(_passwordController, 'Password', obscure: true),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _validateFirebaseCredentials,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(15),
                  ),
                  child: const Text('Next',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- PAGE 2 ---
  Widget _buildPage2() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 250, maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDOBField(),
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
                const SizedBox(height: 10),
                MacroSlider(
                  protein: _protein,
                  carbs: _carbs,
                  fats: _fats,
                  onChanged: (p, c, f) {
                    setState(() {
                      _protein = p;
                      _carbs = c;
                      _fats = f;
                    });
                  },
                ),
                const SizedBox(height: 25),
                _centeredMultiSelectField(
                    'Dietary Habits', _dietaryHabitOptions, _dietaryHabits,
                    isRequired: true),
                const SizedBox(height: 24),
                _centeredMultiSelectField(
                    'Allergies', _allergyOptions, _allergies,
                    isRequired: true),
                const SizedBox(height: 24),
                _buildOptionalTextField(_likesController,
                    'Food Likes (comma-separated, e.g. "chicken, rice")'),
                _buildOptionalTextField(_dislikesController,
                    'Food Dislikes (comma-separated, e.g. "broccoli, tofu")'),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _currentPage = 0);
                      },
                      child: const Text('Back'),
                    ),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(15),
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
      ),
    );
  }

  // --- UI helpers ---
  Widget _buildTextField(
      TextEditingController c,
      String label, {
        TextInputType? keyboardType,
        bool obscure = false,
      }) {
    final focusNode = _focusNodes[c.hashCode.toString()];

    // Determine Firebase or password rule errors
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
        } else if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) {
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

        // 🔁 Live validation and dynamic refresh
        onChanged: (_) {
          if (_submitted) _formKey.currentState?.validate();
          setState(() {}); // ensures password hints refresh live
        },
        onTap: () {
          if (_submitted) _formKey.currentState?.validate();
          setState(() {});
        },

        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: effectiveError ??
              ((_submitted && c.text.isEmpty) ? 'This field is required' : null),
        ),

        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'This field is required';
          }
          if (label.toLowerCase().contains('email') &&
              !EmailValidator.validate(val)) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildOptionalTextField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
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

  Widget _centeredMultiSelectField(String label, List<String> options,
      List<String> selected,
      {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          if (_submitted && isRequired && selected.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('Please select at least one option',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildDOBField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _dobController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _DOBFormatter(),
        ],
        decoration: InputDecoration(
          labelText: 'Date of Birth (MM/DD/YYYY)',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              DateTime now = DateTime.now();
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (pickedDate != null) {
                _dobController.text =
                    DateFormat('MM/dd/yyyy').format(pickedDate);
              }
            },
          ),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'This field is required';
          }
          if (!_isValidDate(val)) {
            return 'Enter a valid date (MM/DD/YYYY)';
          }
          return null;
        },
      ),
    );
  }
}

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
    String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}


