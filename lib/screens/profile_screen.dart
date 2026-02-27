import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../widgets/macro_slider.dart';
import '../theme/app_colors.dart';
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
  bool _isDeleting = false;
  bool _isEdited = false;
  bool _isShowingSaveDialog = false;

  final Color bgColor = AppColors.background;
  final Color brandColor = AppColors.brand;
  final Color deleteColor = AppColors.deleteRed;

  final _weightController = TextEditingController();
  final _dailyCaloriesController = TextEditingController();
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();

  double? _heightCm;

  List<String> _likesList = [];
  List<String> _dislikesList = [];

  String? _firstname;
  String? _lastname;
  String? _email;
  String? _dob;
  String? _sex;
  double _activityLevel = 1;
  double _dietaryGoal = 0;
  List<String> _dietaryHabits = [];
  List<String> _health = [];

  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;
  Map<String, dynamic> _savedProfileSnapshot = {};

  /*final _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
  ];*/
  final _dietGoals = [
    'Large Weight Loss',
    'Weight Loss',
    'Weight Maintenance',
    'Muscle Growth',
    'Large Muscle Growth',
  ];
  final _dietaryHabitOptions = [
    'balanced',
    'high-protein',
    'high-fiber',
    'low-carb',
    'low-fat',
    'low-sodium',
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
    'Whole30',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _dailyCaloriesController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_hasUnsavedChanges()) {
      final shouldLeave = await _showSaveDialog();
      if (!shouldLeave || !mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: brandColor),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.surface),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint("Logout error: $e");
    }
  }

  double _dietGoalPercentOffset(String goal) {
    // Percent adjustment applied to estimated TDEE (BMR * activity).
    // Negative values are deficits; positive values are surpluses.
    switch (goal) {
      case 'Large Weight Loss':
        return -0.25;
      case 'Weight Loss':
        return -0.15;
      case 'Weight Maintenance':
        return 0.0;
      case 'Muscle Growth':
        return 0.10;
      case 'Large Muscle Growth':
        return 0.20;
      default:
        return 0.0;
    }
  }

  int _calculateDailyCalories() {
    final weight = double.tryParse(_weightController.text);
    if (_heightCm == null ||
        weight == null ||
        _sex == null ||
        _dob == null ||
        _dob!.isEmpty)
      return 0;

    try {
      final height = _heightCm!;
      final weightKg = weight / 2.2046226218;
      final dobDate = DateTime.parse(_normalizedDob(_dob) ?? _dob!);
      final now = DateTime.now();
      int age = now.year - dobDate.year;
      if (now.month < dobDate.month ||
          (now.month == dobDate.month && now.day < dobDate.day))
        age--;

      double bmr = (_sex == 'Male')
          ? (10 * weightKg) + (6.25 * height) - (5 * age) + 5
          : (10 * weightKg) + (6.25 * height) - (5 * age) - 161;

      final tdee = bmr * _activityLevel;
      final goalIndex = _dietaryGoal.toInt().clamp(0, _dietGoals.length - 1);
      final goal = _dietGoals[goalIndex];
      final target = tdee * (1.0 + _dietGoalPercentOffset(goal));
      return target.round();
    } catch (e) {
      return 0;
    }
  }

  Map<String, double> _recommendedMacroGoals() {
    double protein = 30;
    double carbs = 40;
    double fats = 30;

    /*switch (_activityLevel) {
      case 'Sedentary':
        protein += 2;
        carbs -= 5;
        fats += 3;
        break;
      case 'Lightly Active':
        break;
      case 'Moderately Active':
        protein += 2;
        carbs += 5;
        fats -= 7;
        break;
      case 'Very Active':
        protein += 5;
        carbs += 10;
        fats -= 15;
        break;
    }*/

    /*switch (_dietaryGoal) {
      case 'Lose Weight':
        protein += 10;
        carbs -= 7;
        fats -= 3;
        break;
      case 'Maintain Weight':
        break;
      case 'Gain Muscle':
        protein += 8;
        carbs += 8;
        fats -= 16;
        break;
    }*/

    for (final habit in _dietaryHabits) {
      switch (habit) {
        case 'high-protein':
          protein += 12;
          carbs -= 8;
          fats -= 4;
          break;
        case 'high-fiber':
          protein += 2;
          carbs += 4;
          fats -= 6;
          break;
        case 'low-carb':
          protein += 8;
          carbs -= 18;
          fats += 10;
          break;
        case 'low-fat':
          protein += 5;
          carbs += 6;
          fats -= 11;
          break;
        case 'balanced':
          protein += 2;
          carbs += 2;
          fats += 2;
          break;
        case 'low-sodium':
          break;
      }
    }

    protein = protein.clamp(15, 55).toDouble();
    carbs = carbs.clamp(15, 65).toDouble();
    fats = fats.clamp(15, 45).toDouble();

    final total = protein + carbs + fats;
    if (total <= 0) {
      return {'protein': 30, 'carbs': 40, 'fat': 30};
    }

    protein = (protein / total) * 100;
    carbs = (carbs / total) * 100;
    fats = 100 - protein - carbs;

    return {'protein': protein, 'carbs': carbs, 'fat': fats};
  }

  void _applyRecommendedMacroGoals({bool silent = false}) {
    final suggested = _recommendedMacroGoals();
    setState(() {
      _protein = suggested['protein']!;
      _carbs = suggested['carbs']!;
      _fats = suggested['fat']!;
      _refreshEditedState();
    });

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Suggestions are more accurate after selecting Activity Level and Dietary Goal.',
          ),
        ),
      );
    }
  }

  String _getInitials() {
    String initials = "";
    if (_firstname != null && _firstname!.isNotEmpty)
      initials += _firstname![0].toUpperCase();
    if (_lastname != null && _lastname!.isNotEmpty)
      initials += _lastname![0].toUpperCase();
    return initials.isEmpty ? "?" : initials;
  }

  String? _normalizedDob(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split('T')[0].split(' ')[0];
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  double? _parsedWeight() {
    final text = _weightController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int? _parsedDailyCalories() {
    final text = _dailyCaloriesController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Map<String, dynamic> _buildProfileSnapshot() {
    return {
      'sex': _sex,
      'activityLevel': _activityLevel,
      'dob': _normalizedDob(_dob),
      'height': _heightCm,
      'weight': _parsedWeight(),
      'mealProfile.dietaryGoal': _dietaryGoal,
      'mealProfile.macroGoals': {
        'protein': _protein,
        'carbs': _carbs,
        'fat': _fats,
      },
      'mealProfile.dietaryHabits': List<String>.from(_dietaryHabits),
      'mealProfile.healthRestrictions': List<String>.from(_health),
      'mealProfile.preferences.likes': List<String>.from(_likesList),
      'mealProfile.preferences.dislikes': List<String>.from(_dislikesList),
      'mealProfile.dailyCalorieGoal': _parsedDailyCalories(),
    };
  }

  Map<String, dynamic> _buildChangedProfileData() {
    final current = _buildProfileSnapshot();
    final changed = <String, dynamic>{};

    for (final entry in current.entries) {
      if (!_snapshotValueEquals(
        _savedProfileSnapshot[entry.key],
        entry.value,
      )) {
        changed[entry.key] = entry.value;
      }
    }

    return changed;
  }

  bool _hasUnsavedChanges() {
    return _buildChangedProfileData().isNotEmpty;
  }

  void _discardUnsavedChanges() {
    final snapshot = _savedProfileSnapshot;
    if (snapshot.isEmpty) {
      _isEdited = false;
      return;
    }

    _sex = snapshot['sex']?.toString();
    _activityLevel = _toDouble(snapshot['activityLevel']) ?? 1.0;
    _dob = snapshot['dob']?.toString() ?? '';
    _canEditDob = _dob != null && _dob!.isNotEmpty ? false : true;
    _heightCm = _toDouble(snapshot['height']);

    final savedWeight = _toDouble(snapshot['weight']);
    if (savedWeight != null) {
      _weightController.text = savedWeight % 1 == 0
          ? savedWeight.toInt().toString()
          : savedWeight.toString();
    } else {
      _weightController.clear();
    }

    _dietaryGoal = _toDouble(snapshot['mealProfile.dietaryGoal']) ?? 0.0;
    _dailyCaloriesController.text =
        _toInt(snapshot['mealProfile.dailyCalorieGoal'])?.toString() ?? '';

    final savedMacroGoals = _toMap(snapshot['mealProfile.macroGoals']);
    _protein = _toDouble(savedMacroGoals['protein']) ?? 0;
    _carbs = _toDouble(savedMacroGoals['carbs']) ?? 0;
    _fats = _toDouble(savedMacroGoals['fat']) ?? 0;

    _dietaryHabits = _toStringList(snapshot['mealProfile.dietaryHabits']);
    _health = _toStringList(snapshot['mealProfile.healthRestrictions']);
    _likesList = _toStringList(snapshot['mealProfile.preferences.likes']);
    _dislikesList = _toStringList(snapshot['mealProfile.preferences.dislikes']);
    _isEdited = false;
  }

  bool _snapshotValueEquals(dynamic oldValue, dynamic newValue) {
    if (oldValue is List && newValue is List) {
      return listEquals(oldValue, newValue);
    }
    if (oldValue is Map && newValue is Map) {
      return mapEquals(oldValue, newValue);
    }
    return oldValue == newValue;
  }

  void _refreshEditedState() {
    _isEdited = _hasUnsavedChanges();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc = await _firestore.collection('Users').doc(user!.uid).get();
      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          _savedProfileSnapshot = _buildProfileSnapshot();
          _isEdited = false;
        });
        return;
      }
      final data = doc.data()!;
      if (!mounted) return;
      setState(() {
        _firstname = data['firstname']?.toString();
        _lastname = data['lastname']?.toString();
        _email = user!.email;
        final rawDob = data['dob']?.toString().trim();
        if (rawDob != null && rawDob.isNotEmpty) {
          _dob = rawDob.split('T')[0].split(' ')[0];
          _canEditDob = false;
        } else {
          _dob = '';
          _canEditDob = true;
        }
        _sex = data['sex']?.toString();
        _heightCm = _toDouble(data['height']);

        final weight = _toDouble(data['weight']);
        if (weight != null) {
          _weightController.text = weight % 1 == 0
              ? weight.toInt().toString()
              : weight.toString();
        } else {
          _weightController.clear();
        }

        _activityLevel = _toDouble(data['activityLevel']) ?? 1.0;
        final mealProfile = _toMap(data['mealProfile']);
        _dietaryGoal = _toDouble(mealProfile['dietaryGoal']) ?? 0.0;
        _dailyCaloriesController.text =
            _toInt(mealProfile['dailyCalorieGoal'])?.toString() ?? '';

        final macroGoals = _toMap(mealProfile['macroGoals']);
        _protein = _toDouble(macroGoals['protein']) ?? 0;
        _carbs = _toDouble(macroGoals['carbs']) ?? 0;
        _fats = _toDouble(macroGoals['fat'] ?? macroGoals['fats']) ?? 0;

        _dietaryHabits = _toStringList(mealProfile['dietaryHabits']);
        _health = _toStringList(mealProfile['healthRestrictions']);

        final prefs = _toMap(mealProfile['preferences']);
        _likesList = _toStringList(prefs['likes']);
        _dislikesList = _toStringList(prefs['dislikes']);
        _savedProfileSnapshot = _buildProfileSnapshot();
        _isEdited = false;
      });
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null || !_formKey.currentState!.validate()) return;
    final updateData = _buildChangedProfileData();
    if (updateData.isEmpty) {
      if (mounted) {
        setState(() => _isEdited = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No changes to save.')));
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('Users').doc(user!.uid).update(updateData);
      if (mounted) {
        setState(() {
          if (_normalizedDob(_dob) != null) _canEditDob = false;
          _savedProfileSnapshot = _buildProfileSnapshot();
          _isEdited = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showSaveDialog() async {
    final hasUnsavedChanges = _hasUnsavedChanges();
    if (!hasUnsavedChanges || _isShowingSaveDialog) return !hasUnsavedChanges;
    _isShowingSaveDialog = true;

    try {
      final shouldLeave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        builder: (dialogContext) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            title: const Text('Save Changes', textAlign: TextAlign.center),
            content: const Text(
              'Would you like to save your changes?',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    setState(_discardUnsavedChanges);
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text(
                  'Discard',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        await _saveProfile();
                        if (!dialogContext.mounted) return;
                        if (!_isEdited) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: brandColor),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: AppColors.surface),
                ),
              ),
            ],
          ),
        ),
      );

      return shouldLeave ?? false;
    } finally {
      _isShowingSaveDialog = false;
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    String? passwordError;
    bool isDeleting = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Confirm Account Deletion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To permanently delete your account, please enter your password.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onChanged: (_) {
                    if (passwordError != null) {
                      setDialogState(() => passwordError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    errorText: passwordError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: deleteColor),
                onPressed: isDeleting
                    ? null
                    : () async {
                        if (passwordController.text.trim().isEmpty) {
                          setDialogState(
                            () => passwordError = 'Please enter your password',
                          );
                          return;
                        }
                        final nav = Navigator.of(context);
                        setDialogState(() => isDeleting = true);
                        try {
                          final credential = EmailAuthProvider.credential(
                            email: user!.email!,
                            password: passwordController.text.trim(),
                          );
                          await user!.reauthenticateWithCredential(credential);
                          await _firestore
                              .collection('Users')
                              .doc(user!.uid)
                              .delete();
                          await user!.delete();
                          if (mounted) {
                            nav.pop();
                            nav.pushReplacementNamed(
                              '/login',
                              arguments: 'accountDeleted',
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isDeleting = false;
                            passwordError =
                                'Incorrect password. Please try again.';
                          });
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.surface,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Delete Account',
                        style: TextStyle(color: AppColors.surface),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHeightPicker() {
    int currentFt = _heightCm != null ? (_heightCm! / 2.54 ~/ 12) : 5;
    int currentIn = _heightCm != null ? (_heightCm! / 2.54 % 12).round() : 7;

    showCupertinoModalPopup(
      context: context,
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    const Text(
                      "Height",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: currentFt - 1,
                              ),
                              itemExtent: 40,
                              looping: true,
                              onSelectedItemChanged: (index) {
                                currentFt = index + 1;
                                _updateHeight(currentFt, currentIn);
                              },
                              children: List.generate(
                                8,
                                (i) => Center(child: Text('${i + 1} ft')),
                              ),
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: currentIn,
                              ),
                              itemExtent: 40,
                              looping: true,
                              onSelectedItemChanged: (index) {
                                currentIn = index;
                                _updateHeight(currentFt, currentIn);
                              },
                              children: List.generate(
                                12,
                                (i) => Center(child: Text('$i in')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Done",
                        style: TextStyle(
                          color: brandColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateHeight(int ft, int inches) {
    setState(() {
      _heightCm = (ft * 12 + inches) * 2.54;
      _refreshEditedState();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    final estimatedCals = _calculateDailyCalories();
    final suggestedMacros = _recommendedMacroGoals();

    String ftText = "5";
    String inText = "7";
    if (_heightCm != null) {
      double totalInches = _heightCm! / 2.54;
      ftText = (totalInches ~/ 12).toString();
      inText = (totalInches.round() % 12).toString();
    }

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _showSaveDialog();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.isInPageView
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () async {
                    if (_hasUnsavedChanges()) {
                      final shouldLeave = await _showSaveDialog();
                      if (shouldLeave && context.mounted) {
                        Navigator.pop(context);
                      }
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.textSecondary),
              onPressed: _logout,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: brandColor,
                      child: Text(
                        _getInitials(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_firstname $_lastname',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    _buildStatBoxes(estimatedCals),

                    const SizedBox(height: 30),
                    _sectionHeader("User"),
                    _buildCard([
                      _buildListTile(
                        Icons.email_outlined,
                        "Email",
                        _email ?? "",
                      ),
                      _buildListTile(
                        Icons.calendar_today,
                        "DOB",
                        (_dob == null || _dob!.isEmpty) ? "Not set" : _dob!,
                        onTap: _canEditDob
                            ? () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(2000),
                                  firstDate: DateTime(1920),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: brandColor,
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (pickedDate != null)
                                  setState(() {
                                    _dob = pickedDate.toString().split(' ')[0];
                                    _refreshEditedState();
                                  });
                              }
                            : null,
                      ),
                      _buildListTile(
                        Icons.wc,
                        "Sex",
                        _sex ?? "Not Set",
                        onTap: () => _showPicker(
                          "Sex",
                          ['Male', 'Female'],
                          _sex,
                          (v) => setState(() {
                            _sex = v;
                            _refreshEditedState();
                          }),
                        ),
                      ),
                      _buildActivitySlider(),
                      _buildDietaryGoalSlider(),

                      /*_buildListTile(
                      Icons.bolt,
                      "Activity Level",
                      _activityLevel ?? "Select",
                      onTap: () => _showPicker(
                        "Activity",
                        _activityLevels,
                        _activityLevel,
                        (v) {
                          setState(() => _activityLevel = v);
                          _applyRecommendedMacroGoals(silent: true);
                        },
                      ),
                    ),*/
                      /*_buildListTile(
                      Icons.track_changes,
                      "Dietary Goal",
                      _dietaryGoal ?? "Select",
                      onTap: () => _showPicker(
                        "Diet Goal",
                        _dietGoals,
                        _dietaryGoal,
                        (v) {
                          setState(() => _dietaryGoal = v);
                          _applyRecommendedMacroGoals(silent: true);
                        },
                      ),
                    ),*/
                    ]),
                    const SizedBox(height: 25),
                    _sectionHeader("Meal Profile"),
                    _buildCard([
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 20.0,
                          left: 16.0,
                          right: 16.0,
                          bottom: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Macronutrient Goals",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 16),
                            MacroSlider(
                              key: ValueKey(
                                'macro-${_protein.toStringAsFixed(2)}-${_carbs.toStringAsFixed(2)}-${_fats.toStringAsFixed(2)}',
                              ),
                              protein: _protein,
                              carbs: _carbs,
                              fats: _fats,
                              onChanged: (p, c, f) => setState(() {
                                _protein = p;
                                _carbs = c;
                                _fats = f;
                                _refreshEditedState();
                              }),
                            ),
                            const SizedBox(height: 8),
                            /*Text(
                            'Suggested values:\nP ${suggestedMacros['protein']!.round()}% • C ${suggestedMacros['carbs']!.round()}% • F ${suggestedMacros['fat']!.round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _applyRecommendedMacroGoals,
                              child: const Text('Use Suggested'),
                            ),
                          ),*/
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMultiSelectTile(
                        "Macronutrient Goal Presets",
                        _dietaryHabitOptions,
                        _dietaryHabits,
                        onChanged: () =>
                            _applyRecommendedMacroGoals(silent: true),
                      ),
                      const Divider(height: 1),
                      _buildMultiSelectTile(
                        "Health & Dietary Restrictions",
                        _healthOptions,
                        _health,
                      ),
                      const Divider(height: 1),
                      _buildBubbleInput("Likes", _likesController, _likesList),
                      const Divider(height: 1),
                      _buildBubbleInput(
                        "Dislikes",
                        _dislikesController,
                        _dislikesList,
                      ),
                    ]),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isEdited && !_isSaving
                            ? _saveProfile
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: AppColors.surface,
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _confirmDeleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deleteColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: _isDeleting
                            ? const CircularProgressIndicator(
                                color: AppColors.surface,
                              )
                            : const Text(
                                "Delete Account",
                                style: TextStyle(
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: widget.isInPageView
            ? NavBar(
                currentIndex: navIndexProfile,
                onTap: (index) async {
                  if (index == navIndexProfile) return;
                  final navContext = context;
                  if (_hasUnsavedChanges()) {
                    final shouldLeave = await _showSaveDialog();
                    if (!shouldLeave || !navContext.mounted) return;
                  }
                  if (!navContext.mounted) return;
                  handleNavTap(navContext, index);
                },
              )
            : null,
      ),
    );
  }

  Widget _buildBubbleInput(
    String title,
    TextEditingController controller,
    List<String> list,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: "Add $title",
                    hintText: "Letters only",
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    String filtered = value.replaceAll(
                      RegExp(r'[^a-zA-Z\s]'),
                      '',
                    );
                    if (filtered != value) {
                      controller.text = filtered;
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: brandColor),
                onPressed: () {
                  final item = controller.text.trim();
                  if (item.isNotEmpty && !list.contains(item)) {
                    setState(() {
                      list.add(item);
                      controller.clear();
                      _refreshEditedState();
                    });
                  }
                },
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: list
                .map(
                  (item) => Chip(
                    label: Text(item, style: const TextStyle(fontSize: 12)),
                    backgroundColor: brandColor.withOpacity(0.1),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() {
                      list.remove(item);
                      _refreshEditedState();
                    }),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBoxes(int estimatedCals) {
    final stats = <Widget>[
      GestureDetector(
        onTap: _showHeightPicker,
        child: _buildStatBox(
          "Height",
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _heightCm != null
                  ? "${(_heightCm! / 2.54 ~/ 12)}'${(_heightCm! / 2.54).round() % 12}\""
                  : "5'7\"",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
      _buildStatBox("Weight", controller: _weightController, suffixText: "lbs"),
      _buildStatBox(
        "Daily Cal",
        controller: _dailyCaloriesController,
        isPrimary: true,
        helperText: estimatedCals > 0 ? "$estimatedCals" : null,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: stats[0]),
        const SizedBox(width: 10),
        Expanded(child: stats[1]),
        const SizedBox(width: 10),
        Expanded(child: stats[2]),
      ],
    );
  }

  Widget _buildStatBox(
    String label, {
    TextEditingController? controller,
    Widget? child,
    bool isPrimary = false,
    String? helperText,
    String? suffixText,
  }) {
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.4).toDouble();
    final boxHeight = 80.0 * textScale;
    final helperHeight = 18.0 * textScale;
    final fieldWidth = 75.0 + ((textScale - 1.0) * 28.0);

    return Column(
      children: [
        Container(
          height: boxHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isPrimary ? brandColor : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.02),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child ??
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: label == "Weight"
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.number,
                      inputFormatters: label == "Weight"
                          ? [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d*'),
                              ),
                            ]
                          : [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(_refreshEditedState),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        suffixText: suffixText,
                        suffixStyle: TextStyle(
                          fontSize: 12,
                          color: isPrimary
                              ? AppColors.surface.withValues(alpha: 0.7)
                              : AppColors.statusNone,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPrimary
                            ? AppColors.surface
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isPrimary
                        ? AppColors.surface.withValues(alpha: 0.7)
                        : AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
        // FIXED: This SizedBox keeps the boxes aligned even when no helper text is present
        SizedBox(
          height: helperHeight,
          child: helperText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Est: $helperText",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHint,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String value, {
    VoidCallback? onTap,
  }) {
    final displayValue = value.isEmpty ? "Not set" : value;

    return InkWell(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final stackValue = textScale > 1.2 || constraints.maxWidth < 330;

          if (stackValue) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: brandColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      displayValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: brandColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    displayValue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDietaryGoalSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: brandColor, size: 22),
              const Text(
                "  Dietary Goal",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                ),
                onPressed: _showDietaryGoalInfo,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dietary Goal Definitions',
              ),
            ],
          ),
          Slider(
            value: _dietaryGoal,
            min: 0,
            max: 4,
            divisions: 4,
            label: _dietGoals[_dietaryGoal.toInt()],
            onChanged: (value) {
              setState(() {
                _dietaryGoal = value;
                _refreshEditedState();
              });
              _applyRecommendedMacroGoals(silent: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: brandColor, size: 22),
              const Text(
                "  Activity Level",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                ),
                onPressed: _showActivityLevelInfo,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Activity Level Definitions',
              ),
            ],
          ),
          Slider(
            value: _activityLevel,
            min: 1.0,
            max: 1.9,
            divisions: 5,
            label: activityLevelLabels(_activityLevel),
            onChanged: (value) {
              setState(() {
                _activityLevel = value;
                _refreshEditedState();
              });
              _applyRecommendedMacroGoals(silent: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectTile(
    String title,
    List<String> options,
    List<String> selected, {
    VoidCallback? onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10.0, bottom: 5),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((opt) {
            final isSel = selected.contains(opt);
            return ChoiceChip(
              label: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  color: isSel ? AppColors.surface : AppColors.textPrimary,
                ),
              ),
              selected: isSel,
              selectedColor: brandColor,
              backgroundColor: bgColor.withOpacity(0.5),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    if (!selected.contains(opt)) selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                  _refreshEditedState();
                });
                onChanged?.call();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  //STRING FUNC FOR SHOWING THE ACTIVITY LEVEL IN THE SLIDER
  String activityLevelLabels(double value) {
    if (value == 1.0)
      return 'Completely Sedentary';
    else if (value > 1.0 && value <= 1.25)
      return 'Basic Daily Activity';
    else if (value > 1.25 && value <= 1.45)
      return 'Lightly Active';
    else if (value > 1.45 && value <= 1.65)
      return 'Moderately Active';
    else if (value > 1.65 && value <= 1.8)
      return 'Very Active';
    else if (value > 1.8)
      return 'Daily Athlete';
    return 'NA';
  }

  void _showPicker(
    String title,
    List<String> options,
    String? current,
    Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map(
                      (o) => ListTile(
                        title: Text(o, textAlign: TextAlign.center),
                        onTap: () {
                          onSelect(o);
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDietaryGoalInfo() {
    final dietGoalsInfo = [
      {
        'goal': 'Large Weight Loss',
        'definition':
            'Targets an aggressive deficit (about 25% below estimated maintenance). Actual weekly change varies by person.',
      },
      {
        'goal': 'Weight Loss',
        'definition':
            'Targets a moderate deficit (about 15% below estimated maintenance). Actual weekly change varies by person.',
      },
      {
        'goal': 'Weight Maintenance',
        'definition':
            'Targets estimated maintenance calories (no deficit or surplus applied).',
      },
      {
        'goal': 'Muscle Growth',
        'definition':
            'Targets a small surplus (about 10% above estimated maintenance) to support training and recovery.',
      },
      {
        'goal': 'Large Muscle Growth',
        'definition':
            'Targets a larger surplus (about 20% above estimated maintenance). This can increase fat gain for some people.',
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dietary Goal Definitions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: dietGoalsInfo.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final info = dietGoalsInfo[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  info['goal']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(info['definition']!),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActivityLevelInfo() {
    final activityLevelsInfo = [
      {
        'level': 'Completely Sedentary',
        'definition': 'Little to no walking or cycling. 0-1 hours per week.',
      },
      {
        'level': 'Basic Daily Activity',
        'definition':
            'Minimal physical activity (e.g., walking to car, light housework).',
      },
      {
        'level': 'Lightly Active',
        'definition': 'Light exercise or sports 1-3 days per week.',
      },
      {
        'level': 'Moderately Active',
        'definition': 'Moderate exercise or sports 3-5 days per week.',
      },
      {
        'level': 'Very Active',
        'definition':
            'Hard exercise (elevated heart rate for 30+ minutes) or sports 5-6 days a week.',
      },
      {
        'level': 'Daily Athlete',
        'definition':
            'Hard exercise/sports every day, often with a physical job.',
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Level Definitions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: activityLevelsInfo.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final info = activityLevelsInfo[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  info['level']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(info['definition']!),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
