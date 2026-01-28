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

    return GestureDetector(
      onTap: onTap,
      //child: Padding(
        //padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).size.height * 0.),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.005)),
          Icon(
            icon,
            color: isActive ? activeColor : Color.fromARGB(255, 109, 94, 88),
            size: MediaQuery.of(context).size.width * 0.1,
          ),
          const SizedBox(height: 4),
          /*Text(
            label,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.03,
              color: isActive ? activeColor : Colors.grey,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),*/
        ],
      ),
    //)
    );
  }
}
