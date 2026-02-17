/// Widget tests for MacroSlider
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/theme/app_colors.dart';
import 'package:nutrition_assistant/widgets/macro_slider.dart';

void main() {
  group('MacroSlider', () {
    testWidgets('should display initial macro values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 30.0,
              carbs: 40.0,
              fats: 30.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      expect(find.text('Protein 30%'), findsOneWidget);
      expect(find.text('Carbs 40%'), findsOneWidget);
      expect(find.text('Fats 30%'), findsOneWidget);
    });

    testWidgets('should display custom macro values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 25.0,
              carbs: 50.0,
              fats: 25.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      expect(find.text('Protein 25%'), findsOneWidget);
      expect(find.text('Carbs 50%'), findsOneWidget);
      expect(find.text('Fats 25%'), findsOneWidget);
    });

    testWidgets('should render with correct colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 33.0,
              carbs: 34.0,
              fats: 33.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      // Verify text widgets with colors exist
      final proteinText = tester.widget<Text>(find.text('Protein 33%'));
      expect(proteinText.style?.color, AppColors.protein);

      final carbsText = tester.widget<Text>(find.text('Carbs 34%'));
      expect(carbsText.style?.color, AppColors.carbs);

      final fatsText = tester.widget<Text>(find.text('Fats 33%'));
      expect(fatsText.style?.color, AppColors.fat);
    });

    testWidgets('should contain gesture detector for dragging', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 30.0,
              carbs: 40.0,
              fats: 30.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('should have correct widget structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 30.0,
              carbs: 40.0,
              fats: 30.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      // Should use LayoutBuilder for responsive sizing
      expect(find.byType(LayoutBuilder), findsOneWidget);
      // Should have a Column for layout
      expect(find.byType(Column), findsOneWidget);
      // Should have a Row for macro labels
      expect(find.byType(Row), findsOneWidget);
      // Should use Stack for layered bar visualization (at least one)
      expect(find.byType(Stack), findsAtLeast(1));
    });

    testWidgets('should call onChanged when dragging', (tester) async {
      double lastProtein = 0;
      double lastCarbs = 0;
      double lastFats = 0;
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500, // Larger width to prevent overflow
              height: 100,
              child: MacroSlider(
                protein: 30.0,
                carbs: 40.0,
                fats: 30.0,
                onChanged: (protein, carbs, fats) {
                  lastProtein = protein;
                  lastCarbs = carbs;
                  lastFats = fats;
                  callCount++;
                },
              ),
            ),
          ),
        ),
      );

      // Find the gesture detector
      final gestureDetector = find.byType(GestureDetector);
      
      // Perform a drag gesture
      await tester.drag(gestureDetector, const Offset(20, 0));
      await tester.pump();

      // Callback should have been called
      expect(callCount, greaterThan(0));
      // Values should still sum to 100
      expect((lastProtein + lastCarbs + lastFats).round(), 100);
    });

    testWidgets('should handle edge case with 0% values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 0.0,
              carbs: 100.0,
              fats: 0.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      expect(find.text('Protein 0%'), findsOneWidget);
      expect(find.text('Carbs 100%'), findsOneWidget);
      expect(find.text('Fats 0%'), findsOneWidget);
    });

    testWidgets('should handle decimal values correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 33.33,
              carbs: 33.34,
              fats: 33.33,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      // Values should be rounded for display
      expect(find.text('Protein 33%'), findsOneWidget);
      expect(find.text('Carbs 33%'), findsOneWidget);
      expect(find.text('Fats 33%'), findsOneWidget);
    });

    testWidgets('should maintain text styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroSlider(
              protein: 30.0,
              carbs: 40.0,
              fats: 30.0,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );

      // All macro texts should be bold
      final proteinText = tester.widget<Text>(find.text('Protein 30%'));
      expect(proteinText.style?.fontWeight, FontWeight.bold);

      final carbsText = tester.widget<Text>(find.text('Carbs 40%'));
      expect(carbsText.style?.fontWeight, FontWeight.bold);

      final fatsText = tester.widget<Text>(find.text('Fats 30%'));
      expect(fatsText.style?.fontWeight, FontWeight.bold);
    });
  });

  group('MacroSlider drag behavior', () {
    testWidgets('should update values on horizontal drag', (tester) async {
      final values = <List<double>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500, // Larger width to prevent overflow
              height: 100,
              child: MacroSlider(
                protein: 33.0,
                carbs: 34.0,
                fats: 33.0,
                onChanged: (protein, carbs, fats) {
                  values.add([protein, carbs, fats]);
                },
              ),
            ),
          ),
        ),
      );

      // Perform drag
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GestureDetector)),
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();
      await tester.pump();

      // Should have received updates
      expect(values.isNotEmpty, isTrue);
      
      // Each update should have values summing to 100
      for (final v in values) {
        expect((v[0] + v[1] + v[2]).round(), 100);
      }
    });

    testWidgets('should clamp values within valid range', (tester) async {
      double lastProtein = 0;
      double lastCarbs = 0;
      double lastFats = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500, // Larger width to prevent overflow
              height: 100,
              child: MacroSlider(
                protein: 50.0,
                carbs: 30.0,
                fats: 20.0,
                onChanged: (protein, carbs, fats) {
                  lastProtein = protein;
                  lastCarbs = carbs;
                  lastFats = fats;
                },
              ),
            ),
          ),
        ),
      );

      // Drag far to the left (should clamp)
      await tester.drag(find.byType(GestureDetector), const Offset(-500, 0));
      await tester.pump();

      // Values should still be valid (non-negative and sum to 100)
      expect(lastProtein, greaterThanOrEqualTo(0));
      expect(lastCarbs, greaterThanOrEqualTo(0));
      expect(lastFats, greaterThanOrEqualTo(0));
      expect((lastProtein + lastCarbs + lastFats).round(), 100);
    });
  });
}
