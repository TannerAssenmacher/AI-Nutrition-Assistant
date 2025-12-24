import 'package:flutter/material.dart';


class top_bar extends StatelessWidget {
  const top_bar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF4A3A2A),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 60, 0, 0),
          child: Center(
            child: Text(
            "AI Nutrition Assistant",
            style: TextStyle(
              color: const Color(0xFFF5EDE2),
              fontSize: 50,
              fontWeight: FontWeight.w600,
            ),
            ),
          ),
        ),
      )
    );
  }
}