import 'package:flutter/material.dart';


class top_bar extends StatelessWidget {
  const top_bar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.1,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF4A3A2A),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).size.height * 0.05, 0, 0),
          child: Center(
            child: Image.asset(
              'lib/icons/WISERBITES_txt_only.png',
              height: MediaQuery.of(context).size.height * 0.04,
              
              color: const Color(0xFFF5EDE2),
            )
            /*child: Text(
            "AI Nutrition Assistant",
            style: TextStyle(
              color: const Color(0xFFF5EDE2),
              fontSize: 50,
              fontWeight: FontWeight.w600,
            ),
            ),*/
          ),
        ),
      )
    );
  }
}