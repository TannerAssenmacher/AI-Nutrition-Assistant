import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';

import '../services/food_search_service.dart';
import '../services/food_image_service.dart';
import '../services/meal_analysis_service.dart';
import '../db/food.dart';
import '../db/favorite_meal.dart';
import '../providers/food_providers.dart';
import '../providers/firestore_providers.dart';
import '../theme/app_colors.dart';
import 'camera_capture_screen.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/add_to_favorites_sheet.dart';

const double _kAnalysisCardRadius = 25;
const double _kAnalysisCardOpacity = 0.95;

InputDecoration _analysisInputDecoration(
  String label, {
  String? hintText,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.black),
  );

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.inputFill,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.black, width: 1.4),
    ),
  );
}

final mealProfileGoalSnapshotProvider =
    StreamProvider.family<Map<String, double>?, String>((ref, userId) {
      return FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            final data = doc.data();
            if (data == null) return null;

            final mealProfile = data['mealProfile'];
            if (mealProfile is! Map) return null;

            final macroGoalsRaw = mealProfile['macroGoals'];
            if (macroGoalsRaw is! Map) return null;

            double asDouble(dynamic value) {
              if (value is num) return value.toDouble();
              if (value is String) return double.tryParse(value) ?? 0.0;
              return 0.0;
            }

            // Read the actual calorie goal, not a default
            final calorieGoal = asDouble(mealProfile['dailyCalorieGoal']);

            return {
              'protein': asDouble(macroGoalsRaw['protein']),
              'carbs': asDouble(macroGoalsRaw['carbs']),
              'fat': asDouble(macroGoalsRaw['fat'] ?? macroGoalsRaw['fats']),
              'calories': calorieGoal > 0 ? calorieGoal : 2000.0,
            };
          });
    });

class CameraScreen extends ConsumerStatefulWidget {
  final bool isInPageView;
  final bool isActive;
  final VoidCallback? onNavigateHome;

