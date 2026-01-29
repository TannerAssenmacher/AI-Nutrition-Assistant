import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum AnalysisStage { uploading, analyzing, cleaning }

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
          .map((item) =>
              AnalyzedFoodItem.fromJson((item as Map).cast<String, dynamic>()))
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

  Future<MealAnalysis> analyzeMealImage(
    File imageFile, {
    String? userContext,
    void Function(AnalysisStage stage)? onStageChanged,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final client = http.Client();
    String? fileId;

    try {
      onStageChanged?.call(AnalysisStage.uploading);
      fileId = await _uploadImage(imageFile, client, timeout);
      final trimmedContext = userContext?.trim();
      final contextSnippet =
          (trimmedContext != null && trimmedContext.length > 500
              ? trimmedContext.substring(0, 500)
              : trimmedContext);

      final userContent = [
        {
          'type': 'input_text',
          'text': 'Analyze this meal and break down each food item.'
        },
        if (contextSnippet != null && contextSnippet.isNotEmpty)
          {
            'type': 'input_text',
            'text': 'User context (optional): $contextSnippet'
          },
        {'type': 'input_image', 'file_id': fileId},
      ];
      onStageChanged?.call(AnalysisStage.analyzing);
      final response = await client
          .post(
            Uri.parse('$_baseUrl/responses'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'model': 'gpt-5.2',
              'reasoning': {'effort': 'low'},
              'max_output_tokens': 3000,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': 'You are a nutrition expert. Analyze meal images and return ONLY valid JSON. '
                          'THINK STEP-BY-STEP (internally) BEFORE ANSWERING: identify foods → determine mass → derive per-gram macros → scale to mass → compute calories with 4/4/9 → sanity-check totals. '
                          'DO NOT return your reasoning, only the final JSON. '
                          'OUTPUT FORMAT: {"f":[{"n":"food name","m":grams,"k":kcal,"p":protein_g,"c":carbs_g,"a":fat_g}]} '
                          'RULES: '
                          '- All numeric values must be numbers, not strings. '
                          '- Use at least 1 decimal place for grams/kcal when appropriate. '
                          '- k MUST equal (p×4)+(c×4)+(a×9) exactly. '
                          '- If a scale shows weight, that is the authoritative mass; for multiple items on one scale, estimate proportional weight per item. '
                          '- Prefer slightly conservative estimates over overestimates when uncertain. '
                          'Example: 150g chicken breast → ~46.5g protein, ~0g carbs, ~4.5g fat → (46.5×4)+(0×4)+(4.5×9) = 226.5 kcal'
                    }
                  ]
                },
                {'role': 'user', 'content': userContent}
              ],
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed: ${response.statusCode} - ${response.body}');
      }

      final responseData =
          json.decode(response.body) as Map<String, dynamic>? ?? {};
      final rawJson = _extractTextResponse(responseData);
      final parsedJson = json.decode(rawJson) as Map<String, dynamic>;

      final analysis = MealAnalysis.fromJson(parsedJson);
      return _normalizeAnalysis(analysis);
    } finally {
      onStageChanged?.call(AnalysisStage.cleaning);
      if (fileId != null) {
        await _deleteFile(client, fileId, timeout);
      }
      client.close();
    }
  }

  Future<MealAnalysis> analyzeMealByText(
    String mealDescription, {
    void Function(AnalysisStage stage)? onStageChanged,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final client = http.Client();

    try {
      onStageChanged?.call(AnalysisStage.analyzing);

      final response = await client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'model': 'gpt-4o',
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are a nutrition expert. Analyze meal descriptions and return ONLY valid JSON. '
                      'THINK STEP-BY-STEP (internally) BEFORE ANSWERING: identify foods → determine mass → derive per-gram macros → scale to mass → compute calories with 4/4/9 → sanity-check totals. '
                      'DO NOT return your reasoning, only the final JSON. '
                      'OUTPUT FORMAT: {"f":[{"n":"food name","m":grams,"k":kcal,"p":protein_g,"c":carbs_g,"a":fat_g}]} '
                      'RULES: '
                      '- All numeric values must be numbers, not strings. '
                      '- Use at least 1 decimal place for grams/kcal when appropriate. '
                      '- k MUST equal (p×4)+(c×4)+(a×9) exactly. '
                      '- Prefer slightly conservative estimates over overestimates when uncertain.'
                },
                {
                  'role': 'user',
                  'content': 'Analyze this meal description and provide nutritional breakdown: $mealDescription'
                }
              ],
              'max_tokens': 2000,
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed: ${response.statusCode} - ${response.body}');
      }

      final responseData =
          json.decode(response.body) as Map<String, dynamic>? ?? {};
      
      // Extract text from chat completions response
      final choices = responseData['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No response from API');
      }
      
      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw Exception('No message in response');
      }
      
      final content = message['content'] as String?;
      if (content == null || content.isEmpty) {
        throw Exception('Empty response content');
      }

      // Parse the JSON response - try to extract JSON from the response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      final jsonStr = jsonMatch?.group(0) ?? content;
      final parsedJson = json.decode(jsonStr) as Map<String, dynamic>;

      // Convert from short format to expected format
      final foods = (parsedJson['f'] as List?)?.map((food) {
            final f = food as Map<String, dynamic>;
            return {
              'name': f['n'] ?? 'Unknown',
              'mass': (f['m'] as num?)?.toDouble() ?? 100.0,
              'calories': (f['k'] as num?)?.toDouble() ?? 0.0,
              'protein': (f['p'] as num?)?.toDouble() ?? 0.0,
              'carbs': (f['c'] as num?)?.toDouble() ?? 0.0,
              'fat': (f['a'] as num?)?.toDouble() ?? 0.0,
            };
          }).toList() ??
          [];

      if (foods.isEmpty) {
        throw Exception('No foods parsed from response');
      }

      final analysis = MealAnalysis(
        foods: foods
            .map((f) => AnalyzedFoodItem(
                  name: f['name'] as String,
                  mass: f['mass'] as double,
                  calories: f['calories'] as double,
                  protein: f['protein'] as double,
                  carbs: f['carbs'] as double,
                  fat: f['fat'] as double,
                ))
            .toList(),
      );
      return _normalizeAnalysis(analysis);
    } finally {
      onStageChanged?.call(AnalysisStage.cleaning);
      client.close();
    }
  }

  /// Ensures calories align with macros (4/4/9) and strips negative/NaN values.
  MealAnalysis _normalizeAnalysis(MealAnalysis analysis) {
    final normalizedFoods = analysis.foods.map((food) {
      final mass = _clampNonNegative(food.mass);
      final protein = _clampNonNegative(food.protein);
      final carbs = _clampNonNegative(food.carbs);
      final fat = _clampNonNegative(food.fat);

      final calories = (protein * 4) + (carbs * 4) + (fat * 9);

      return AnalyzedFoodItem(
        name: food.name,
        mass: mass,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
    }).toList();

    return MealAnalysis(foods: normalizedFoods);
  }

  double _clampNonNegative(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value < 0 ? 0.0 : value;
  }

  /// Recursively extracts text or output_text from nested response nodes.
  String? _extractTextFromNode(dynamic node) {
    if (node is Map<String, dynamic>) {
      final text = node['text'];
      if (text is String && text.isNotEmpty) {
        return text;
      }
      final outputText = node['output_text'];
      if (outputText is String && outputText.isNotEmpty) {
        return outputText;
      }

      final content = node['content'];
      if (content != null) {
        final nested = _extractTextFromNode(content);
        if (nested != null) return nested;
      }
    }

    if (node is List) {
      for (final item in node.reversed) {
        final nested = _extractTextFromNode(item);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  Future<String> _uploadImage(
    File imageFile,
    http.Client client,
    Duration timeout,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/files'));

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['purpose'] = 'vision';
    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await client.send(request).timeout(timeout);
    final responseBody =
        await response.stream.bytesToString().timeout(timeout);

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

  Future<void> _deleteFile(
    http.Client client,
    String fileId,
    Duration timeout,
  ) async {
    try {
      await client
          .delete(
            Uri.parse('$_baseUrl/files/$fileId'),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(timeout);
    } catch (_) {
      // Swallow cleanup errors.
    }
  }

  String _extractTextResponse(Map<String, dynamic> responseData) {
    // Direct field some responses include.
    final outputText = responseData['output_text'];
    if (outputText is String && outputText.isNotEmpty) {
      return outputText;
    }

    // Primary path: responses API returns "output" with nested content.
    final output = responseData['output'];
    if (output is List && output.isNotEmpty) {
      // Prefer the last entries (message often follows reasoning).
      for (final item in output.reversed) {
        final text = _extractTextFromNode(item);
        if (text != null) return text;
      }
    }

    // Fallback: sometimes "output" is a map instead of a list.
    if (output is Map<String, dynamic>) {
      final content = output['content'];
      final text = _extractTextFromNode(content);
      if (text != null) return text;
    }

    // Legacy/chat-completions style fallback: choices -> message -> content.
    final choices = responseData['choices'];
    if (choices is List && choices.isNotEmpty) {
      for (final choice in choices) {
        final message =
            choice is Map<String, dynamic> ? choice['message'] : null;
        final content =
            message is Map<String, dynamic> ? message['content'] : null;
        final text = _extractTextFromNode(content);
        if (text != null) return text;
      }
    }

    // If all parsing paths fail, surface the raw payload to aid debugging.
    throw Exception(
        'API response missing expected text output. Payload: ${json.encode(responseData)}');
  }
}
