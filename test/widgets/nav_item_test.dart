/// Accessibility tests for NavItem widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/widgets/nav_item.dart';

Widget _buildNavItem({
  required String label,
  bool isActive = false,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: NavItem(
          icon: Icons.home,
          label: label,
          isActive: isActive,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('NavItem semantics', () {
    testWidgets('has semantic label matching the label parameter', (tester) async {
      await tester.pumpWidget(_buildNavItem(label: 'Home'));

      expect(find.bySemanticsLabel('Home'), findsOneWidget);
    });

    testWidgets('active and inactive items both have semantic labels', (tester) async {
      await tester.pumpWidget(_buildNavItem(label: 'Home', isActive: true));
      expect(find.bySemanticsLabel('Home'), findsOneWidget);

      await tester.pumpWidget(_buildNavItem(label: 'Home', isActive: false));
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_buildNavItem(label: 'Home', onTap: () => tapped = true));

      await tester.tap(find.byType(NavItem));
      expect(tapped, isTrue);
    });

    testWidgets('different labels produce different semantic nodes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                NavItem(icon: Icons.home, label: 'Home', isActive: false, onTap: () {}),
                NavItem(icon: Icons.search, label: 'Search', isActive: false, onTap: () {}),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
    });
  });

  group('NavItem accessibility guidelines', () {
    testWidgets('meets iOS tap target guideline (44pt min)', (tester) async {
      await tester.pumpWidget(_buildNavItem(label: 'Home'));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('meets Android tap target guideline (48dp min)', (tester) async {
      await tester.pumpWidget(_buildNavItem(label: 'Home'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('meets labeled tap target guideline', (tester) async {
      await tester.pumpWidget(_buildNavItem(label: 'Home'));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('active item also meets tap target guidelines', (tester) async {
      await tester.pumpWidget(_buildNavItem(label: 'Camera', isActive: true));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });
}
