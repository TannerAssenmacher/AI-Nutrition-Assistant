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
  bool _canEditDob = true; 

  //colors
  final Color bgColor = const Color(0xFFF5EDE2);
  final Color brandColor = const Color(0xFF5F9735); 
  final Color deleteColor = const Color(0xFFD32F2F);

  //controllers
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dailyCaloriesController = TextEditingController();

  //data
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
      if (!mounted) return;
      setState(() {
        _firstname = data['firstname'];
        _lastname = data['lastname'];
        _email = user!.email;
        
        //load dob and check if already in dob, if not then edit flag becomes true
        if (data['dob'] != null && data['dob'].toString().trim().isNotEmpty) {
          _dob = data['dob'].toString().split(' ')[0];
          _canEditDob = false; 
        } else {
          _dob = '';
          _canEditDob = true;
        }

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
      debugPrint("Error loading profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDobPicker() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: brandColor, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dob = pickedDate.toString().split(' ')[0];
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    try {
      //update with whatever is not empty
      final Map<String, dynamic> updateData = {
        'activityLevel': _activityLevel,
        'dob': (_dob != null && _dob!.isNotEmpty) ? _dob : null,
        'mealProfile.dietaryGoal': _dietaryGoal,
        'mealProfile.macroGoals': {
          'protein': _protein,
          'carbs': _carbs,
          'fat': _fats,
        },
        'mealProfile.dietaryHabits': _dietaryHabits,
        'mealProfile.healthRestrictions': _health,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      //only add numeric fields
      if (_heightController.text.isNotEmpty) {
        updateData['height'] = double.tryParse(_heightController.text);
      }
      if (_weightController.text.isNotEmpty) {
        updateData['weight'] = double.tryParse(_weightController.text);
      }
      if (_dailyCaloriesController.text.isNotEmpty) {
        updateData['mealProfile.dailyCalorieGoal'] = int.tryParse(_dailyCaloriesController.text);
      }

      //push update to firebase
      await _firestore.collection('Users').doc(user!.uid).update(updateData);

      //lock dob locally
      if (_dob != null && _dob!.isNotEmpty) {
        setState(() => _canEditDob = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'))
        );
      }
    } catch (e) {
      debugPrint("!! SAVE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50, 
                  backgroundColor: brandColor, 
                  child: Text(_getInitials(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                Text('$_firstname $_lastname', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_email ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBox("Height", _heightController),
                    _buildStatBox("Weight", _weightController),
                    _buildStatBox("Daily Cal", _dailyCaloriesController, isPrimary: true),
                  ],
                ),
                const SizedBox(height: 30),

                _sectionHeader("User"),
                _buildCard([
                  _buildListTile(Icons.badge_outlined, "First Name", _firstname ?? ""),
                  _buildListTile(Icons.badge_outlined, "Last Name", _lastname ?? ""),
                  _buildListTile(Icons.email_outlined, "Email", _email ?? ""),
                  
                  _buildListTile(
                    Icons.calendar_today, 
                    "DOB", 
                    (_dob == null || _dob!.isEmpty) ? "Not set" : _dob!,
                    onTap: _canEditDob ? _showDobPicker : null, 
                  ),
                  
                  _buildListTile(Icons.wc, "Sex", _sex ?? "Not set"),
                  _buildListTile(Icons.bolt, "Activity Level", _activityLevel ?? "Select", 
                      onTap: () => _showPicker("Activity", _activityLevels, _activityLevel, (v) => setState(() => _activityLevel = v))),
                  _buildListTile(Icons.track_changes, "Dietary Goal", _dietaryGoal ?? "Select", 
                      onTap: () => _showPicker("Diet Goal", _dietGoals, _dietaryGoal, (v) => setState(() => _dietaryGoal = v))),
                ]),

                const SizedBox(height: 25),

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

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: brandColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: deleteColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                    child: const Text("Delete Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.isInPageView ? null : NavBar(
        currentIndex: navIndexProfile,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  Widget _buildStatBox(String label, TextEditingController controller, {bool isPrimary = false}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 12), 
      decoration: BoxDecoration(
        color: isPrimary ? brandColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : Colors.black),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, errorStyle: TextStyle(height: 0)),
              validator: (v) => (v == null || v.isEmpty) ? "" : null,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: isPrimary ? Colors.white70 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(alignment: Alignment.centerLeft, child: Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
    ));
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: brandColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      
          if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ],
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