  const CameraScreen({
    super.key,
    this.isInPageView = false,
    this.isActive = true,
    this.onNavigateHome,
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
  String? _cachedCapturedImageUrl;
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
      // If there is no result and going off camera screen
      // navigate back to the home screen instead of showing the idle state.
      if (_analysisResult == null && widget.onNavigateHome != null) {
        widget.onNavigateHome!();
      }
      return;
    }

    if (captureResult.mode == CaptureMode.barcode) {
      await _handleBarcodeLookup(captureResult.barcode);
      return;
    }

    final photo = captureResult.photo;
    if (photo == null) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No photo captured. Please try again.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _errorMessage = null;
      _analysisStage = AnalysisStage.uploading;
      _cachedCapturedImageUrl = null;
    });

    final file = File(photo.path);
    final service = MealAnalysisService();

    try {
      _cachedCapturedImageUrl = await FoodImageService.cacheCapturedImage(file);
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

      AppSnackBar.success(context, 'Meal analysis complete!');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = _buildAnalyzeMealErrorMessage(e);
      setState(() {
        _errorMessage = message;
      });

      AppSnackBar.error(context, message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Analysis failed: $e';
      });

      AppSnackBar.error(context, 'Analysis failed: $e');
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
      if (widget.isInPageView && !widget.isActive) return;
      AppSnackBar.error(context, 'Scanned barcode was empty.');
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
      if (widget.isInPageView && !widget.isActive) return;

      if (result == null) {
        AppSnackBar.error(
          context,
          'No product found for barcode $barcodeForMessages.',
        );
        return;
      }

      final wasAdded = await _showBarcodeFoodDialog(result);
      if (!mounted || !wasAdded) {
        return;
      }

      AppSnackBar.success(context, 'Added "${result.name}" to your daily log.');

      // Navigate back to home after successfully logging barcode food.
      if (widget.onNavigateHome != null) {
        widget.onNavigateHome!();
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (widget.isInPageView && !widget.isActive) return;
      final message = _buildBarcodeLookupErrorMessage(
        e,
        barcodeForMessages: barcodeForMessages,
      );
      setState(() {
        _errorMessage = message;
      });
      AppSnackBar.error(context, message);
    } on TimeoutException {
      if (!mounted) return;
      if (widget.isInPageView && !widget.isActive) return;
      final message =
          'Barcode lookup timed out. Check your connection and try again.';
      setState(() {
        _errorMessage = message;
      });
      AppSnackBar.error(context, message);
    } catch (e) {
      if (!mounted) return;
      if (widget.isInPageView && !widget.isActive) return;
      final message = 'Barcode lookup failed: $e';
      setState(() {
        _errorMessage = message;
      });
      AppSnackBar.error(context, message);
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
            final trimmedImageUrl = (result.imageUrl ?? '').trim();
            final imageUrlForLog =
                trimmedImageUrl.isNotEmpty &&
                    FoodImageService.shouldShowImageForEntry(consumedAt)
                ? trimmedImageUrl
                : null;
            final item = FoodItem(
              id: 'barcode-${DateTime.now().microsecondsSinceEpoch}',
              name: result.name,
              mass_g: grams,
              calories_g: servingOption.caloriesPerGram,
              protein_g: servingOption.proteinPerGram,
              carbs_g: servingOption.carbsPerGram,
              fat: servingOption.fatPerGram,
              mealType: mealType,
              imageUrl: imageUrlForLog,
              consumedAt: consumedAt,
            );

            // Capture food count BEFORE adding (for animation baseline)
            final beforeCount = ref.read(foodLogProvider).length;
            ref.read(mealAnalysisBeforeSnapshotProvider.notifier).state =
                beforeCount;
            ref.read(mealAnalysisAddedItemForAnimationProvider.notifier).state =
                item;

            debugPrint(
              '[MacroAnim][MealAnalysis] barcode add-log: captured before-count=$beforeCount, emitting signal for ${result.name}',
            );
            ref.read(mealAnalysisLogAnimationSignalProvider.notifier).state++;
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
    if (e.code == 'permission-denied') {
      final message = (e.message ?? '').toLowerCase();
      if (message.contains('scope') && message.contains('barcode')) {
        return 'FatSecret barcode scope is missing on this API key. Ask FatSecret to enable the barcode scope for your key.';
      }
      if (message.contains('invalid ip')) {
        return 'FatSecret rejected this request IP. Confirm the static egress IP is allowlisted in FatSecret.';
      }
      return 'Permission denied during barcode lookup. Please verify FatSecret API permissions.';
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
      AppSnackBar.error(context, 'No analysis to add. Capture a meal first.');
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
        AppSnackBar.error(
          context,
          'Please sign in to save meals to your calendar.',
        );
        return;
      }

      final firestoreLog = container.read(
        firestoreFoodLogProvider(userId).notifier,
      );
      final cachedImageUrl = (_cachedCapturedImageUrl ?? '').trim();
      final imageUrlForLog =
          cachedImageUrl.isNotEmpty &&
              FoodImageService.shouldShowImageForEntry(now)
          ? cachedImageUrl
          : null;

      // Filter out items with no mass.
      final validFoods = analysis.foods.where((f) => f.mass > 0).toList();
      if (validFoods.isEmpty) {
        if (mounted) {
          AppSnackBar.error(context, 'No items added (missing weights).');
        }
        return;
      }

      // Combine all analyzed items into one meal entry.
      final totalMass = validFoods.fold<double>(0, (s, f) => s + f.mass);
      final totalCalories = validFoods.fold<double>(
        0,
        (s, f) => s + f.calories,
      );
      final totalProtein = validFoods.fold<double>(0, (s, f) => s + f.protein);
      final totalCarbs = validFoods.fold<double>(0, (s, f) => s + f.carbs);
      final totalFat = validFoods.fold<double>(0, (s, f) => s + f.fat);

      // Build ingredient list for display in the daily log.
      final ingredientsList = validFoods
          .map(
            (f) => <String, dynamic>{
              'name': f.name,
              'mass_g': f.mass,
              'calories': f.calories,
              'protein': f.protein,
              'carbs': f.carbs,
              'fat': f.fat,
            },
          )
          .toList();

      final mealName = analysis.displayTitle;

      final item = FoodItem(
        id: '${now.microsecondsSinceEpoch}-0',
        name: mealName,
        mass_g: totalMass,
        calories_g: totalCalories / totalMass,
        protein_g: totalProtein / totalMass,
        carbs_g: totalCarbs / totalMass,
        fat: totalFat / totalMass,
        mealType: 'meal',
        imageUrl: imageUrlForLog,
        consumedAt: now,
        ingredients: validFoods.length > 1 ? ingredientsList : null,
      );
      // Capture food count BEFORE adding (for animation baseline)
      final beforeCount = container.read(foodLogProvider).length;
      container.read(mealAnalysisBeforeSnapshotProvider.notifier).state =
          beforeCount;
      container.read(mealAnalysisAddedItemForAnimationProvider.notifier).state =
          item;

      debugPrint(
        '[MacroAnim][MealAnalysis] calendar add-log: captured before-count=$beforeCount, emitting signal for $mealName',
      );
      container.read(mealAnalysisLogAnimationSignalProvider.notifier).state++;
      notifier.addFoodItem(item);
      await firestoreLog.addFood(userId, item);

      if (!mounted) return;

      AppSnackBar.success(context, 'Added "$mealName" to today.');

      // Navigate back to home after successfully adding to calendar.
      if (widget.onNavigateHome != null) {
        debugPrint(
          '[MacroAnim][MealAnalysis] invoking onNavigateHome callback',
        );
        widget.onNavigateHome!();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addMealToFavorites() async {
    final analysis = _analysisResult;
    if (analysis == null || analysis.foods.isEmpty) {
      AppSnackBar.error(context, 'No analysis to add. Capture a meal first.');
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      AppSnackBar.error(context, 'Please sign in to save favorites.');
      return;
    }

    final trimmedImageUrl = (_cachedCapturedImageUrl ?? '').trim();
    final imageUrlForFavorites = trimmedImageUrl.isNotEmpty
        ? trimmedImageUrl
        : null;

    final items = <FavoriteMealItem>[];
    for (int index = 0; index < analysis.foods.length; index++) {
      final food = analysis.foods[index];
      if (food.mass <= 0) continue;

      final normalizedName = food.name.toLowerCase().trim().replaceAll(
        RegExp(r'\s+'),
        '_',
      );

      items.add(
        FavoriteMealItem(
          name: food.name,
          grams: food.mass,
          caloriesPerGram: food.calories / food.mass,
          proteinPerGram: food.protein / food.mass,
          carbsPerGram: food.carbs / food.mass,
          fatPerGram: food.fat / food.mass,
          imageUrl: imageUrlForFavorites,
          sourceId:
              'analysis_${DateTime.now().millisecondsSinceEpoch}_${index}_$normalizedName',
          servingLabel: '${food.mass.toStringAsFixed(0)} g',
        ),
      );
    }

    if (items.isEmpty) {
      AppSnackBar.error(context, 'No valid meal items to save to favorites.');
      return;
    }

    final totalMass = analysis.totalMass > 0 ? analysis.totalMass : 100.0;
    final syntheticResult = FoodSearchResult(
      id: 'meal_analysis_bundle_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Analyzed meal',
      caloriesPerGram: analysis.totalCalories / totalMass,
      proteinPerGram: analysis.totalProtein / totalMass,
      carbsPerGram: analysis.totalCarbs / totalMass,
      fatPerGram: analysis.totalFat / totalMass,
      servingGrams: totalMass,
      source: 'fatsecret',
      imageUrl: imageUrlForFavorites,
    );

    final addedMealName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return AddToFavoritesSheet(
          result: syntheticResult,
          userId: userId,
          initialItems: items,
        );
      },
    );

    if (!mounted || addedMealName == null) return;
    AppSnackBar.success(context, 'Saved to favorites: $addedMealName.');
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
      AppSnackBar.error(context, 'Weight must be greater than 0.');
      return;
    }

    final updatedFoods = List<AnalyzedFoodItem>.from(current.foods);
    final item = updatedFoods[index];
    if (item.mass <= 0) {
      AppSnackBar.error(
        context,
        'Original weight missing; cannot adjust macros.',
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
        backgroundColor: AppColors.surface.withValues(
          alpha: _kAnalysisCardOpacity,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kAnalysisCardRadius),
        ),
        title: const Text('Edit item name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: _analysisInputDecoration('Name'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.surface,
            ),
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
        backgroundColor: AppColors.surface.withValues(
          alpha: _kAnalysisCardOpacity,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kAnalysisCardRadius),
        ),
        title: const Text('Edit weight (grams)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textInputAction: TextInputAction.done,
          decoration: _analysisInputDecoration(
            'Weight in grams',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.surface,
            ),
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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      Map<String, double>? goalSnapshot;
      if (userId != null) {
        final goalsAsync = ref.watch(mealProfileGoalSnapshotProvider(userId));
        // Use valueOrNull but prefer waiting for data when available
        goalSnapshot = goalsAsync.valueOrNull;

        // If data is loading and we don't have a value yet, show loading indicator
        if (goalsAsync.isLoading && goalSnapshot == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading your nutrition goals...'),
              ],
            ),
          );
        }
      }

      return SizedBox.expand(
        child: MealAnalysisResultWidget(
          key: const ValueKey('analysis_result'),
          analysis: _analysisResult!,
          goalSnapshot: goalSnapshot,
          onEditName: _promptEditName,
          onEditWeight: _promptEditWeight,
          onAddToFavorites: _addMealToFavorites,
          onAddToCalendar: _addMealToCalendar,
          isSavingToCalendar: _isSaving,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _buildCameraContent(context);

    if (widget.isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(top: 2),
            child: const FatSecretAttribution(),
          ),
          NavBar(
            currentIndex: navIndexCamera,
            onTap: (index) => handleNavTap(context, index),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraContent(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
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
            child: Text(message, style: TextStyle(color: AppColors.error)),
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final rawServings = widget.result.servingOptions.isEmpty
        ? [widget.result.defaultServingOption]
        : widget.result.servingOptions;
    _availableServings = _normalizeServingOptions(rawServings);
    _selectedServing = _availableServings.firstWhere(
      (option) => option.isDefault,
      orElse: () => _availableServings.first,
    );
    _gramsController = TextEditingController(
      text: _formatCompactNumber(_selectedServing.grams, maxDecimals: 0),
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

  List<FoodServingOption> _normalizeServingOptions(
    List<FoodServingOption> options,
  ) {
    final prioritized = [
      ...options.where((option) => option.isDefault),
      ...options.where((option) => !option.isDefault),
    ];
    final seen = <String>{};
    final normalized = <FoodServingOption>[];
    for (final option in prioritized) {
      final key =
          '${option.description.trim().toLowerCase()}|${option.grams.toStringAsFixed(2)}';
      if (!seen.add(key)) continue;
      normalized.add(option);
    }
    return normalized.isEmpty ? options : normalized;
  }

  String _servingLabel(FoodServingOption option) {
    final gramsText = '${_formatCompactNumber(option.grams, maxDecimals: 0)} g';
    final description = option.description.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (description.isEmpty) {
      return gramsText;
    }

    final normalized = description.toLowerCase();
    if (normalized == 'default serving') {
      return gramsText;
    }
    final duplicatePattern = RegExp(
      r'^([\d.]+\s*(?:g|gram|grams|ml|oz|ounce|ounces))\s*\(\s*\1\s*\)$',
      caseSensitive: false,
    );
    final duplicateMatch = duplicatePattern.firstMatch(description);
    if (duplicateMatch != null) {
      return duplicateMatch.group(1)!;
    }
    if (RegExp(
      r'^\s*[\d.]+\s*(g|gram|grams|ml|oz|ounce|ounces)\s*$',
    ).hasMatch(normalized)) {
      return description;
    }
    return '$description ($gramsText)';
  }

  Widget _buildImagePreview() {
    final imageUrl = widget.result.imageUrl?.trim() ?? '';
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget errorPlaceholder() {
      return Container(
        height: 140,
        width: double.infinity,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: AppColors.textHint),
            const SizedBox(height: 4),
            Text(
              'Image unavailable',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 140,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => errorPlaceholder(),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _handleAdd() async {
    final grams = double.tryParse(_gramsController.text.trim());
    if (grams == null || grams <= 0) {
      AppSnackBar.error(context, 'Please enter a valid grams amount.');
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
      AppSnackBar.error(context, _errorMessage(error));
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
    final typedGrams = double.tryParse(_gramsController.text.trim());
    final gramsPreview = (typedGrams != null && typedGrams > 0)
        ? typedGrams
        : _selectedServing.grams;
    final previewCalories = _selectedServing.caloriesPerGram * gramsPreview;
    final previewProtein = _selectedServing.proteinPerGram * gramsPreview;
    final previewCarbs = _selectedServing.carbsPerGram * gramsPreview;
    final previewFat = _selectedServing.fatPerGram * gramsPreview;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Center(
          child: AlertDialog(
            backgroundColor: AppColors.surface.withValues(
              alpha: _kAnalysisCardOpacity,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kAnalysisCardRadius),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePreview(),
                  if ((widget.result.imageUrl ?? '').trim().isNotEmpty)
                    const SizedBox(height: 12),
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
                    decoration: _analysisInputDecoration('Meal type'),
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
                  if (_availableServings.length > 1) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<FoodServingOption>(
                      initialValue: _selectedServing,
                      isExpanded: true,
                      decoration: _analysisInputDecoration('Serving size'),
                      selectedItemBuilder: (context) => _availableServings
                          .map(
                            (option) => Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                _servingLabel(option),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      items: _availableServings
                          .map(
                            (option) => DropdownMenuItem<FoodServingOption>(
                              value: option,
                              child: Text(
                                _servingLabel(option),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
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
                                _gramsController.text = _formatCompactNumber(
                                  value.grams,
                                  maxDecimals: 0,
                                );
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 10),
                  TextField(
                    controller: _gramsController,
                    focusNode: _gramsFocusNode,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Weight (g)',
                      suffixIcon: IconButton(
                        tooltip: 'Done',
                        icon: const Icon(Icons.check),
                        onPressed: _dismissKeyboard,
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.black,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                    onSubmitted: (_) => _dismissKeyboard(),
                    onTapOutside: (_) => _dismissKeyboard(),
                  ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.surface,
                ),
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

// Widget to display the meal analysis results.
class MealAnalysisResultWidget extends StatelessWidget {
  final MealAnalysis analysis;
  final Map<String, double>? goalSnapshot;
  final void Function(int) onEditName;
  final void Function(int) onEditWeight;
  final VoidCallback onAddToFavorites;
  final Future<void> Function() onAddToCalendar;
  final bool isSavingToCalendar;

  const MealAnalysisResultWidget({
    super.key,
    required this.analysis,
    this.goalSnapshot,
    required this.onEditName,
    required this.onEditWeight,
    required this.onAddToFavorites,
    required this.onAddToCalendar,
    required this.isSavingToCalendar,
  });

  /// Converts the user's daily macro goals to grams.
  Map<String, double>? _dailyGoalsInGrams() {
    final goals = goalSnapshot;
    if (goals == null || goals.isEmpty) {
      return null;
    }

    final calorieGoal = goals['calories'] ?? 0.0;
    if (calorieGoal <= 0) {
      return null; // Can't calculate without valid calorie goal
    }

    final proteinRaw = goals['protein'] ?? 0.0;
    final carbsRaw = goals['carbs'] ?? 0.0;
    final fatRaw = goals['fat'] ?? goals['fats'] ?? 0.0;

    final values = [proteinRaw, carbsRaw, fatRaw].where((v) => v > 0).toList();
    final looksLikePercentages =
        values.isNotEmpty && values.every((v) => v <= 100.0);

    // If stored as percentages, convert to grams based on calorie goal
    if (looksLikePercentages) {
      return {
        'protein': (proteinRaw / 100) * calorieGoal / 4,
        'carbs': (carbsRaw / 100) * calorieGoal / 4,
        'fat': (fatRaw / 100) * calorieGoal / 9,
      };
    }

    // If already stored as grams, use directly
    if (proteinRaw > 0 || carbsRaw > 0 || fatRaw > 0) {
      return {'protein': proteinRaw, 'carbs': carbsRaw, 'fat': fatRaw};
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate what percentage of the user's daily goals this meal represents
    final dailyGoals = _dailyGoalsInGrams();

    // Always calculate percentage of daily goals if goals are available
    double proteinPercent = analysis.proteinPercentage;
    double carbsPercent = analysis.carbsPercentage;
    double fatPercent = analysis.fatPercentage;

    if (dailyGoals != null) {
      if (dailyGoals['protein'] != null && dailyGoals['protein']! > 0) {
        proteinPercent = (analysis.totalProtein / dailyGoals['protein']!) * 100;
      }
      if (dailyGoals['carbs'] != null && dailyGoals['carbs']! > 0) {
        carbsPercent = (analysis.totalCarbs / dailyGoals['carbs']!) * 100;
      }
      if (dailyGoals['fat'] != null && dailyGoals['fat']! > 0) {
        fatPercent = (analysis.totalFat / dailyGoals['fat']!) * 100;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // ── Main Analysis Card ──
        Card(
          margin: EdgeInsets.zero,
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Food name + favorite ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        analysis.displayTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add to favorites',
                      onPressed: onAddToFavorites,
                      icon: const Icon(Icons.favorite_border),
                      color: AppColors.textHint,
                      iconSize: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Serving weight pill ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Serving',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${analysis.totalMass.toStringAsFixed(0)} g',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Macro circles ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MacroCircle(
                      label: 'Calories',
                      value: analysis.totalCalories.toStringAsFixed(0),
                      unit: 'Cal',
                      backgroundColor:
                          AppColors.brand.withValues(alpha: 0.12),
                      textColor: AppColors.brand,
                    ),
                    _MacroCircle(
                      label: 'Protein',
                      value:
                          _formatCompactNumber(analysis.totalProtein),
                      unit: 'g',
                      backgroundColor:
                          AppColors.protein.withValues(alpha: 0.12),
                      textColor: AppColors.protein,
                    ),
                    _MacroCircle(
                      label: 'Carbs',
                      value:
                          _formatCompactNumber(analysis.totalCarbs),
                      unit: 'g',
                      backgroundColor:
                          AppColors.carbs.withValues(alpha: 0.15),
                      textColor: AppColors.carbs,
                    ),
                    _MacroCircle(
                      label: 'Fat',
                      value: _formatCompactNumber(analysis.totalFat),
                      unit: 'g',
                      backgroundColor:
                          AppColors.fat.withValues(alpha: 0.12),
                      textColor: AppColors.fat,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Macronutrient Breakdown ──
                Text(
                  'MACRONUTRIENT BREAKDOWN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                _MacroProgressRow(
                  label: 'Protein',
                  grams: analysis.totalProtein,
                  percentage: proteinPercent,
                  color: AppColors.protein,
                ),
                const SizedBox(height: 16),
                _MacroProgressRow(
                  label: 'Carbs',
                  grams: analysis.totalCarbs,
                  percentage: carbsPercent,
                  color: AppColors.carbs,
                ),
                const SizedBox(height: 16),
                _MacroProgressRow(
                  label: 'Fat',
                  grams: analysis.totalFat,
                  percentage: fatPercent,
                  color: AppColors.fat,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Action button ──
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: isSavingToCalendar ? null : onAddToCalendar,
            icon: isSavingToCalendar
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.calendar_month, size: 20),
            label: Text(
              isSavingToCalendar ? 'Adding...' : 'Add to today\'s log',
            ),
          ),
        ),
        // ── Items card ──
        if (analysis.foods.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ITEMS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...analysis.foods.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final food = entry.value;
                    return Column(
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
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Edit name',
                              color: AppColors.textHint,
                              onPressed: () => onEditName(idx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => onEditWeight(idx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${food.mass.toStringAsFixed(0)} g',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brand,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: AppColors.brand,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _NutrientChip(
                              label: 'Cal',
                              value: food.calories.toStringAsFixed(0),
                              color:
                                  AppColors.brand.withValues(alpha: 0.12),
                              textColor: AppColors.brand,
                            ),
                            const SizedBox(width: 8),
                            _NutrientChip(
                              label: 'Protein',
                              value:
                                  '${food.protein.toStringAsFixed(1)}g',
                              color: AppColors.protein
                                  .withValues(alpha: 0.12),
                              textColor: AppColors.protein,
                            ),
                            const SizedBox(width: 8),
                            _NutrientChip(
                              label: 'Carbs',
                              value:
                                  '${food.carbs.toStringAsFixed(1)}g',
                              color:
                                  AppColors.carbs.withValues(alpha: 0.15),
                              textColor: AppColors.carbs,
                            ),
                            const SizedBox(width: 8),
                            _NutrientChip(
                              label: 'Fat',
                              value: '${food.fat.toStringAsFixed(1)}g',
                              color:
                                  AppColors.fat.withValues(alpha: 0.12),
                              textColor: AppColors.fat,
                            ),
                          ],
                        ),
                        if (idx < analysis.foods.length - 1)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.homeDivider),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  const _NutrientChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroCircle extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color backgroundColor;
  final Color textColor;

  const _MacroCircle({
    required this.label,
    required this.value,
    required this.unit,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MacroProgressRow extends StatelessWidget {
  final String label;
  final double grams;
  final double percentage;
  final Color color;

  const _MacroProgressRow({
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              '${grams.toStringAsFixed(1)}g (${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
