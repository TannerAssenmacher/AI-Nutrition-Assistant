import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/macro_slider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _submitted = false;

  // Controllers
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dailyCaloriesController = TextEditingController();
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();

  // Data fields
  String? _firstname;
  String? _lastname;
  String? _email;
  String? _dob;
  String? _sex;
  String? _activityLevel;
  String? _dietaryGoal;
  List<String> _dietaryHabits = [];
  List<String> _health = [];

  // Macros
  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;

  // Dropdown options
  final _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active'
  ];
  final _dietGoals = ['Lose Weight', 'Maintain Weight', 'Gain Muscle'];
  
  //edamam api options for diet labels
  final _dietaryHabitOptions = [
    'balanced', 
    'high-fiber', 
    'high-protein', 
    'low-carb', 
    'low-fat', 
    'low-sodium',
    'none'
  ];

  //edamam api option for health labels
  final _healthOptions = [
   'alcohol-cocktail' , 
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc = await _firestore.collection('Users').doc(user!.uid).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      setState(() {
        _firstname = data['firstname'];
        _lastname = data['lastname'];
        _email = data['email'];
        _dob = data['dateOfBirth'];
        _sex = data['sex'];
        _heightController.text = data['height'].toString();
        _weightController.text = data['weight'].toString();
        _activityLevel = data['activityLevel'];
        _dietaryGoal = data['dietaryGoal'];
        _dailyCaloriesController.text = data['dailyCalorieGoal'].toString();
        final macroGoals = Map<String, dynamic>.from(data['macroGoals']);
        _protein = macroGoals['protein']?.toDouble() ?? 0;
        _carbs = macroGoals['carbs']?.toDouble() ?? 0;
        _fats = macroGoals['fats']?.toDouble() ?? 0;

        if (data.containsKey('mealProfile')) {
          final mp = Map<String, dynamic>.from(data['mealProfile']);
          _dietaryHabits =
              (mp['dietaryHabits'] as List).map((e) => e.toString()).toList();
          _health =
              (mp['allergies'] as List).map((e) => e.toString()).toList();
          final prefs = Map<String, dynamic>.from(mp['preferences']);
          _likesController.text =
              (prefs['likes'] as List).join(', ');
          _dislikesController.text =
              (prefs['dislikes'] as List).join(', ');
        }
      });
    } catch (e) {
      print('⚠️ Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_dietaryHabits.isEmpty || _health.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text('Please select at least one dietary habit and one allergy.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('Users').doc(user!.uid).update({
        'height': double.parse(_heightController.text),
        'weight': double.parse(_weightController.text),
        'activityLevel': _activityLevel,
        'dietaryGoal': _dietaryGoal,
        'dailyCalorieGoal': int.parse(_dailyCaloriesController.text),
        'macroGoals': {
          'protein': _protein,
          'carbs': _carbs,
          'fats': _fats,
        },
        'mealProfile.dietaryHabits': _dietaryHabits,
        'mealProfile.allergies': _health,
        'mealProfile.preferences.likes':
        _likesController.text.split(',').map((e) => e.trim()).toList(),
        'mealProfile.preferences.dislikes':
        _dislikesController.text.split(',').map((e) => e.trim()).toList(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!')));
    } catch (e) {
      print('⚠️ Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Read-only info
                  Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(minWidth: 250, maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _readOnlyField('First Name', _firstname ?? ''),
                          _readOnlyField('Last Name', _lastname ?? ''),
                          _readOnlyField('Email', _email ?? ''),
                          _readOnlyField('Date of Birth', _dob ?? ''),
                          _readOnlyField('Sex', _sex ?? ''),
                          _editableField(_heightController, 'Height (inches)',
                              isNumber: true),
                          _editableField(_weightController, 'Weight (lbs)',
                              isNumber: true),
                          _dropdownField('Activity Level', _activityLevels,
                              _activityLevel, (val) => _activityLevel = val),
                          _dropdownField('Dietary Goal', _dietGoals,
                              _dietaryGoal, (val) => _dietaryGoal = val),
                          _editableField(_dailyCaloriesController,
                              'Daily Calorie Goal',
                              isNumber: true),
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
                  _centeredMultiSelectField(
                      'Dietary Habits', _dietaryHabitOptions, _dietaryHabits),
                  const SizedBox(height: 24),
                  _centeredMultiSelectField(
                      'Health Restrictions', _healthOptions, _health),
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(minWidth: 250, maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _editableField(_likesController,
                              'Food Likes (comma-separated, e.g. "chicken, rice")'),
                          _editableField(_dislikesController,
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
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.all(15),
                        ),
                        child: const Text(
                          'Save Changes',
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

  // --- Helper Widgets ---

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        readOnly: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _editableField(TextEditingController controller, String label,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType:
        isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) return 'This field is required';
          return null;
        },
      ),
    );
  }

  Widget _dropdownField(String label, List<String> options, String? value,
      void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: value,
        onChanged: onChanged,
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        validator: (val) =>
        val == null || val.isEmpty ? 'Please select an option' : null,
      ),
    );
  }

  Widget _centeredMultiSelectField(
      String label, List<String> options, List<String> selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
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
                onSelected: (_) {
                  setState(() {
                    isSelected
                        ? selected.remove(option)
                        : selected.add(option);
                  });
                },
                selectedColor: Colors.green[200],
              );
            }).toList(),
          ),
          if (_submitted && selected.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Please select at least one option',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
