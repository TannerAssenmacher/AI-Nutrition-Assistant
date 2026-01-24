import 'package:flutter/material.dart';

const int navIndexChat = 1;
const int navIndexHistory = 2;
const int navIndexHome = 3;
const int navIndexCamera = 4;
const int navIndexProfile = 5;

/// Centralized navigation handler for the bottom nav bar.
void handleNavTap(BuildContext context, int targetIndex) {
  String? targetRoute;
  bool useRegularPush = false; // For screens that should allow back navigation

  switch (targetIndex) {
    case navIndexChat:
      targetRoute = '/chat';
      useRegularPush = true; // Allow back navigation from chat
      break;
    case navIndexHistory:
      targetRoute = '/calendar';
      useRegularPush = true; // Allow back navigation from history
      break;
    case navIndexHome:
      targetRoute = '/home';
      break;
    case navIndexCamera:
      targetRoute = '/camera';
      break;
    case navIndexProfile:
      targetRoute = '/profile';
      useRegularPush = true; // Allow back navigation from profile
      break;
    default:
      targetRoute = null;
  }

  if (targetRoute == null) return;

  final currentRoute = ModalRoute.of(context)?.settings.name;
  if (currentRoute == targetRoute) {
    return;
  }

  if (useRegularPush) {
    Navigator.pushNamed(context, targetRoute);
  } else {
    Navigator.pushReplacementNamed(context, targetRoute);
  }
}
