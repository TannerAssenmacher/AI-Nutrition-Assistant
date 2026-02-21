import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';

import '../services/food_search_service.dart';
import '../services/meal_analysis_service.dart';
import '../db/food.dart';
import '../providers/food_providers.dart';
import '../providers/firestore_providers.dart';
import '../theme/app_colors.dart';
import 'camera_capture_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final bool isInPageView;
  final bool isActive;

  const CameraScreen({
    super.key,
    this.isInPageView = false,
    this.isActive = true,
  });

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  bool _isAnalyzing = false;
  bool _isLookingUpBarcode = false;
  bool _isSaving = false;
  bool _hasAutoCaptureRunForCurrentActivation = false;
  MealAnalysis? _analysisResult;
  String? _errorMessage;
  AnalysisStage? _analysisStage;
  final FoodSearchService _foodSearchService = FoodSearchService();

  @override
  void initState() {
    super.initState();
    _tryAutoCaptureOnActivation();
  }

  @override
  void didUpdateWidget(covariant CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _hasAutoCaptureRunForCurrentActivation = false;
      _tryAutoCaptureOnActivation();
    } else if (oldWidget.isActive && !widget.isActive) {
      _hasAutoCaptureRunForCurrentActivation = false;
    }
  }

  void _tryAutoCaptureOnActivation() {
    if (!widget.isActive || _hasAutoCaptureRunForCurrentActivation) {
      return;
    }

    _hasAutoCaptureRunForCurrentActivation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) {
        return;
      }
      _captureAndAnalyze();
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_isAnalyzing || _isLookingUpBarcode) return;

    final captureResult = await Navigator.of(context).push<MealCaptureResult?>(
      MaterialPageRoute<MealCaptureResult?>(
        builder: (_) => const CameraCaptureScreen(),
        settings: const RouteSettings(name: '/camera/capture'),
      ),
    );

    if (captureResult == null || !mounted) {
      return;
    }

    if (captureResult.mode == CaptureMode.barcode) {
      await _handleBarcodeLookup(captureResult.barcode);
      return;
    }

    final photo = captureResult.photo;
    if (photo == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo captured. Please try again.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _errorMessage = null;
      _analysisStage = AnalysisStage.uploading;
    });

    final file = File(photo.path);
    final service = MealAnalysisService();

    try {
      final analysis = await service.analyzeMealImage(
        file,
        userContext: captureResult.userContext,
        onStageChanged: (stage) {
          if (!mounted) return;
          setState(() {
            _analysisStage = stage;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _analysisResult = analysis;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meal analysis complete!')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = _buildAnalyzeMealErrorMessage(e);
      setState(() {
        _errorMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Analysis failed: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStage = null;
        });
      }
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  Future<void> _handleBarcodeLookup(String? rawBarcode) async {
    final scannedBarcode = (rawBarcode ?? '').trim();
    if (scannedBarcode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanned barcode was empty.')),
      );
      return;
    }
    final displayBarcode = FoodSearchService.canonicalBarcode(scannedBarcode);
    final barcodeForMessages = displayBarcode.isEmpty
        ? scannedBarcode
        : displayBarcode;

    setState(() {
      _isLookingUpBarcode = true;
      _errorMessage = null;
    });

    try {
      final result = await _foodSearchService
          .lookupFoodByBarcode(scannedBarcode)
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found for barcode $barcodeForMessages.'),
          ),
        );
        return;
      }

      final wasAdded = await _showBarcodeFoodDialog(result);
      if (!mounted || !wasAdded) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "${result.name}" to your daily log.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = _buildBarcodeLookupErrorMessage(
        e,
        barcodeForMessages: barcodeForMessages,
      );
      setState(() {
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      final message =
          'Barcode lookup timed out. Check your connection and try again.';
      setState(() {
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = 'Barcode lookup failed: $e';
      setState(() {
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUpBarcode = false;
        });
      }
    }
  }

  Future<bool> _showBarcodeFoodDialog(FoodSearchResult result) async {
    final wasAdded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _BarcodeFoodDialog(
          result: result,
          onAdd: (grams, mealType, servingOption) async {
            final userId = FirebaseAuth.instance.currentUser?.uid;
            if (userId == null) {
              throw StateError('Please sign in to save scanned foods.');
            }

            final consumedAt = DateTime.now();
            final item = FoodItem(
              id: 'barcode-${DateTime.now().microsecondsSinceEpoch}',
              name: result.name,
              mass_g: grams,
              calories_g: servingOption.caloriesPerGram,
              protein_g: servingOption.proteinPerGram,
              carbs_g: servingOption.carbsPerGram,
              fat: servingOption.fatPerGram,
              mealType: mealType,
              consumedAt: consumedAt,
            );

            ref.read(foodLogProvider.notifier).addFoodItem(item);
            await ref
                .read(firestoreFoodLogProvider(userId).notifier)
                .addFood(userId, item);
          },
        );
      },
    );

    return wasAdded ?? false;
  }

  String _formatCompactNumber(double value, {int maxDecimals = 1}) {
    final safeValue = value.isFinite ? value : 0;
    final normalized = safeValue.abs() < 0.0000001 ? 0 : safeValue;
    if (maxDecimals <= 0) {
      return normalized.round().toString();
    }

    final fixed = normalized.toStringAsFixed(maxDecimals);
    final withoutTrailingZeros = fixed.replaceFirst(RegExp(r'0+$'), '');
    return withoutTrailingZeros.replaceFirst(RegExp(r'\.$'), '');
  }

  String _buildAnalyzeMealErrorMessage(FirebaseFunctionsException e) {
    if (_isMissingCallable(e)) {
      return 'Cloud Function analyzeMealImage was not found. Deploy Functions to us-central1 for project ai-nutrition-assistant-e2346.';
    }
    if (e.code == 'unauthenticated') {
      return 'Please sign in to analyze meals.';
    }
    if (e.code == 'permission-denied') {
      return 'Permission denied while analyzing meal. Check Firebase auth rules and App Check settings.';
    }
    return e.message ?? 'Meal analysis failed. Please try again.';
  }

  String _buildBarcodeLookupErrorMessage(
    FirebaseFunctionsException e, {
    required String barcodeForMessages,
  }) {
    if (_isMissingCallable(e)) {
      return 'Cloud Function lookupFoodByBarcode was not found. Deploy Functions to us-central1 for project ai-nutrition-assistant-e2346.';
    }
    if (e.code == 'not-found') {
      return 'No food found for barcode $barcodeForMessages.';
    }
    if (e.code == 'unauthenticated') {
      return 'Please sign in to log scanned foods.';
    }
    if (e.code == 'invalid-argument') {
      return 'Invalid barcode. Please scan again.';
    }
    return e.message ?? 'Barcode lookup failed. Please try again.';
  }

  bool _isMissingCallable(FirebaseFunctionsException e) {
    if (e.code != 'not-found') {
      return false;
    }
    final message = (e.message ?? '').toLowerCase();
    if (message.isEmpty) {
      return true;
    }
    return message.contains('not found') ||
        message.contains('function') ||
        message.contains('callable');
  }

  Future<void> _addMealToCalendar() async {
    final analysis = _analysisResult;
    if (analysis == null || analysis.foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No analysis to add. Capture a meal first.'),
        ),
      );
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final container = ProviderScope.containerOf(context, listen: false);
      final notifier = container.read(foodLogProvider.notifier);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to save meals to your calendar.'),
          ),
        );
        return;
      }

      final firestoreLog = container.read(
        firestoreFoodLogProvider(userId).notifier,
      );
      int added = 0;

      for (final food in analysis.foods) {
        if (food.mass <= 0) {
          continue;
        }

        final mass = food.mass;
        final caloriesPerGram = food.calories / mass;
        final proteinPerGram = food.protein / mass;
        final carbsPerGram = food.carbs / mass;
        final fatPerGram = food.fat / mass;

        notifier.addFoodItem(
          FoodItem(
            id: '${now.microsecondsSinceEpoch}-$added',
            name: food.name,
            mass_g: mass,
            calories_g: caloriesPerGram,
            protein_g: proteinPerGram,
            carbs_g: carbsPerGram,
            fat: fatPerGram,
            mealType: 'meal',
            consumedAt: now,
          ),
        );

        await firestoreLog.addFood(
          userId,
          FoodItem(
            id: '${now.microsecondsSinceEpoch}-$added',
            name: food.name,
            mass_g: mass,
            calories_g: caloriesPerGram,
            protein_g: proteinPerGram,
            carbs_g: carbsPerGram,
            fat: fatPerGram,
            mealType: 'meal',
            consumedAt: now,
          ),
        );

        added++;
      }

      if (!mounted) return;

      final message = added > 0
          ? 'Added $added item${added == 1 ? '' : 's'} to today.'
          : 'No items added (missing weights).';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateItemName(int index, String newName) {
    final current = _analysisResult;
    if (current == null || index < 0 || index >= current.foods.length) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final updatedFoods = List<AnalyzedFoodItem>.from(current.foods);
    final item = updatedFoods[index];
    updatedFoods[index] = AnalyzedFoodItem(
      name: trimmed,
      mass: item.mass,
      calories: item.calories,
      protein: item.protein,
      carbs: item.carbs,
      fat: item.fat,
    );

    setState(() {
      _analysisResult = MealAnalysis(foods: updatedFoods);
    });
  }

  void _updateItemWeight(int index, double newMass) {
    final current = _analysisResult;
    if (current == null || index < 0 || index >= current.foods.length) return;
    if (newMass <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight must be greater than 0.')),
      );
      return;
    }

    final updatedFoods = List<AnalyzedFoodItem>.from(current.foods);
    final item = updatedFoods[index];
    if (item.mass <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original weight missing; cannot adjust macros.'),
        ),
      );
      return;
    }

    // Derive per-gram macros from the original AI estimate, then scale to the new mass.
    final proteinPerGram = item.protein / item.mass;
    final carbsPerGram = item.carbs / item.mass;
    final fatPerGram = item.fat / item.mass;

    final protein = proteinPerGram * newMass;
    final carbs = carbsPerGram * newMass;
    final fat = fatPerGram * newMass;
    final calories = protein * 4 + carbs * 4 + fat * 9;

    updatedFoods[index] = AnalyzedFoodItem(
      name: item.name,
      mass: newMass,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    setState(() {
      _analysisResult = MealAnalysis(foods: updatedFoods);
    });
  }

  Future<void> _promptEditName(int index) async {
    final current = _analysisResult;
    if (current == null || index < 0 || index >= current.foods.length) return;
    final controller = TextEditingController(text: current.foods[index].name);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit item name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (_) {
            _updateItemName(index, controller.text);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateItemName(index, controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptEditWeight(int index) async {
    final current = _analysisResult;
    if (current == null || index < 0 || index >= current.foods.length) return;
    final controller = TextEditingController(
      text: current.foods[index].mass.toStringAsFixed(0),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit weight (grams)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Weight in grams',
            hintText: 'e.g. 150',
          ),
          onSubmitted: (_) {
            final parsed = double.tryParse(controller.text.trim());
            if (parsed != null) {
              _updateItemWeight(index, parsed);
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null) {
                _updateItemWeight(index, parsed);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLookingUpBarcode) {
      return const _AnalyzingState(labelOverride: 'Looking up barcode…');
    }

    if (_isAnalyzing) {
      return _AnalyzingState(stage: _analysisStage);
    }

    if (_analysisResult != null) {
      return MealAnalysisResultWidget(
        key: const ValueKey('analysis_result'),
        analysis: _analysisResult!,
        onCapture: _captureAndAnalyze,
        onEditName: _promptEditName,
        onEditWeight: _promptEditWeight,
        onAddToCalendar: _addMealToCalendar,
        isSavingToCalendar: _isSaving,
      );
    }

    return _IdleState(
      key: const ValueKey('idle_state'),
      onCapture: _captureAndAnalyze,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _buildCameraContent(context);
    final isBusy = _isAnalyzing || _isLookingUpBarcode;

    final fab = FloatingActionButton.extended(
      onPressed: isBusy ? null : _captureAndAnalyze,
      backgroundColor: AppColors.success,
      icon: isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface),
              ),
            )
          : const Icon(Icons.camera_alt),
      label: Text(
        _isAnalyzing
            ? 'Analyzing...'
            : _isLookingUpBarcode
                ? 'Looking up...'
                : 'Capture meal',
      ),
    );

    if (widget.isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexCamera,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  Widget _buildCameraContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              _ErrorBanner(message: _errorMessage!),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeMacroRow extends StatelessWidget {
  final String label;
  final String value;

  const _BarcodeMacroRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeFoodDialog extends StatefulWidget {
  final FoodSearchResult result;
  final Future<void> Function(
    double grams,
    String mealType,
    FoodServingOption servingOption,
  )
  onAdd;

  const _BarcodeFoodDialog({required this.result, required this.onAdd});

  @override
  State<_BarcodeFoodDialog> createState() => _BarcodeFoodDialogState();
}

class _BarcodeFoodDialogState extends State<_BarcodeFoodDialog> {
  late final List<FoodServingOption> _availableServings;
  late FoodServingOption _selectedServing;
  late final TextEditingController _gramsController;
  late final FocusNode _gramsFocusNode;
  String _mealType = 'snack';
  int _quantity = 1;
  bool _useCustomGrams = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _availableServings = widget.result.servingOptions.isEmpty
        ? [widget.result.defaultServingOption]
        : widget.result.servingOptions;
    _selectedServing = _availableServings.firstWhere(
      (option) => option.isDefault,
      orElse: () => _availableServings.first,
    );
    _gramsController = TextEditingController(
      text: _formatCompactNumber(
        _selectedServing.grams * _quantity,
        maxDecimals: 0,
      ),
    );
    _gramsFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _gramsFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String _formatCompactNumber(double value, {int maxDecimals = 1}) {
    final safeValue = value.isFinite ? value : 0;
    final normalized = safeValue.abs() < 0.0000001 ? 0 : safeValue;
    if (maxDecimals <= 0) {
      return normalized.round().toString();
    }

    final fixed = normalized.toStringAsFixed(maxDecimals);
    final withoutTrailingZeros = fixed.replaceFirst(RegExp(r'0+$'), '');
    return withoutTrailingZeros.replaceFirst(RegExp(r'\.$'), '');
  }

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _handleAdd() async {
    final grams = _useCustomGrams
        ? double.tryParse(_gramsController.text.trim())
        : (_selectedServing.grams * _quantity);
    if (grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid grams amount.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onAdd(grams, _mealType, _selectedServing);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultGrams = _selectedServing.grams * _quantity;
    final previewInput = _useCustomGrams
        ? (double.tryParse(_gramsController.text.trim()) ?? defaultGrams)
        : defaultGrams;
    final gramsPreview = previewInput > 0 ? previewInput : 0;
    final previewCalories = _selectedServing.caloriesPerGram * gramsPreview;
    final previewProtein = _selectedServing.proteinPerGram * gramsPreview;
    final previewCarbs = _selectedServing.carbsPerGram * gramsPreview;
    final previewFat = _selectedServing.fatPerGram * gramsPreview;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Center(
          child: AlertDialog(
            title: const Text('Scanned Food'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.result.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((widget.result.brand ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.result.brand!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _mealType,
                    decoration: const InputDecoration(labelText: 'Meal type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                      DropdownMenuItem(value: 'snack', child: Text('Snack')),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _mealType = value;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FoodServingOption>(
                    initialValue: _selectedServing,
                    decoration: const InputDecoration(
                      labelText: 'Serving size',
                    ),
                    items: _availableServings
                        .map(
                          (option) => DropdownMenuItem<FoodServingOption>(
                            value: option,
                            child: Text(
                              '${option.description} (${_formatCompactNumber(option.grams, maxDecimals: 0)} g)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedServing = value;
                              if (!_useCustomGrams) {
                                _gramsController.text = _formatCompactNumber(
                                  _selectedServing.grams * _quantity,
                                  maxDecimals: 0,
                                );
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _quantity,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    items: List.generate(
                      6,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _quantity = value;
                              if (!_useCustomGrams) {
                                _gramsController.text = _formatCompactNumber(
                                  _selectedServing.grams * _quantity,
                                  maxDecimals: 0,
                                );
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _useCustomGrams,
                    title: const Text('Override grams'),
                    subtitle: Text(
                      _useCustomGrams
                          ? 'Custom grams will be used.'
                          : 'Using ${_formatCompactNumber(defaultGrams, maxDecimals: 0)} g from serving × quantity.',
                    ),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _useCustomGrams = value;
                              if (!_useCustomGrams) {
                                _gramsController.text = _formatCompactNumber(
                                  _selectedServing.grams * _quantity,
                                  maxDecimals: 0,
                                );
                              }
                            });
                          },
                  ),
                  if (_useCustomGrams) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gramsController,
                      focusNode: _gramsFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Custom grams',
                        helperText:
                            'FatSecret reference: ${_formatCompactNumber(defaultGrams, maxDecimals: 0)} g',
                        suffixIcon: IconButton(
                          tooltip: 'Done',
                          icon: const Icon(Icons.check),
                          onPressed: _dismissKeyboard,
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                      onSubmitted: (_) => _dismissKeyboard(),
                      onTapOutside: (_) => _dismissKeyboard(),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'FatSecret reference: ${_formatCompactNumber(defaultGrams, maxDecimals: 0)} g',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _BarcodeMacroRow(
                    label: 'Calories',
                    value:
                        '${_formatCompactNumber(previewCalories, maxDecimals: 0)} Cal',
                  ),
                  _BarcodeMacroRow(
                    label: 'Protein',
                    value:
                        '${_formatCompactNumber(previewProtein, maxDecimals: 1)} g',
                  ),
                  _BarcodeMacroRow(
                    label: 'Carbs',
                    value:
                        '${_formatCompactNumber(previewCarbs, maxDecimals: 1)} g',
                  ),
                  _BarcodeMacroRow(
                    label: 'Fat',
                    value:
                        '${_formatCompactNumber(previewFat, maxDecimals: 1)} g',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.result.sourceLabel,
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        _dismissKeyboard();
                        Navigator.of(context).pop(false);
                      },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _isSaving ? null : _handleAdd,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add to log'),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          child: IgnorePointer(
            ignoring: !keyboardVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: keyboardVisible ? 1 : 0,
              child: Material(
                color: AppColors.textPrimary,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.check, color: AppColors.surface),
                  onPressed: _dismissKeyboard,
                  tooltip: 'Done',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyzingState extends StatelessWidget {
  final AnalysisStage? stage;
  final String? labelOverride;

  const _AnalyzingState({this.stage, this.labelOverride});

  String get _label {
    if (labelOverride != null && labelOverride!.trim().isNotEmpty) {
      return labelOverride!;
    }

    switch (stage) {
      case AnalysisStage.uploading:
        return 'Uploading photo…';
      case AnalysisStage.analyzing:
        return 'Analyzing meal…';
      case AnalysisStage.cleaning:
        return 'Wrapping up…';
      default:
        return 'Working on your meal…';
    }
  }

  double? get _progressValue {
    switch (stage) {
      case AnalysisStage.uploading:
        return 1 / 3;
      case AnalysisStage.analyzing:
        return 2 / 3;
      case AnalysisStage.cleaning:
        return 1.0;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progressValue;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(_label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            Text(
              'Step ${(progress * 3).clamp(1, 3).round()} of 3',
              style: TextStyle(color: AppColors.textHint),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  final VoidCallback onCapture;

  const _IdleState({super.key, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt, size: 60, color: AppColors.statusNone),
          const SizedBox(height: 10),
          Text('No photo captured yet', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture meal'),
          ),
        ],
      ),
    );
  }
}

class _EditableChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditableChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget to display the meal analysis results.
class MealAnalysisResultWidget extends StatelessWidget {
  final MealAnalysis analysis;
  final VoidCallback onCapture;
  final void Function(int) onEditName;
  final void Function(int) onEditWeight;
  final Future<void> Function() onAddToCalendar;
  final bool isSavingToCalendar;

  const MealAnalysisResultWidget({
    super.key,
    required this.analysis,
    required this.onCapture,
    required this.onEditName,
    required this.onEditWeight,
    required this.onAddToCalendar,
    required this.isSavingToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topInset + 8),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Totals',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TotalCard(
                          label: 'Total Calories',
                          value: analysis.totalCalories.toStringAsFixed(0),
                          unit: 'Cal',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TotalCard(
                          label: 'Total Weight',
                          value: analysis.totalMass.toStringAsFixed(0),
                          unit: 'g',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Macronutrient Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _MacroBar(
                    label: 'Protein',
                    grams: analysis.totalProtein,
                    percentage: analysis.proteinPercentage,
                    color: AppColors.protein,
                  ),
                  const SizedBox(height: 8),
                  _MacroBar(
                    label: 'Carbs',
                    grams: analysis.totalCarbs,
                    percentage: analysis.carbsPercentage,
                    color: AppColors.carbs,
                  ),
                  const SizedBox(height: 8),
                  _MacroBar(
                    label: 'Fat',
                    grams: analysis.totalFat,
                    percentage: analysis.fatPercentage,
                    color: AppColors.fat,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: isSavingToCalendar ? null : onAddToCalendar,
                icon: isSavingToCalendar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month),
                label: Text(
                  isSavingToCalendar ? 'Adding...' : 'Add to today\'s calendar',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...analysis.foods.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final food = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  '${idx + 1}. ${food.name}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit name',
                                onPressed: () => onEditName(idx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: _EditableChip(
                              label: 'Weight',
                              value: '${food.mass.toStringAsFixed(0)} g',
                              onTap: () => onEditWeight(idx),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Calories',
                                  value:
                                      '${food.calories.toStringAsFixed(0)} Cal',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Protein',
                                  value: '${food.protein.toStringAsFixed(1)} g',
                                  color: AppColors.protein.withValues(alpha: 0.1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Carbs',
                                  value: '${food.carbs.toStringAsFixed(1)} g',
                                  color: AppColors.carbs.withValues(alpha: 0.1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Fat',
                                  value: '${food.fat.toStringAsFixed(1)} g',
                                  color: AppColors.fat.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                          if (idx < analysis.foods.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture another meal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _NutrientChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _TotalCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double grams;
  final double percentage;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.grams,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '${grams.toStringAsFixed(1)}g (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.progressTrack,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
