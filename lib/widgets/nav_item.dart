import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  static const Color _activeColor = AppColors.navBar;

  @override
  Widget build(BuildContext context) {
    const inactiveColor = AppColors.homeTextSecondary;

    return Semantics(
      label: label,
      button: true,
      selected: isActive,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 58),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 42;
              final color = isActive ? _activeColor : inactiveColor;

              if (isCompact) {
                return Center(child: Icon(icon, color: color, size: 22));
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
