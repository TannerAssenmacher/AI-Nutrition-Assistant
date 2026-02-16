import 'package:flutter/material.dart';
import 'package:nutrition_assistant/widgets/nav_item.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).size.height * 0.02; // Adjust based on your needs
    final barHeight = MediaQuery.of(context).size.height * 0.07;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3E2F26),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: barHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavItem(
              icon: Icons.restaurant_outlined,
              label: "Recipes",
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            NavItem(
              icon: Icons.calendar_month,
              label: "History",
              isActive: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            NavItem(
              icon: Icons.home,
              label: "Home",
              isActive: currentIndex == 3,
              onTap: () => onTap(3),
            ),
            NavItem(
              icon: Icons.search,
              label: "Search",
              isActive: currentIndex == 4,
              onTap: () => onTap(4),
            ),
            NavItem(
              icon: Icons.camera_alt,
              label: "Camera",
              isActive: currentIndex == 5,
              onTap: () => onTap(5),
            ),
          ],
        ),
      ),
    );
  }
}
