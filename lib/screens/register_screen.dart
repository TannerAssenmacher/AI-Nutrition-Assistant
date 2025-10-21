import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../db/user.dart';
import '../widgets/macro_slider.dart';
import 'package:intl/intl.dart';

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
  final _dobController = TextEditingController();
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
  bool _submitted = false;

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

  /// ✅ Validates that a date string MM/DD/YYYY is a real valid date
  bool _isValidDate(String input) {
    final regex =
    RegExp(r'^(0[1-9]|1[0-2])\/(0[1-9]|[12][0-9]|3[01])\/(19|20)\d{2}$');
    if (!regex.hasMatch(input)) return false;

    try {
      final parts = input.split('/');
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final date = DateTime(year, month, day);
      return date.month == month &&
          date.day == day &&
          date.year == year &&
          year <= DateTime.now().year;
    } catch (_) {
      return false;
    }
  }

  Future<void> _registerUser() async {
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) return;

    if (_dietaryHabits.isEmpty || _allergies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text('Please select at least one dietary habit and one allergy')));
      return;
    }

    if (_sex == null || _activityLevel == null || _dietaryGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete all dropdowns and selections')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authResult =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
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

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .set(userJson);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(minWidth: 250, maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(_firstnameController, 'First Name'),
                          _buildTextField(_lastnameController, 'Last Name'),
                          _buildTextField(_emailController, 'Email',
                              keyboardType: TextInputType.emailAddress),
                          _buildTextField(_passwordController, 'Password',
                              obscure: true),

                          // ✅ Final fixed Date of Birth field
                          Padding(
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
                                    DateTime? pickedDate =
                                    await showDatePicker(
                                      context: context,
                                      initialDate: DateTime(
                                          now.year - 18, now.month, now.day),
                                      firstDate: DateTime(1900),
                                      lastDate: now,
                                    );
                                    if (pickedDate != null) {
                                      _dobController.text =
                                          DateFormat('MM/dd/yyyy')
                                              .format(pickedDate);
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
                          ),

                          _dropdownField('Sex', _sexOptions, (val) => _sex = val),
                          _buildTextField(_heightController, 'Height (inches)',
                              keyboardType: TextInputType.number),
                          _buildTextField(_weightController, 'Weight (lbs)',
                              keyboardType: TextInputType.number),
                          _dropdownField('Activity Level', _activityLevels,
                                  (val) => _activityLevel = val),
                          _dropdownField('Dietary Goal', _dietGoals,
                                  (val) => _dietaryGoal = val),
                          _buildTextField(_dailyCaloriesController,
                              'Daily Calorie Goal',
                              keyboardType: TextInputType.number),
                          const SizedBox(height: 20),
                          const Text(
                            'Macronutrient Goals (% of calories)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _centeredMultiSelectField('Dietary Habits',
                      _dietaryHabitOptions, _dietaryHabits,
                      isRequired: true),
                  const SizedBox(height: 24),
                  _centeredMultiSelectField(
                      'Allergies', _allergyOptions, _allergies,
                      isRequired: true),
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(minWidth: 250, maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildOptionalTextField(_likesController,
                              'Food Likes (comma-separated, e.g. "chicken, rice")'),
                          _buildOptionalTextField(_dislikesController,
                              'Food Dislikes (comma-separated, e.g. "broccoli, tofu")'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(minWidth: 200, maxWidth: 350),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.all(15),
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                              color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI helpers ---
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
      List<String> selected, {bool isRequired = false}) {
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
}

/// ✅ Final DOB formatter — keeps / consistent, allows backspace, and limits to MM/DD/YYYY
class _DOBFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // ✅ Cap at 8 digits (MMDDYYYY)
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      // Add slashes after month and day
      if ((i == 1 || i == 3) && i != digits.length - 1) {
        buffer.write('/');
      }
    }

    String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
