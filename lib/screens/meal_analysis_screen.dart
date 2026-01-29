import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrition_assistant/config/env.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';

import '../services/meal_analysis_service.dart';
import '../db/food.dart';
import '../providers/food_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import 'camera_capture_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final bool isInPageView;

  const CameraScreen({super.key, this.isInPageView = false});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  bool _isAnalyzing = false;
  bool _isSaving = false;
  MealAnalysis? _analysisResult;
  String? _errorMessage;
  AnalysisStage? _analysisStage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if meal title was passed as argument
      final mealTitle = ModalRoute.of(context)?.settings.arguments as String?;
      if (mealTitle != null && mealTitle.isNotEmpty) {
        _analyzeByText(mealTitle);
      } else {
        _captureAndAnalyze();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset analysis when returning to the app (e.g., from another screen)
    if (state == AppLifecycleState.resumed) {
      _resetAnalysis();
    }
  }

  void _resetAnalysis() {
    setState(() {
      _analysisResult = null;
      _isAnalyzing = false;
      _errorMessage = null;
      _analysisStage = null;
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_isAnalyzing) return;

    final apiKey = Env.openAiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'OpenAI API key is not configured.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'OpenAI API key is missing. Pass OPENAI_API_KEY via --dart-define.'),
        ),
      );
      return;
    }

    final captureResult = await Navigator.of(context).push<MealCaptureResult?>(
      MaterialPageRoute<MealCaptureResult?>(
        builder: (_) => const CameraCaptureScreen(),
        settings: const RouteSettings(name: '/camera/capture'),
      ),
    );

    if (captureResult == null || !mounted) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _errorMessage = null;
      _analysisStage = AnalysisStage.uploading;
    });

    final file = File(captureResult.photo.path);
    final service = MealAnalysisService(apiKey: apiKey);

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal analysis complete!'),
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
          backgroundColor: Colors.red[700],
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

  Future<void> _analyzeByText(String mealTitle) async {
    if (_isAnalyzing) return;

    final apiKey = Env.openAiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'OpenAI API key is not configured.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'OpenAI API key is missing. Pass OPENAI_API_KEY via --dart-define.'),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _errorMessage = null;
      _analysisStage = AnalysisStage.uploading;
    });

    final service = MealAnalysisService(apiKey: apiKey);

    try {
      final analysis = await service.analyzeMealByText(
        mealTitle,
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal analysis complete!'),
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
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStage = null;
        });
      }
    }
  }

  Future<void> _addMealToCalendar() async {
    final analysis = _analysisResult;
    if (analysis == null || analysis.foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No analysis to add. Capture a meal first.')),
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
      final authUser = container.read(authServiceProvider);

      final userId = authUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please sign in to save meals to your calendar.')),
        );
        return;
      }

      final firestoreLog =
          container.read(firestoreFoodLogProvider(userId).notifier);
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
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
              decimal: true, signed: false),
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
    if (_isAnalyzing) {
      return _AnalyzingState(stage: _analysisStage);
    }

    if (_analysisResult != null) {
      return MealAnalysisResultWidget(
        key: const ValueKey('analysis_result'),
        analysis: _analysisResult!,
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

    final fab = FloatingActionButton.extended(
      onPressed: _isAnalyzing ? null : _captureAndAnalyze,
      backgroundColor: Colors.green[700],
      icon: _isAnalyzing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.camera_alt),
      label: Text(_isAnalyzing ? 'Analyzing...' : 'Capture meal'),
    );

    if (widget.isInPageView == true) {
      return Stack(
        children: [
          bodyContent,
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(child: fab),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE2),
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexCamera,
        onTap: (index) => handleNavTap(context, index),
      ),
      floatingActionButton: fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingState extends StatelessWidget {
  final AnalysisStage? stage;

  const _AnalyzingState({this.stage});

  String get _label {
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
          Text(
            _label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${((progress ?? 0) * 3).clamp(1, 3).round()} of 3',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
              ),
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
          const Icon(Icons.camera_alt, size: 60, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            'No photo captured yet',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture meal'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _AddMealByText(),
        ],
      ),
    );
  }
}

class _AddMealByText extends StatefulWidget {
  const _AddMealByText();

  @override
  State<_AddMealByText> createState() => _AddMealByTextState();
}

class _AddMealByTextState extends State<_AddMealByText> {
  final TextEditingController _mealController = TextEditingController();

  @override
  void dispose() {
    _mealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Or describe your meal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 250,
          child: TextField(
            controller: _mealController,
            decoration: InputDecoration(
              hintText: 'e.g., Chicken & Rice',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            if (_mealController.text.trim().isNotEmpty) {
              // Navigate back with the meal title as argument
              Navigator.pop(context, _mealController.text.trim());
              // The parent screen will catch this and restart analysis
            }
          },
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Analyze'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5F9735),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
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
                const Icon(Icons.edit, size: 14, color: Colors.black54),
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
  final void Function(int) onEditName;
  final void Function(int) onEditWeight;
  final Future<void> Function() onAddToCalendar;
  final bool isSavingToCalendar;

  const MealAnalysisResultWidget({
    super.key,
    required this.analysis,
    required this.onEditName,
    required this.onEditWeight,
    required this.onAddToCalendar,
    required this.isSavingToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _EditableChip(
                                label: 'Weight',
                                value: '${food.mass.toStringAsFixed(0)} g',
                                onTap: () => onEditWeight(idx),
                              ),
                              _NutrientChip(
                                label: 'Calories',
                                value:
                                    '${food.calories.toStringAsFixed(0)} kcal',
                              ),
                              _NutrientChip(
                                label: 'Protein',
                                value: '${food.protein.toStringAsFixed(1)} g',
                                color: Colors.blue.shade50,
                              ),
                              _NutrientChip(
                                label: 'Carbs',
                                value: '${food.carbs.toStringAsFixed(1)} g',
                                color: Colors.orange.shade50,
                              ),
                              _NutrientChip(
                                label: 'Fat',
                                value: '${food.fat.toStringAsFixed(1)} g',
                                color: Colors.green.shade50,
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
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Totals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TotalCard(
                          label: 'Total Calories',
                          value: analysis.totalCalories.toStringAsFixed(0),
                          unit: 'kcal',
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MacroBar(
                    label: 'Protein',
                    grams: analysis.totalProtein,
                    percentage: analysis.proteinPercentage,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _MacroBar(
                    label: 'Carbs',
                    grams: analysis.totalCarbs,
                    percentage: analysis.carbsPercentage,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _MacroBar(
                    label: 'Fat',
                    grams: analysis.totalFat,
                    percentage: analysis.fatPercentage,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: isSavingToCalendar ? null : onAddToCalendar,
                      icon: isSavingToCalendar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_month),
                      label: Text(
                        isSavingToCalendar
                            ? 'Adding...'
                            : 'Add to today\'s calendar',
                      ),
                    ),
                  ),
                ],
              ),
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

  const _NutrientChip({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
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
                    color: Colors.grey.shade600,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${grams.toStringAsFixed(1)}g (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
