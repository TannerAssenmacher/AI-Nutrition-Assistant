import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/macro_slider.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';

class ProfilePage extends StatefulWidget {
  final bool isInPageView;
  const ProfilePage({super.key, this.isInPageView = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  // Colors
  final Color bgColor = const Color(0xFFF5EDE2);
  final Color brandColor = const Color(0xFF5F9735); 
  final Color deleteColor = const Color(0xFFD32F2F); // Solid Red

  // Controllers for Header Boxes
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dailyCaloriesController = TextEditingController();

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

  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;

  final _activityLevels = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'];
  final _dietGoals = ['Lose Weight', 'Maintain Weight', 'Gain Muscle'];
  final _dietaryHabitOptions = ['balanced', 'high-fiber', 'high-protein', 'low-carb', 'low-fat', 'low-sodium'];
  final _healthOptions = [
    'vegan', 'vegetarian', 'gluten free', 'dairy free', 'ketogenic', 
    'lacto-vegetarian', 'ovo-vegetarian', 'pescetarian', 'paleo', 'primal', 'low FODMAP', 'Whole30'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _getInitials() {
    String initials = "";
    if (_firstname != null && _firstname!.isNotEmpty) initials += _firstname![0].toUpperCase();
    if (_lastname != null && _lastname!.isNotEmpty) initials += _lastname![0].toUpperCase();
    return initials.isEmpty ? "?" : initials;
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
        _email = user!.email;
        _dob = (data['dob'] != null) ? data['dob'].toString().split(' ')[0] : '';
        _sex = data['sex'];
        _heightController.text = data['height']?.toString() ?? '';
        _weightController.text = data['weight']?.toString() ?? '';
        _activityLevel = data['activityLevel'];
        
        final mealProfile = data['mealProfile'] ?? {};
        _dietaryGoal = mealProfile['dietaryGoal'];
        _dailyCaloriesController.text = mealProfile['dailyCalorieGoal']?.toString() ?? '';
        
        final macroGoals = Map<String, dynamic>.from(mealProfile['macroGoals'] ?? {});
        _protein = macroGoals['protein']?.toDouble() ?? 0;
        _carbs = macroGoals['carbs']?.toDouble() ?? 0;
        _fats = (macroGoals['fat'] ?? macroGoals['fats'] ?? 0).toDouble();
        
        _dietaryHabits = List<String>.from(mealProfile['dietaryHabits'] ?? []);
        _health = List<String>.from(mealProfile['healthRestrictions'] ?? []);
      });
    } catch (e) {
      debugPrint("Error loading: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('Users').doc(user!.uid).update({
        'height': double.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
        'activityLevel': _activityLevel,
        'mealProfile': {
          'dietaryGoal': _dietaryGoal,
          'dailyCalorieGoal': int.tryParse(_dailyCaloriesController.text),
          'macroGoals': {'protein': _protein, 'carbs': _carbs, 'fat': _fats},
          'dietaryHabits': _dietaryHabits,
          'healthRestrictions': _health,
        },
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20), 
          onPressed: () => Navigator.pop(context)
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // --- HEADER ---
            CircleAvatar(
              radius: 50, 
              backgroundColor: brandColor, 
              child: Text(
                _getInitials(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text('$_firstname $_lastname', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(_email ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 25),

            // --- HEADER BOXES ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatBox("Height", _heightController),
                _buildStatBox("Weight", _weightController),
                _buildStatBox("Daily Cal", _dailyCaloriesController, isPrimary: true),
              ],
            ),
            const SizedBox(height: 30),

            // --- USER SECTION ---
            _sectionHeader("User"),
            _buildCard([
              _buildListTile(Icons.badge_outlined, "First Name", _firstname ?? ""),
              _buildListTile(Icons.badge_outlined, "Last Name", _lastname ?? ""),
              _buildListTile(Icons.email_outlined, "Email", _email ?? ""),
              _buildListTile(Icons.calendar_today, "DOB", _dob ?? "Not set"),
              _buildListTile(Icons.wc, "Sex", _sex ?? "Not set"),
              _buildListTile(Icons.bolt, "Activity Level", _activityLevel ?? "Select", 
                  onTap: () => _showPicker("Activity", _activityLevels, _activityLevel, (v) => setState(() => _activityLevel = v))),
              _buildListTile(Icons.track_changes, "Dietary Goal", _dietaryGoal ?? "Select", 
                  onTap: () => _showPicker("Diet Goal", _dietGoals, _dietaryGoal, (v) => setState(() => _dietaryGoal = v))),
            ]),

            const SizedBox(height: 25),

            // --- MEAL PROFILE SECTION ---
            _sectionHeader("Meal Profile"),
            _buildCard([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Macronutrients Goal", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    MacroSlider(
                      protein: _protein, carbs: _carbs, fats: _fats, 
                      onChanged: (p, c, f) => setState(() { _protein = p; _carbs = c; _fats = f; })
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildMultiSelectTile("Dietary Habits", _dietaryHabitOptions, _dietaryHabits),
              const Divider(height: 1),
              _buildMultiSelectTile("Health Restrictions", _healthOptions, _health),
            ]),

            const SizedBox(height: 30),

            // --- BUTTONS ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {}, // Add logic for account deletion
                style: ElevatedButton.styleFrom(
                  backgroundColor: deleteColor, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text("Delete Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: widget.isInPageView ? null : NavBar(
        currentIndex: navIndexProfile,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft, 
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
      )
    );
  }

  Widget _buildStatBox(String label, TextEditingController controller, {bool isPrimary = false}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isPrimary ? brandColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : Colors.black),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: isPrimary ? Colors.white70 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: brandColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ]
      ),
    );
  }

  Widget _buildMultiSelectTile(String title, List<String> options, List<String> selected) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10.0, bottom: 5),
        child: Wrap(
          spacing: 8, 
          runSpacing: 4,
          children: options.map((opt) {
            final isSel = selected.contains(opt);
            return ChoiceChip(
              label: Text(opt, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
              selected: isSel,
              selectedColor: brandColor,
              backgroundColor: bgColor.withOpacity(0.5),
              onSelected: (v) => setState(() => v ? selected.add(opt) : selected.remove(opt)),
            );
          }).toList()
        ),
      ),
    );
  }

  void _showPicker(String title, List<String> options, String? current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) => ListTile(
                  title: Text(o, textAlign: TextAlign.center), 
                  onTap: () { onSelect(o); Navigator.pop(context); }
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ]
        ),
      )
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/macro_slider.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';

