import 'package:flutter/material.dart';
import 'package:nutrition_assistant/screens/profile_screen.dart';
import '../theme/app_colors.dart';

class top_bar extends StatelessWidget {
  const top_bar({super.key, this.showProfileButton = false});

  final bool showProfileButton;

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
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: Image.asset(
                  'lib/icons/WISERBITES_txt_only.png',
                  fit: BoxFit.contain,
                  color: AppColors.background,
                ),
              ),
            ),
            if (showProfileButton)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(
                      Icons.account_circle,
                      color: AppColors.background,
                      size: 32,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ProfilePage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = 0.0;
                                const end = 1.0;
                                const curve = Curves.easeInOut;

                                var scaleTween = Tween(
                                  begin: begin,
                                  end: end,
                                ).chain(CurveTween(curve: curve));
                                var fadeTween = Tween(
                                  begin: 0.0,
                                  end: 1.0,
                                ).chain(CurveTween(curve: curve));

                                return ScaleTransition(
                                  scale: animation.drive(scaleTween),
                                  child: FadeTransition(
                                    opacity: animation.drive(fadeTween),
                                    child: child,
                                  ),
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
