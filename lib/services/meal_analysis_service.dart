import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
  final String? title;
  final List<AnalyzedFoodItem> foods;

  MealAnalysis({this.title, required this.foods});

  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    final foodsList = json['f'] as List<dynamic>? ?? [];
    return MealAnalysis(
      title: json['t'] as String?,
      foods: foodsList
          .map((item) =>
              AnalyzedFoodItem.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 't': title,
      'f': foods.map((food) => food.toJson()).toList(),
    };
  }

  /// Returns the meal title, or generates one from ingredient names.
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!;
    if (foods.isEmpty) return 'Meal';
    if (foods.length == 1) return foods.first.name;
    final names = foods.map((f) => f.name).toList();
    if (names.length <= 2) return names.join(' & ');
    return '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
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
  MealAnalysisService({String region = 'us-central1'}) : _region = region;

  final String _region;

  Uri _callableUri(String functionName) {
    final projectId = Firebase.app().options.projectId;
    return Uri.parse(
      'https://$_region-$projectId.cloudfunctions.net/$functionName',
    );
  }

  Future<MealAnalysis> analyzeMealImage(
    File imageFile, {
    String? userContext,
    void Function(AnalysisStage stage)? onStageChanged,
    Duration timeout = const Duration(seconds: 100),
  }) async {
    try {
      onStageChanged?.call(AnalysisStage.uploading);
      final imageBytes = await imageFile.readAsBytes().timeout(timeout);
      final imageBase64 = base64Encode(imageBytes);

      final trimmedContext = userContext?.trim();
      final contextSnippet =
          (trimmedContext != null && trimmedContext.length > 500
              ? trimmedContext.substring(0, 500)
              : trimmedContext);

      onStageChanged?.call(AnalysisStage.analyzing);
      final user = await _ensureSignedInUser();
      final idToken = await user.getIdToken(true);

      final payload = <String, dynamic>{
        'imageBase64': imageBase64,
        'mimeType': 'image/jpeg',
        if (contextSnippet != null && contextSnippet.isNotEmpty)
          'userContext': contextSnippet,
      };

      final httpResponse = await http
          .post(
            _callableUri('analyzeMealImage'),
            headers: {
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'data': payload}),
          )
          .timeout(timeout);

      if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        throw StateError(
          'Cloud Function call failed (${httpResponse.statusCode}): ${httpResponse.body}',
        );
      }

      final decoded = jsonDecode(httpResponse.body);
      if (decoded is! Map) {
        throw StateError(
          'Unexpected Cloud Function response type: ${decoded.runtimeType}',
        );
      }

      final errorRaw = decoded['error'];
      if (errorRaw is Map) {
        final message = errorRaw['message'] ?? 'Unknown error';
        throw StateError('Cloud Function error: $message');
      }

      final resultRaw = decoded['result'];
      if (resultRaw is! Map) {
        throw StateError(
          'Missing or invalid "result" in Cloud Function response.',
        );
      }

      final data = Map<String, dynamic>.from(resultRaw);
      final analysisRaw = data['analysis'];
      if (analysisRaw is! Map) {
        throw StateError(
          'Missing or invalid "analysis" in Cloud Function response.',
        );
      }

      final analysis =
          MealAnalysis.fromJson(Map<String, dynamic>.from(analysisRaw));
      return _normalizeAnalysis(analysis);
    } finally {
      onStageChanged?.call(AnalysisStage.cleaning);
    }
  }

  Future<User> _ensureSignedInUser() async {
    final auth = FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user != null) {
      return user;
    }

    try {
      final credential = await auth.signInAnonymously();
      user = credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'admin-restricted-operation') {
        throw StateError('Please sign in. Anonymous auth is disabled.');
      }
      rethrow;
    }

    if (user == null) {
      throw StateError('Could not authenticate user');
    }
    return user;
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

    return MealAnalysis(title: analysis.title, foods: normalizedFoods);
  }

  double _clampNonNegative(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value < 0 ? 0.0 : value;
  }
}
