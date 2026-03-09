import 'package:flutter/material.dart';

import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_item.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavItem(
                icon: Icons.chat_bubble_outline,
                label: 'Coach',
                isActive: currentIndex == navIndexChat,
                onTap: () => onTap(navIndexChat),
              ),
              NavItem(
                icon: Icons.restaurant_menu,
                label: 'Log',
                isActive: currentIndex == navIndexHistory,
                onTap: () => onTap(navIndexHistory),
              ),
              _HomeButton(
                isSelected: currentIndex == navIndexHome,
                onTap: () => onTap(navIndexHome),
              ),
              NavItem(
                icon: Icons.search,
                label: 'Search',
                isActive: currentIndex == navIndexSearch,
                onTap: () => onTap(navIndexSearch),
              ),
              NavItem(
                icon: Icons.camera_alt_outlined,
                label: 'Photo',
                isActive: currentIndex == navIndexCamera,
                onTap: () => onTap(navIndexCamera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fillColor = isSelected ? const Color(0xFF34C759) : Colors.black;

    return Semantics(
      label: 'Home',
      button: true,
      selected: isSelected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: fillColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.home_filled, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
