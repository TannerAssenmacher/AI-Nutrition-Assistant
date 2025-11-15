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
  bool _isDeleting = false;

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
    'low-sodium'
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
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await _firestore.collection('Users').doc(user!.uid).get();
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      setState(() {
        _firstname = data['firstname'];
        _lastname = data['lastname'];
        _email = user!.email;
        _dob = (data['dob'] != null) ? data['dob'].toString().split(' ')[0] : '';
        _sex = data['sex'];
        _heightController.text = data['height'].toString();
        _weightController.text = data['weight'].toString();
        _activityLevel = data['activityLevel'];
        _dietaryGoal = data['mealProfile']?['dietaryGoal'] ?? data['dietaryGoal'];
        _dailyCaloriesController.text = data['mealProfile']?['dailyCalorieGoal']?.toString() ?? data['dailyCalorieGoal']?.toString() ?? '';
        final macroGoals = Map<String, dynamic>.from(data['mealProfile']?['macroGoals'] ?? data['macroGoals'] ?? {});
        _protein = macroGoals['protein']?.toDouble() ?? 0;
        _carbs = macroGoals['carbs']?.toDouble() ?? 0;
        _fats = (macroGoals['fat'] ?? macroGoals['fats'] ?? 0).toDouble();

        if (data.containsKey('mealProfile')) {
          final mp = Map<String, dynamic>.from(data['mealProfile']);
          _dietaryHabits = (mp['dietaryHabits'] as List?)?.map((e) => e.toString()).toList() ?? [];
          _health = (mp['healthRestrictions'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final prefs = Map<String, dynamic>.from(mp['preferences'] ?? {});
          _likesController.text = (prefs['likes'] as List?)?.join(', ') ?? '';
          _dislikesController.text = (prefs['dislikes'] as List?)?.join(', ') ?? '';
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

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('Users').doc(user!.uid).update({
        'height': double.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
        'activityLevel': _activityLevel,
        'mealProfile.dietaryGoal': _dietaryGoal,
        'mealProfile.dailyCalorieGoal':
        int.tryParse(_dailyCaloriesController.text),
        'mealProfile.macroGoals': {
          'protein': _protein,
          'carbs': _carbs,
          'fat': _fats,
        },
        'mealProfile.dietaryHabits': _dietaryHabits,
        'mealProfile.healthRestrictions': _health,
        'mealProfile.preferences.likes':
        _likesController.text.split(',').map((e) => e.trim()).toList(), 'mealProfile.preferences.dislikes':
        _dislikesController.text.split(',').map((e) => e.trim()).toList(), 'updatedAt': FieldValue.serverTimestamp(),
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

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Account Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'To permanently delete your account, please enter your password to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount(passwordController.text.trim());
    }
  }

  Future<void> _deleteAccount(String password) async {
    setState(() => _isDeleting = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );

      await user!.reauthenticateWithCredential(credential);
      await _firestore.collection('Users').doc(user!.uid).delete();
      await user!.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account deleted successfully.'),
        ));
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    } finally {
      setState(() => _isDeleting = false);
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
                          _optionalField(_likesController,
                              'Food Likes (comma-separated, e.g. "chicken, rice")'),
                          _optionalField(_dislikesController,
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
                  const SizedBox(height: 20),
                  Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(minWidth: 200, maxWidth: 350),
                      child: _isDeleting
                          ? const Center(child: CircularProgressIndicator())
                          : OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.red),
                        label: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.all(15),
                        ),
                        onPressed: _confirmDeleteAccount,
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
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _optionalField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdownField(String label, List<String> options, String? value,
      void Function(String?) onChanged) {
    String? safeValue = options.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: safeValue,
        onChanged: onChanged,
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
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
        ],
      ),
    );
  }
}
