/// Accessibility guideline tests for real app components.
/// Uses Flutter's built-in meetsGuideline() to verify tap targets and labels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/widgets/macro_slider.dart';

void main() {
  // ============================================================================
  // NavBar
  // ============================================================================
  group('NavBar accessibility guidelines', () {
    Widget buildNavBar({int currentIndex = 3}) {
      return MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NavBar(
            currentIndex: currentIndex,
            onTap: (_) {},
          ),
        ),
      );
    }

    // NavBar height is 7% of screen height — simulate a real phone so the bar
    // is tall enough to meet 44/48dp tap target requirements (7% of 844 = 59px).
    void setPhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532); // iPhone 14 Pro points×3
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('meets Android tap target guideline (48dp min)', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildNavBar());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('meets iOS tap target guideline (44pt min)', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildNavBar());
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('meets labeled tap target guideline', (tester) async {
      await tester.pumpWidget(buildNavBar());
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('all five nav items have semantic labels', (tester) async {
      await tester.pumpWidget(buildNavBar());

      expect(find.bySemanticsLabel('Recipes'), findsOneWidget);
      expect(find.bySemanticsLabel('History'), findsOneWidget);
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      expect(find.bySemanticsLabel('Camera'), findsOneWidget);
    });
  });

  // ============================================================================
  // MacroSlider
  // ============================================================================
  group('MacroSlider accessibility guidelines', () {
    Widget buildSlider({
      double protein = 33,
      double carbs = 34,
      double fats = 33,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 100,
            child: MacroSlider(
              protein: protein,
              carbs: carbs,
              fats: fats,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );
    }

    testWidgets('meets Android tap target guideline', (tester) async {
      await tester.pumpWidget(buildSlider());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('has semantic label describing macro percentages', (tester) async {
      await tester.pumpWidget(buildSlider(protein: 30, carbs: 40, fats: 30));

      expect(
        find.bySemanticsLabel(RegExp(r'Protein.*30%.*Carbs.*40%.*Fats.*30%')),
        findsOneWidget,
      );
    });

    testWidgets('semantic label updates when values change', (tester) async {
      await tester.pumpWidget(buildSlider(protein: 50, carbs: 30, fats: 20));

      expect(
        find.bySemanticsLabel(RegExp(r'Protein.*50%.*Carbs.*30%.*Fats.*20%')),
        findsOneWidget,
      );
    });
  });
}
