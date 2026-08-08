import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor

  // ──────────────────────────────────────────
  // Primary palette (Modern Blue)
  // ──────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);       // Blue 800
  static const Color primaryLight = Color(0xFF1976D2);   // Blue 700 (dark mode primary)
  static const Color primaryDark = Color(0xFF0D47A1);    // Blue 900

  // Secondary palette (Warm Amber)
  static const Color secondary = Color(0xFFFF8F00);      // Amber 800
  static const Color secondaryLight = Color(0xFFFFA000);
  static const Color secondaryDark = Color(0xFFFF6F00);

  // Tertiary (Teal accent for variety)
  static const Color tertiary = Color(0xFF00897B);       // Teal 600

  // ──────────────────────────────────────────
  // Status colors
  // ──────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);  // Green 800
  static const Color warning = Color(0xFFF57C00);  // Orange 800
  static const Color error = Color(0xFFD32F2F);    // Red 700
  static const Color info = Color(0xFF1976D2);     // Blue 700

  // ──────────────────────────────────────────
  // Light Mode Surfaces
  // ──────────────────────────────────────────
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;

  // Neutral / Greyscale
  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF49454F);
  static const Color textHint = Color(0xFF79747E);
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFE7E0EC);

  // Specific accent colors used in badges/chips
  static const Color accentPurple = Color(0xFF7C4DFF);
  static const Color accentPink = Color(0xFFE91E63);

  // ──────────────────────────────────────────
  // Dark Mode Surfaces (Material 3 canonical)
  // ──────────────────────────────────────────
  static const Color darkBackground = Color(0xFF141218);
  static const Color darkSurface = Color(0xFF1D1B20);

  // Dark Mode Neutral / Greyscale
  static const Color textDarkPrimary = Color(0xFFE6E0E9);
  static const Color textDarkSecondary = Color(0xFFCAC4D0);
  static const Color textDarkHint = Color(0xFF938F99);
  static const Color darkBorder = Color(0xFF49454F);
  static const Color darkDivider = Color(0xFF36343B);
}
