import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class top_bar extends StatelessWidget {
  const top_bar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.1,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.topBar,
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
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(  context).size.width * 0.4,
            child: Image.asset(
              'lib/icons/WISERBITES_txt_only.png',
              fit: BoxFit.contain,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}
