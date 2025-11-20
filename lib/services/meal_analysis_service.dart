import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Simple model representing a single analyzed food item.
class AnalyzedFoodItem {
  final String name;
  final double mass;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  AnalyzedFoodItem({
    required this.name,
    required this.mass,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory AnalyzedFoodItem.fromJson(Map<String, dynamic> json) {
    return AnalyzedFoodItem(
      name: json['n'] as String? ?? 'Unknown Food',
      mass: _toDouble(json['m']),
      calories: _toDouble(json['k']),
      protein: _toDouble(json['p']),
      carbs: _toDouble(json['c']),
      fat: _toDouble(json['a']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': name,
      'm': mass,
      'k': calories,
      'p': protein,
      'c': carbs,
      'a': fat,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Collection of analyzed foods with convenience totals.
class MealAnalysis {
  final List<AnalyzedFoodItem> foods;

  MealAnalysis({required this.foods});

  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    final foodsList = json['f'] as List<dynamic>? ?? [];
    return MealAnalysis(
      foods: foodsList
          .map((item) => AnalyzedFoodItem.fromJson(
              (item as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'f': foods.map((food) => food.toJson()).toList(),
    };
  }

  double get totalMass =>
      foods.fold<double>(0.0, (sum, food) => sum + food.mass);
  double get totalCalories =>
      foods.fold<double>(0.0, (sum, food) => sum + food.calories);
  double get totalProtein =>
      foods.fold<double>(0.0, (sum, food) => sum + food.protein);
  double get totalCarbs =>
      foods.fold<double>(0.0, (sum, food) => sum + food.carbs);
  double get totalFat => foods.fold<double>(0.0, (sum, food) => sum + food.fat);

  double get proteinPercentage {
    if (totalCalories == 0) return 0.0;
    return (totalProtein * 4 / totalCalories) * 100;
  }

  double get carbsPercentage {
    if (totalCalories == 0) return 0.0;
    return (totalCarbs * 4 / totalCalories) * 100;
  }

  double get fatPercentage {
    if (totalCalories == 0) return 0.0;
    return (totalFat * 9 / totalCalories) * 100;
  }
}

/// Service for uploading a meal photo and getting a nutrition estimate via OpenAI.
class MealAnalysisService {
  MealAnalysisService({required this.apiKey});

  final String apiKey;
  static const String _baseUrl = 'https://api.openai.com/v1';

  Future<MealAnalysis> analyzeMealImage(File imageFile) async {
    String? fileId;

    try {
      fileId = await _uploadImage(imageFile);
      final response = await http.post(
        Uri.parse('$_baseUrl/responses'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-4.1-mini',
          'input': [
            {
              'role': 'system',
              'content': [
                {
                  'type': 'input_text',
                  'text':
                      'You are a nutrition expert. Analyze meal images and return ONLY valid JSON. '
                          'Use this exact structure: '
                          '{"f":[{"n":"food name","m":grams,"k":kcal,"p":protein_g,"c":carbs_g,"a":fat_g}]} '
                          'where n=food name, m=mass grams, k=kilocalories, p=protein grams, c=carb grams, a=fat grams. '
                          'All numeric values (m,k,p,c,a) must be numbers, never strings. Provide your best estimate for each visible food item.'
                }
              ]
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_text',
                  'text': 'Analyze this meal and break down each food item.'
                },
                {'type': 'input_image', 'file_id': fileId},
              ]
            }
          ],
          'temperature': 0.1,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed: ${response.statusCode} - ${response.body}');
      }

      final responseData =
          json.decode(response.body) as Map<String, dynamic>? ?? {};
      final rawJson = _extractTextResponse(responseData);
      final parsedJson = json.decode(rawJson) as Map<String, dynamic>;

      return MealAnalysis.fromJson(parsedJson);
    } finally {
      if (fileId != null) {
        await _deleteFile(fileId);
      }
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/files'));

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['purpose'] = 'vision';
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to upload image: ${response.statusCode} - $responseBody');
    }

    final data = json.decode(responseBody) as Map<String, dynamic>? ?? {};
    final fileId = data['id'] as String?;
    if (fileId == null) {
      throw Exception('Image upload response missing file id.');
    }

    return fileId;
  }

  Future<void> _deleteFile(String fileId) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/files/$fileId'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
    } catch (_) {
      // Swallow cleanup errors.
    }
  }

  String _extractTextResponse(Map<String, dynamic> responseData) {
    final output = responseData['output'];
    if (output is List && output.isNotEmpty) {
      final firstOutput = output.first;
      final content = firstOutput is Map<String, dynamic>
          ? firstOutput['content']
          : null;

      if (content is List) {
        for (final item in content) {
          if (item is Map<String, dynamic>) {
            final text = item['text'];
            if (text is String && text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    }
    throw Exception('API response missing expected text output.');
  }
}
