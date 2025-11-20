import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/meal_analysis_service.dart';
import 'camera_capture_screen.dart';

class IntegratedMealCaptureFlow extends StatefulWidget {
  const IntegratedMealCaptureFlow({super.key});

  @override
  State<IntegratedMealCaptureFlow> createState() =>
      _IntegratedMealCaptureFlowState();
}

class _IntegratedMealCaptureFlowState extends State<IntegratedMealCaptureFlow> {
  bool _isAnalyzing = false;
  MealAnalysis? _analysisResult;
  String? _errorMessage;

  Future<void> _openCamera(BuildContext context) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'OpenAI API key is not configured.';
      });
      return;
    }

    try {
      final capturedFile = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute<XFile?>(
          builder: (_) => const CameraCaptureScreen(),
        ),
      );

      if (capturedFile == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _isAnalyzing = true;
        _analysisResult = null;
        _errorMessage = null;
      });

      final file = File(capturedFile.path);
      final service = MealAnalysisService(apiKey: apiKey);

      try {
        final analysis = await service.analyzeMealImage(file);

        if (!mounted) return;

        setState(() {
          _analysisResult = analysis;
          _isAnalyzing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal analysis complete!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Analysis failed: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Ignore cleanup failures.
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Camera unavailable: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Analyzer'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isAnalyzing
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing your meal...'),
                  ],
                )
              : _analysisResult != null
                  ? MealAnalysisResultWidget(analysis: _analysisResult!)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Capture a meal to analyze',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _openCamera(context),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCamera(context),
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

/// Widget to display the meal analysis results.
class MealAnalysisResultWidget extends StatelessWidget {
  final MealAnalysis analysis;

  const MealAnalysisResultWidget({
    super.key,
    required this.analysis,
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
                  const Text(
                    'Food Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...analysis.foods.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final food = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${idx + 1}. ${food.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Weight',
                                  value: '${food.mass.toStringAsFixed(0)}g',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Calories',
                                  value: food.calories.toStringAsFixed(0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Protein',
                                  value: '${food.protein.toStringAsFixed(1)}g',
                                  color: Colors.blue.shade50,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Carbs',
                                  value: '${food.carbs.toStringAsFixed(1)}g',
                                  color: Colors.orange.shade50,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutrientChip(
                                  label: 'Fat',
                                  value: '${food.fat.toStringAsFixed(1)}g',
                                  color: Colors.green.shade50,
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
