import 'package:flutter/material.dart';

const int navIndexChat = 1;
const int navIndexHistory = 2;
const int navIndexHome = 3;
const int navIndexSearch = 4;
const int navIndexCamera = 5;
const int navIndexProfile = 6;

/// Centralized navigation handler for the bottom nav bar.
void handleNavTap(BuildContext context, int targetIndex) {
  String? targetRoute;

  switch (targetIndex) {
    case navIndexChat:
      targetRoute = '/chat';
      break;
    case navIndexHistory:
      targetRoute = '/calendar';
      break;
    case navIndexHome:
      targetRoute = '/home';
      break;
    case navIndexSearch:
      targetRoute = '/search';
      break;
    case navIndexCamera:
      targetRoute = '/camera';
      break;
    default:
      targetRoute = null;
  }

  if (targetRoute == null) return;

  final currentRoute = ModalRoute.of(context)?.settings.name;
  if (currentRoute == targetRoute) {
    return;
  }

  // Use pushNamedAndRemoveUntil for clean tab transitions without building a stack
  Navigator.pushNamedAndRemoveUntil(
    context,
    targetRoute,
    (route) => false,
  );
}
