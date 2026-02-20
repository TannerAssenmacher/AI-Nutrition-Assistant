/// Accessibility guideline tests for real app components.
/// Uses Flutter's built-in meetsGuideline() to verify tap targets and labels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/theme/app_colors.dart';
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

  // ============================================================================
  // Text contrast — macro colors on app background (protein, carbs, fat)
  // ============================================================================
  group('Macro label text contrast', () {
    // MacroSlider labels appear inside white card surfaces in the app, not
    // directly on the app background, so test against AppColors.surface (white).
    Widget buildMacroLabels() {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Protein 33%',
                    style: TextStyle(
                        color: AppColors.protein, fontWeight: FontWeight.bold)),
                Text('Carbs 34%',
                    style: TextStyle(
                        color: AppColors.carbs, fontWeight: FontWeight.bold)),
                Text('Fats 33%',
                    style: TextStyle(
                        color: AppColors.fat, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('protein label meets text contrast guideline', (tester) async {
      await tester.pumpWidget(buildMacroLabels());
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('carbs label meets text contrast guideline', (tester) async {
      await tester.pumpWidget(buildMacroLabels());
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('fat label meets text contrast guideline', (tester) async {
      await tester.pumpWidget(buildMacroLabels());
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // Text contrast — accent and brand colors on app background
  // Covers: accentBrown (home/login/register/forgot_password/daily_log labels),
  //         brand (home_screen text), navBar (daily_log text),
  //         caloriesCircle (daily_log summary text).
  // ============================================================================
  group('App text colors on app background', () {
    Widget textOnAppBg(Color fg) => MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Text('Sample label',
                  style: TextStyle(color: fg, fontSize: 14)),
            ),
          ),
        );

    testWidgets('accentBrown meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnAppBg(AppColors.accentBrown));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('brand meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnAppBg(AppColors.brand));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('navBar color meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnAppBg(AppColors.navBar));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('caloriesCircle meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnAppBg(AppColors.caloriesCircle));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('selectionColor meets text contrast guideline', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Today',
                style: TextStyle(
                    color: AppColors.selectionColor, fontSize: 14)),
          ),
        ),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // Text contrast — white text on colored button backgrounds
  // Covers: brand buttons (login/register/forgot_password/food_search),
  //         accentBrown button (daily_log), navBar-colored button (daily_log).
  // ============================================================================
  group('White text on colored button backgrounds', () {
    Widget whiteOnButton(Color bgColor) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor,
                  foregroundColor: AppColors.surface,
                ),
                onPressed: () {},
                child: const Text('Submit'),
              ),
            ),
          ),
        );

    testWidgets('white text on brand button meets text contrast guideline',
        (tester) async {
      await tester.pumpWidget(whiteOnButton(AppColors.brand));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets(
        'white text on accentBrown button meets text contrast guideline',
        (tester) async {
      await tester.pumpWidget(whiteOnButton(AppColors.accentBrown));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('white text on navBar button meets text contrast guideline',
        (tester) async {
      await tester.pumpWidget(whiteOnButton(AppColors.navBar));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // NavBar icon colors on navBar background
  // Icons are graphical — textContrastGuideline doesn't scan them directly, so
  // we render Text in the same colors to catch regressions when AppColors changes.
  // Active:   AppColors.navIconActive   (#FFFDF A) — 10.7:1 on navBar ✓
  // Inactive: AppColors.navIconInactive (#C0A598)  —  4.7:1 on navBar ✓
  //           (was #6D5E58 = 1.75:1 — failed WCAG non-text contrast)
  // ============================================================================
  group('NavBar icon colors on navBar background', () {
    Widget iconColorOnNavBar(Color color) => MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.navBar,
            body: Center(
              child: Text('Nav item',
                  style: TextStyle(color: color, fontSize: 14)),
            ),
          ),
        );

    testWidgets('active icon color meets contrast guideline', (tester) async {
      await tester.pumpWidget(iconColorOnNavBar(AppColors.navIconActive));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('inactive icon color meets contrast guideline', (tester) async {
      await tester.pumpWidget(iconColorOnNavBar(AppColors.navIconInactive));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // TopBar: background-colored logo and icon on topBar background
  // background (#F5EDE2) on topBar (#4A3A2A) = 9.4:1
  // ============================================================================
  group('TopBar color pair', () {
    testWidgets(
        'background color on topBar background meets contrast guideline',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.topBar,
          body: Center(
            child: Text('WiserBites',
                style: TextStyle(color: AppColors.background, fontSize: 18)),
          ),
        ),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // Accent color (currently unused in app UI — regression guard)
  // accent (#A35720): 5.3:1 on white, 4.6:1 on app background
  // ============================================================================
  group('Accent color', () {
    testWidgets('accent meets contrast guideline on app background',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: const Center(
            child: Text('Accent label',
                style: TextStyle(color: AppColors.accent, fontSize: 14)),
          ),
        ),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('accent meets contrast guideline on white', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Accent label',
                style: TextStyle(color: AppColors.accent, fontSize: 14)),
          ),
        ),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // Status & feedback colors as text on white surface
  // error   (#B00020): 7.3:1 on white ✓
  // success (#2E7D32): 5.1:1 on white ✓
  // warning (#C84B00): 4.7:1 on white ✓
  // deleteRed (#D32F2F): ~4.7:1 on white ✓
  // ============================================================================
  group('Status and feedback text on white surface', () {
    Widget textOnSurface(Color fg, String label) => MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(
              child: Text(label, style: TextStyle(color: fg, fontSize: 14)),
            ),
          ),
        );

    testWidgets('error color meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.error, 'Error message'));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('success color meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.success, 'Success'));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('warning color meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.warning, 'Warning'));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('deleteRed meets text contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.deleteRed, 'Delete'));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // Text hierarchy — the three body-text colors on both main surfaces.
  // textPrimary   (#212121): 16.1:1 on white, ~14:1 on background ✓
  // textSecondary (#616161):  5.9:1 on white,  ~5.1:1 on background ✓
  // textHint      (#757575):  4.6:1 on white  ✓
  //   (on background = ~3.9:1, below AA threshold — only used on white cards)
  // ============================================================================
  group('Text hierarchy on white surface', () {
    Widget textOnSurface(Color fg) => MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(
              child: Text('Body text', style: TextStyle(color: fg, fontSize: 14)),
            ),
          ),
        );

    testWidgets('textPrimary meets contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.textPrimary));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('textSecondary meets contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.textSecondary));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('textHint meets contrast guideline', (tester) async {
      await tester.pumpWidget(textOnSurface(AppColors.textHint));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  group('Text hierarchy on app background', () {
    Widget textOnBackground(Color fg) => MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Text('Body text', style: TextStyle(color: fg, fontSize: 14)),
            ),
          ),
        );

    testWidgets('textPrimary on background meets contrast guideline',
        (tester) async {
      await tester.pumpWidget(textOnBackground(AppColors.textPrimary));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('textSecondary on background meets contrast guideline',
        (tester) async {
      await tester.pumpWidget(textOnBackground(AppColors.textSecondary));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  // ============================================================================
  // Input fill background — text fields use AppColors.inputFill as fill color.
  // inputFill (#F5F1E8) is near-white; any on-surface text will pass easily.
  // ============================================================================
  group('Text on inputFill background', () {
    testWidgets('accentBrown label on inputFill meets contrast guideline',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.inputFill,
          body: Center(
            child: Text('Email address',
                style:
                    TextStyle(color: AppColors.accentBrown, fontSize: 14)),
          ),
        ),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('navBar color label on inputFill meets contrast guideline',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.inputFill,
          body: Center(
            child: Text('Password',
                style: TextStyle(color: AppColors.navBar, fontSize: 14)),
          ),
        ),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
