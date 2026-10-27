import 'package:flutter/material.dart';

/// Brand palette derived from the Alma Roots logo (gold tree on warm white),
/// anchored by a deep forest green.
class AppColors {
  AppColors._(); // Private constructor

  // ──────────────────────────────────────────
  // Brand
  // ──────────────────────────────────────────
  static const Color forest = Color(0xFF1F4D3A);        // Primary brand green
  static const Color forestDeep = Color(0xFF12342A);    // Gradients, pressed states
  static const Color forestSoft = Color(0xFFDCEBE2);    // Light container
  static const Color gold = Color(0xFFC9A24B);          // Logo gold (accents, never body text on white)
  static const Color goldDeep = Color(0xFF8A6A1F);      // Gold that passes contrast on light surfaces
  static const Color goldSoft = Color(0xFFF4E9CC);      // Light gold container
  static const Color sage = Color(0xFF3E7C6B);          // Tertiary
  static const Color clay = Color(0xFFB4643C);          // Warm accent for admin / highlights

  // Kept for existing references
  static const Color primary = forest;
  static const Color primaryLight = Color(0xFF8FCBA9);  // Dark-mode primary
  static const Color primaryDark = forestDeep;
  static const Color secondary = gold;
  static const Color secondaryLight = Color(0xFFE2C27A);
  static const Color secondaryDark = goldDeep;
  static const Color tertiary = sage;

  // ──────────────────────────────────────────
  // Status colors
  // ──────────────────────────────────────────
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFB3261E);
  static const Color info = Color(0xFF2F6F8F);

  // ──────────────────────────────────────────
  // Light Mode Surfaces (warm paper)
  // ──────────────────────────────────────────
  static const Color background = Color(0xFFF6F3EC);
  static const Color surface = Colors.white;
  static const Color surfaceLow = Color(0xFFFBF9F4);
  static const Color surfaceMid = Color(0xFFF1EDE3);
  static const Color surfaceHigh = Color(0xFFEAE5D9);

  // Neutral
  static const Color textPrimary = Color(0xFF1C2421);
  static const Color textSecondary = Color(0xFF5B6660);
  static const Color textHint = Color(0xFF8A938E);
  static const Color border = Color(0xFFB9B3A5);
  static const Color divider = Color(0xFFE6E1D6);

  // Kept for existing references
  static const Color accentPurple = sage;
  static const Color accentPink = clay;

  // ──────────────────────────────────────────
  // Dark Mode Surfaces (deep green-black)
  // ──────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0E1512);
  static const Color darkSurface = Color(0xFF151E1A);
  static const Color darkSurfaceMid = Color(0xFF1C2722);
  static const Color darkSurfaceHigh = Color(0xFF24322B);

  static const Color textDarkPrimary = Color(0xFFE4EAE6);
  static const Color textDarkSecondary = Color(0xFFA9B5AE);
  static const Color textDarkHint = Color(0xFF7C8983);
  static const Color darkBorder = Color(0xFF4B5A53);
  static const Color darkDivider = Color(0xFF2A3731);

  // ──────────────────────────────────────────
  // Gradients
  // ──────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF24573F), forestDeep],
  );

  /// Avatar tints, picked deterministically from a name.
  static const List<Color> avatarPalette = [
    Color(0xFF1F4D3A),
    Color(0xFF8A6A1F),
    Color(0xFF3E7C6B),
    Color(0xFFB4643C),
    Color(0xFF2F6F8F),
    Color(0xFF6B5B95),
  ];

  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'alumni':
        return goldDeep;
      case 'admin':
        return clay;
      default:
        return sage;
    }
  }
}
