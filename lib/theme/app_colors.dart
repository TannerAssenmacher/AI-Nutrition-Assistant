import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Original palette (uncomment to revert) ──
  // static const Color brand = Color(0xFF5F9735);
  // static const Color background = Color(0xFFF5EDE2);
  // static const Color navBar = Color(0xFF3E2F26);
  // static const Color topBar = Color(0xFF4A3A2A);
  // static const Color protein = Color(0xFFC2482B);
  // static const Color carbs = Color(0xFFE0A100);
  // static const Color fat = Color(0xFF3A6FB8);
  // static const Color accentBrown = Color(0xFF967460);
  // static const Color inputFill = Color(0xFFF5F1E8);
  // static const Color streakBackground = Color(0xFFFFF3E0);
  // static const Color caloriesCircle = Color(0xFF5F9735);
  // static const Color selectionColor = Color(0xFF6DCFF6);


  // ── Active palette (WCAG AA compliant) ──
  // brand/secondary/caloriesCircle: #5F9735 → #4A7629 (5.4:1 on white, 4.6:1 on background)
  // carbs: #E0A100 → #875C00 (5.9:1 on white, 5.1:1 on background)
  // accentBrown: #967460 → #7A5A47 (6.2:1 on white, 5.4:1 on background)
  // selectionColor: #6DCFF6 → #006E8C (5.8:1 on white, 5.0:1 on background)
  // accent: #C96E35 → #A35720 (5.3:1 on white, 4.6:1 on background)
  // navIconInactive: #6D5E58 → #C0A598 (4.7:1 on navBar background)
  static const Color brand = Color(0xFF4A7629);
  static const Color background = Color(0xFFF5EDE2);
  static const Color navBar = Color(0xFF3E2F26);
  static const Color topBar = Color(0xFF4A3A2A);
  static const Color secondary = Color(0xFF4A7629);
  static const Color accent = Color(0xFFA35720);
  static const Color protein = Color(0xFFC2482B);
  static const Color carbs   = Color(0xFF875C00);
  static const Color fat     = Color(0xFF3A6FB8);
  static const Color accentBrown = Color(0xFF7A5A47);
  static const Color inputFill = Color(0xFFF5F1E8);
  static const Color streakBackground = Color(0xFFFFF3E0);
  static const Color caloriesCircle = Color(0xFF4A7629);
  static const Color selectionColor = Color(0xFF006E8C);
  // Nav icon colors — on navBar (#3E2F26) background
  static const Color navIconActive   = Color(0xFFFFFDFA); // 10.7:1
  static const Color navIconInactive = Color(0xFFC0A598); //  4.7:1

  // ── Shared surfaces ──
  static const Color surface        = Color(0xFFFFFFFF); // card / sheet / dialog background
  static const Color surfaceSubtle  = Color(0xFFFAFAFA); // grey-50 subtle card bg
  static const Color surfaceVariant = Color(0xFFF5F5F5); // grey-100 chip / tile bg

  // ── Borders / dividers ──
  static const Color borderLight  = Color(0xFFE0E0E0); // grey-300
  static const Color divider      = Color(0xFFBDBDBD); // grey-400
  static const Color progressTrack = Color(0xFFEEEEEE); // grey-200 progress bar track

  // ── Status & feedback (WCAG AA compliant for text on white) ──
  static const Color error   = Color(0xFFB00020); // 7.3:1 — errors, delete, danger
  static const Color success = Color(0xFF2E7D32); // 5.1:1 — confirmed, success
  static const Color warning = Color(0xFFC84B00); // 4.7:1 — warning, caution

  // ── Grade scale (S → F); C & D are fill-only indicators ──
  static const Color gradeS = Color(0xFF2E7D32);
  static const Color gradeA = Color(0xFF4CAF50);
  static const Color gradeB = Color(0xFF8BC34A);
  static const Color gradeC = Color(0xFFFFB300); // fill indicator only
  static const Color gradeD = Color(0xFFFF7043); // fill indicator only
  static const Color gradeF = Color(0xFFE53935);

  // ── Nutrient progress status colors (bar / chip fills; not for body text) ──
  static const Color statusOver  = Color(0xFFE53935); // over limit
  static const Color statusNear  = Color(0xFFF57F17); // approaching limit
  static const Color statusGood  = Color(0xFF4CAF50); // on target
  static const Color statusUnder = Color(0xFFFF9800); // under target
  static const Color statusNone  = Color(0xFF9E9E9E); // no data (grey-500)

  // ── Text hierarchy (WCAG AA on white & app background) ──
  static const Color textPrimary   = Color(0xFF212121); // near-black
  static const Color textSecondary = Color(0xFF616161); // grey-700, 5.9:1 on white
  static const Color textHint      = Color(0xFF757575); // grey-600, 4.6:1 on white

  // ── Warm neutrals (meal log card theming) ──
  static const Color warmLight  = Color(0xFFEFEBE9); // brown-50  badge fill
  static const Color warmBorder = Color(0xFFD7CCC8); // brown-100 card border/bg
  static const Color warmMid    = Color(0xFFA1887F); // brown-300 badge border
  static const Color warmDark   = Color(0xFF6D4C41); // brown-600 badge text
  static const Color warmDarker = Color(0xFF5D4037); // brown-700 secondary text

  // ── Miscellaneous ──
  static const Color mealText         = Color(0xFF2E221A); // dark brown text in meal name fields
  static const Color deleteRed        = Color(0xFFD32F2F); // destructive action button
  static const Color neumorphicShadow = Color(0xFFD9D0C3); // chat card neumorphic shadow (dark side)

  // ── Recipe detail dark theme ──
  static const Color recipeSurface = Color(0xFF181818); // near-black background
  static const Color recipeAccent  = Color(0xFF5D8A73); // teal-green accent
  static const Color recipeText    = Color(0xFFF2F4F7); // off-white heading text
  static const Color recipeSubtext = Color(0xFFB8C0CC); // muted blue-grey
  static const Color recipeBody    = Color(0xFFE9EDF4); // body text
  // Recipe image overlay gradient stops (semi-transparent dark teal)
  static const Color recipeOverlayHigh = Color(0xAA2A3A33); // 67% dark teal
  static const Color recipeOverlayMid  = Color(0x2A2A3A33); // 16% dark teal
  static const Color recipeOverlayFade = Color(0x00181818); // 0% — transparent fade

  // ── Camera screen ──
  static const Color cameraBg = Color(0xFF000000); // pure black camera viewfinder background
}
