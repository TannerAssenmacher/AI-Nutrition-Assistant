import 'package:flutter/material.dart';

const int navIndexChat = 1;
const int navIndexHistory = 2;
const int navIndexHome = 3;
const int navIndexCamera = 4;
const int navIndexProfile = 5;

/// Centralized navigation handler for the bottom nav bar.
void handleNavTap(BuildContext context, int targetIndex) {
  if (targetIndex == navIndexHistory) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('History is coming soon.'),
      ),
    );
    return;
  }

  String? targetRoute;
  switch (targetIndex) {
    case navIndexChat:
      targetRoute = '/chat';
      break;
    case navIndexHome:
      targetRoute = '/home';
      break;
    case navIndexCamera:
      targetRoute = '/camera';
      break;
    case navIndexProfile:
      targetRoute = '/profile';
      break;
    default:
      targetRoute = null;
  }

  if (targetRoute == null) return;

  final currentRoute = ModalRoute.of(context)?.settings.name;
  if (currentRoute == targetRoute) {
    return;
  }

  Navigator.pushReplacementNamed(context, targetRoute);
}
