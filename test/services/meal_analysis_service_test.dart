/// Tests for MealAnalysisService models (AnalyzedFoodItem, MealAnalysis)
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/services/meal_analysis_service.dart';

void main() {
  // ============================================================================
  // ANALYZED FOOD ITEM TESTS
  // ============================================================================
  group('AnalyzedFoodItem', () {
    test('should create instance with all fields', () {
      final item = AnalyzedFoodItem(
        name: 'Apple',
        mass: 150,
        calories: 78,
        protein: 0.5,
        carbs: 21,
        fat: 0.3,
      );

      expect(item.name, 'Apple');
      expect(item.mass, 150);
      expect(item.calories, 78);
      expect(item.protein, 0.5);
      expect(item.carbs, 21);
      expect(item.fat, 0.3);
    });

    test('fromJson should parse JSON correctly', () {
      final json = {
        'n': 'Banana',
        'm': 118,
        'k': 105,
        'p': 1.3,
        'c': 27,
        'a': 0.4,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.name, 'Banana');
      expect(item.mass, 118);
      expect(item.calories, 105);
      expect(item.protein, 1.3);
      expect(item.carbs, 27);
      expect(item.fat, 0.4);
    });

    test('fromJson should handle missing name with default', () {
      final json = {
        'm': 100,
        'k': 50,
        'p': 1,
        'c': 10,
        'a': 0.5,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.name, 'Unknown Food');
    });

    test('fromJson should handle integer values', () {
      final json = {
        'n': 'Rice',
        'm': 200,
        'k': 260,
        'p': 5,
        'c': 57,
        'a': 1,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.mass, 200.0);
      expect(item.calories, 260.0);
      expect(item.protein, 5.0);
    });

    test('fromJson should handle string numeric values', () {
      final json = {
        'n': 'Bread',
        'm': '50',
        'k': '130',
        'p': '4',
        'c': '24',
        'a': '1.5',
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.mass, 50.0);
      expect(item.calories, 130.0);
      expect(item.protein, 4.0);
      expect(item.carbs, 24.0);
      expect(item.fat, 1.5);
    });

    test('fromJson should handle null/invalid values as 0', () {
      final json = {
        'n': 'Unknown',
        'm': null,
        'k': 'invalid',
        'p': null,
        'c': null,
        'a': null,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.mass, 0.0);
      expect(item.calories, 0.0);
      expect(item.protein, 0.0);
      expect(item.carbs, 0.0);
      expect(item.fat, 0.0);
    });

    test('toJson should produce correct JSON', () {
      final item = AnalyzedFoodItem(
        name: 'Chicken',
        mass: 100,
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
      );

      final json = item.toJson();

      expect(json['n'], 'Chicken');
      expect(json['m'], 100);
      expect(json['k'], 165);
      expect(json['p'], 31);
      expect(json['c'], 0);
      expect(json['a'], 3.6);
    });

    test('JSON round-trip should preserve data', () {
      final original = AnalyzedFoodItem(
        name: 'Salmon',
        mass: 150,
        calories: 312,
        protein: 37.5,
        carbs: 0,
        fat: 19.5,
      );

      final json = original.toJson();
      final restored = AnalyzedFoodItem.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.mass, original.mass);
      expect(restored.calories, original.calories);
      expect(restored.protein, original.protein);
      expect(restored.carbs, original.carbs);
      expect(restored.fat, original.fat);
    });
  });

  // ============================================================================
  // MEAL ANALYSIS TESTS
  // ============================================================================
  group('MealAnalysis', () {
    test('should create instance with foods list', () {
      final analysis = MealAnalysis(
        foods: [
          AnalyzedFoodItem(
            name: 'Apple',
            mass: 150,
            calories: 78,
            protein: 0.5,
            carbs: 21,
            fat: 0.3,
          ),
        ],
      );

      expect(analysis.foods.length, 1);
      expect(analysis.foods.first.name, 'Apple');
    });

    test('fromJson should parse foods array', () {
      final json = {
        'f': [
          {'n': 'Apple', 'm': 150, 'k': 78, 'p': 0.5, 'c': 21, 'a': 0.3},
          {'n': 'Banana', 'm': 118, 'k': 105, 'p': 1.3, 'c': 27, 'a': 0.4},
        ]
      };

      final analysis = MealAnalysis.fromJson(json);

      expect(analysis.foods.length, 2);
      expect(analysis.foods[0].name, 'Apple');
      expect(analysis.foods[1].name, 'Banana');
    });

    test('fromJson should handle missing foods array', () {
      final json = <String, dynamic>{};

      final analysis = MealAnalysis.fromJson(json);

      expect(analysis.foods, isEmpty);
    });

    test('fromJson should handle null foods array', () {
      final json = {'f': null};

      final analysis = MealAnalysis.fromJson(json);

      expect(analysis.foods, isEmpty);
    });

    test('toJson should produce correct structure', () {
      final analysis = MealAnalysis(
        foods: [
          AnalyzedFoodItem(
            name: 'Chicken',
            mass: 100,
            calories: 165,
            protein: 31,
            carbs: 0,
            fat: 3.6,
          ),
        ],
      );

      final json = analysis.toJson();

      expect(json['f'], isA<List>());
      expect((json['f'] as List).length, 1);
    });

    group('Totals', () {
      late MealAnalysis analysis;

      setUp(() {
        analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Apple',
              mass: 150,
              calories: 78,
              protein: 0.5,
              carbs: 21,
              fat: 0.3,
            ),
            AnalyzedFoodItem(
              name: 'Chicken Breast',
              mass: 100,
              calories: 165,
              protein: 31,
              carbs: 0,
              fat: 3.6,
            ),
          ],
        );
      });

      test('totalMass should sum all food masses', () {
        expect(analysis.totalMass, 250); // 150 + 100
      });

      test('totalCalories should sum all calories', () {
        expect(analysis.totalCalories, 243); // 78 + 165
      });

      test('totalProtein should sum all protein', () {
        expect(analysis.totalProtein, 31.5); // 0.5 + 31
      });

      test('totalCarbs should sum all carbs', () {
        expect(analysis.totalCarbs, 21); // 21 + 0
      });

      test('totalFat should sum all fat', () {
        expect(analysis.totalFat, closeTo(3.9, 0.01)); // 0.3 + 3.6
      });
    });

    group('Percentages', () {
      test('should calculate protein percentage correctly', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Test',
              mass: 100,
              calories: 400,
              protein: 25, // 25g * 4 = 100 kcal -> 25%
              carbs: 50, // 50g * 4 = 200 kcal -> 50%
              fat: 11.11, // ~11g * 9 = 100 kcal -> 25%
            ),
          ],
        );

        expect(analysis.proteinPercentage, closeTo(25, 0.1));
      });

      test('should calculate carbs percentage correctly', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Test',
              mass: 100,
              calories: 400,
              protein: 25,
              carbs: 50, // 50g * 4 = 200 kcal -> 50%
              fat: 11.11,
            ),
          ],
        );

        expect(analysis.carbsPercentage, closeTo(50, 0.1));
      });

      test('should calculate fat percentage correctly', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Test',
              mass: 100,
              calories: 400,
              protein: 25,
              carbs: 50,
              fat: 11.11, // ~11g * 9 = ~100 kcal -> ~25%
            ),
          ],
        );

        expect(analysis.fatPercentage, closeTo(25, 0.1));
      });

      test('should return 0 percentages when calories are 0', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Water',
              mass: 250,
              calories: 0,
              protein: 0,
              carbs: 0,
              fat: 0,
            ),
          ],
        );

        expect(analysis.proteinPercentage, 0);
        expect(analysis.carbsPercentage, 0);
        expect(analysis.fatPercentage, 0);
      });

      test('should return 0 percentages for empty foods list', () {
        final analysis = MealAnalysis(foods: []);

        expect(analysis.totalCalories, 0);
        expect(analysis.proteinPercentage, 0);
        expect(analysis.carbsPercentage, 0);
        expect(analysis.fatPercentage, 0);
      });
    });

    test('JSON round-trip should preserve all data', () {
      final original = MealAnalysis(
        foods: [
          AnalyzedFoodItem(
            name: 'Salad',
            mass: 200,
            calories: 45,
            protein: 2,
            carbs: 8,
            fat: 0.5,
          ),
          AnalyzedFoodItem(
            name: 'Dressing',
            mass: 30,
            calories: 150,
            protein: 0,
            carbs: 2,
            fat: 16,
          ),
        ],
      );

      final json = original.toJson();
      final restored = MealAnalysis.fromJson(json);

      expect(restored.foods.length, original.foods.length);
      expect(restored.totalCalories, original.totalCalories);
      expect(restored.totalProtein, original.totalProtein);
    });
  });

  // ============================================================================
  // API RESPONSE PARSING TESTS
  // These test the patterns used by MealAnalysisService for parsing API responses
  // ============================================================================
  group('API Response Parsing Patterns', () {
    // Helper to simulate _extractTextResponse behavior
    String extractTextResponse(Map<String, dynamic> responseData) {
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

    test('should extract text from valid OpenAI response structure', () {
      final responseData = {
        'output': [
          {
            'content': [
              {'type': 'text', 'text': '{"f":[{"n":"Apple","m":150,"k":78,"p":0.5,"c":21,"a":0.3}]}'}
            ]
          }
        ]
      };

      final text = extractTextResponse(responseData);
      expect(text, '{"f":[{"n":"Apple","m":150,"k":78,"p":0.5,"c":21,"a":0.3}]}');
    });

    test('should parse extracted JSON into MealAnalysis', () {
      final jsonText = '{"f":[{"n":"Banana","m":118,"k":105,"p":1.3,"c":27,"a":0.4}]}';
      final parsed = MealAnalysis.fromJson(Map<String, dynamic>.from(
        (const JsonDecoder().convert(jsonText) as Map).cast<String, dynamic>()
      ));

      expect(parsed.foods.length, 1);
      expect(parsed.foods[0].name, 'Banana');
      expect(parsed.foods[0].calories, 105);
    });

    test('should handle multiple food items in API response', () {
      final jsonText = '''
      {
        "f": [
          {"n": "Grilled Chicken", "m": 150, "k": 250, "p": 30, "c": 0, "a": 12},
          {"n": "Steamed Broccoli", "m": 100, "k": 35, "p": 3, "c": 7, "a": 0.4},
          {"n": "Brown Rice", "m": 200, "k": 220, "p": 5, "c": 45, "a": 2}
        ]
      }
      ''';
      final parsed = MealAnalysis.fromJson(Map<String, dynamic>.from(
        (const JsonDecoder().convert(jsonText) as Map).cast<String, dynamic>()
      ));

      expect(parsed.foods.length, 3);
      expect(parsed.totalCalories, 505);
      expect(parsed.totalProtein, 38);
    });

    test('should throw on empty output array', () {
      final responseData = {'output': []};

      expect(() => extractTextResponse(responseData), throwsException);
    });

    test('should throw on missing output key', () {
      final responseData = {'data': 'something'};

      expect(() => extractTextResponse(responseData), throwsException);
    });

    test('should throw on null output', () {
      final responseData = {'output': null};

      expect(() => extractTextResponse(responseData), throwsException);
    });

    test('should throw on empty content array', () {
      final responseData = {
        'output': [
          {'content': []}
        ]
      };

      expect(() => extractTextResponse(responseData), throwsException);
    });

    test('should throw on missing text in content', () {
      final responseData = {
        'output': [
          {
            'content': [
              {'type': 'image', 'url': 'http://example.com'}
            ]
          }
        ]
      };

      expect(() => extractTextResponse(responseData), throwsException);
    });

    test('should throw on empty text string', () {
      final responseData = {
        'output': [
          {
            'content': [
              {'type': 'text', 'text': ''}
            ]
          }
        ]
      };

      expect(() => extractTextResponse(responseData), throwsException);
    });

    test('should find text in mixed content array', () {
      final responseData = {
        'output': [
          {
            'content': [
              {'type': 'image', 'url': 'http://example.com'},
              {'type': 'text', 'text': '{"f":[]}'},
            ]
          }
        ]
      };

      final text = extractTextResponse(responseData);
      expect(text, '{"f":[]}');
    });

    test('should handle real-world complex response', () {
      final responseData = {
        'id': 'resp_123',
        'object': 'response',
        'created_at': 1234567890,
        'output': [
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {
                'type': 'output_text',
                'text': '{"f":[{"n":"Spaghetti Carbonara","m":350,"k":650,"p":25,"c":70,"a":28}]}'
              }
            ]
          }
        ],
        'usage': {'total_tokens': 150}
      };

      final text = extractTextResponse(responseData);
      final parsed = MealAnalysis.fromJson(Map<String, dynamic>.from(
        (const JsonDecoder().convert(text) as Map).cast<String, dynamic>()
      ));

      expect(parsed.foods.length, 1);
      expect(parsed.foods[0].name, 'Spaghetti Carbonara');
      expect(parsed.foods[0].calories, 650);
    });
  });

  // ============================================================================
  // MEAL ANALYSIS SERVICE INSTANCE TESTS
  // ============================================================================
  group('MealAnalysisService Instance', () {
    test('should create service with API key', () {
      final service = MealAnalysisService(apiKey: 'test-api-key');
      expect(service.apiKey, 'test-api-key');
    });

    test('should create service with empty API key', () {
      final service = MealAnalysisService(apiKey: '');
      expect(service.apiKey, '');
    });

    test('should create multiple independent service instances', () {
      final service1 = MealAnalysisService(apiKey: 'key-1');
      final service2 = MealAnalysisService(apiKey: 'key-2');

      expect(service1.apiKey, 'key-1');
      expect(service2.apiKey, 'key-2');
      expect(service1.apiKey, isNot(equals(service2.apiKey)));
    });
  });
}