class ProfilePage extends StatefulWidget {
  final bool isInPageView;

  const ProfilePage({super.key, this.isInPageView = false});

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
    'low-sodium',
  ];

  //spoonacular food options
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
        _dob =
            (data['dob'] != null) ? data['dob'].toString().split(' ')[0] : '';
        _sex = data['sex'];
        _heightController.text = data['height'].toString();
        _weightController.text = data['weight'].toString();
        _activityLevel = data['activityLevel'];
        _dietaryGoal =
            data['mealProfile']?['dietaryGoal'] ?? data['dietaryGoal'];
        _dailyCaloriesController.text =
            data['mealProfile']?['dailyCalorieGoal']?.toString() ??
                data['dailyCalorieGoal']?.toString() ??
                '';
        final macroGoals = Map<String, dynamic>.from(
            data['mealProfile']?['macroGoals'] ?? data['macroGoals'] ?? {});
        _protein = macroGoals['protein']?.toDouble() ?? 0;
        _carbs = macroGoals['carbs']?.toDouble() ?? 0;
        _fats = (macroGoals['fat'] ?? macroGoals['fats'] ?? 0).toDouble();

        if (data.containsKey('mealProfile')) {
          final mp = Map<String, dynamic>.from(data['mealProfile']);
          _dietaryHabits = (mp['dietaryHabits'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _health = (mp['healthRestrictions'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final prefs = Map<String, dynamic>.from(mp['preferences'] ?? {});
          _likesController.text = (prefs['likes'] as List?)?.join(', ') ?? '';
          _dislikesController.text =
              (prefs['dislikes'] as List?)?.join(', ') ?? '';
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
        'mealProfile': {
          'dietaryGoal': _dietaryGoal,
          'dailyCalorieGoal': int.tryParse(_dailyCaloriesController.text),
          'macroGoals': {
            'protein': _protein,
            'carbs': _carbs,
            'fat': _fats,
          },
          'dietaryHabits': _dietaryHabits,
          'healthRestrictions': _health,
          'preferences': {
            'likes':
                _likesController.text.split(',').map((e) => e.trim()).toList(),
            'dislikes': _dislikesController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      print('⚠️ Error saving profile: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
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

    final bodyContent = SafeArea(
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
                        _dropdownField('Dietary Goal', _dietGoals, _dietaryGoal,
                            (val) => _dietaryGoal = val),
                        _editableField(
                            _dailyCaloriesController, 'Daily Calorie Goal',
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
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
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
    );

    if (widget.isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE2),
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexProfile,
        onTap: (index) => handleNavTap(context, index),
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
                    isSelected ? selected.remove(option) : selected.add(option);
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
*/