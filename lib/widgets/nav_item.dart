import 'package:flutter/material.dart';

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color.fromARGB(255, 255, 253, 250);

    return Semantics(
      label: label,
      button: true,
      selected: isActive,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.005)),
              Icon(
                icon,
                color: isActive ? activeColor : Color.fromARGB(255, 109, 94, 88),
                size: MediaQuery.of(context).size.height * 0.05,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
