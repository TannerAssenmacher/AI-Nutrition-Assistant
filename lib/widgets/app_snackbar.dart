import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppSnackBar {
  static void success(BuildContext context, String message) {
    _show(ScaffoldMessenger.of(context), message, AppColors.success, Icons.check_circle);
  }

  static void error(BuildContext context, String message) {
    _show(ScaffoldMessenger.of(context), message, AppColors.deleteRed, Icons.error);
  }

  static void successFrom(ScaffoldMessengerState messenger, String message) {
    _show(messenger, message, AppColors.success, Icons.check_circle);
  }

  static void errorFrom(ScaffoldMessengerState messenger, String message) {
    _show(messenger, message, AppColors.deleteRed, Icons.error);
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String message,
    Color backgroundColor,
    IconData icon,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.surface),
            const SizedBox(width: 10),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
