import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────
  // Color schemes
  // ─────────────────────────────────────────────────
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.forest,
    onPrimary: Colors.white,
    primaryContainer: AppColors.forestSoft,
    onPrimaryContainer: Color(0xFF0F2A1F),
    secondary: AppColors.goldDeep,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.goldSoft,
    onSecondaryContainer: Color(0xFF4A3A10),
    tertiary: AppColors.sage,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD5E8E1),
    onTertiaryContainer: Color(0xFF103A30),
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppColors.surfaceLow,
    surfaceContainer: AppColors.surfaceMid,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: Color(0xFFE3DDCF),
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    shadow: Color(0xFF1C2421),
    scrim: Colors.black,
    inverseSurface: Color(0xFF1C2421),
    onInverseSurface: Color(0xFFF1EFE9),
    inversePrimary: AppColors.primaryLight,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryLight,
    onPrimary: Color(0xFF08281A),
    primaryContainer: AppColors.forest,
    onPrimaryContainer: Color(0xFFCDEBD9),
    secondary: AppColors.secondaryLight,
    onSecondary: Color(0xFF3A2C05),
    secondaryContainer: Color(0xFF4A3A10),
    onSecondaryContainer: Color(0xFFF4E3B5),
    tertiary: Color(0xFF8CC7B5),
    onTertiary: Color(0xFF06372B),
    tertiaryContainer: Color(0xFF235345),
    onTertiaryContainer: Color(0xFFCDEDE2),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: AppColors.darkSurface,
    onSurface: AppColors.textDarkPrimary,
    onSurfaceVariant: AppColors.textDarkSecondary,
    surfaceContainerLowest: Color(0xFF0B110E),
    surfaceContainerLow: Color(0xFF121A16),
    surfaceContainer: AppColors.darkSurfaceMid,
    surfaceContainerHigh: AppColors.darkSurfaceHigh,
    surfaceContainerHighest: Color(0xFF2C3B34),
    outline: AppColors.darkBorder,
    outlineVariant: AppColors.darkDivider,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.textDarkPrimary,
    onInverseSurface: Color(0xFF1C2421),
    inversePrimary: AppColors.forest,
    surfaceTint: Colors.transparent,
  );

  static ThemeData get lightTheme => _build(_lightScheme, AppColors.background);
  static ThemeData get darkTheme => _build(_darkScheme, AppColors.darkBackground);

  // ─────────────────────────────────────────────────
  // Typography: Fraunces (serif) for display & headings, Plus Jakarta Sans for UI text
  // ─────────────────────────────────────────────────
  static TextTheme _textTheme(ColorScheme cs) {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      cs.brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    TextStyle? serif(TextStyle? s, {FontWeight weight = FontWeight.w600, double? spacing}) =>
        GoogleFonts.fraunces(textStyle: s, fontWeight: weight, letterSpacing: spacing, color: cs.onSurface);

    return base.copyWith(
      displayLarge: serif(base.displayLarge, spacing: -1.0),
      displayMedium: serif(base.displayMedium, spacing: -0.8),
      displaySmall: serif(base.displaySmall, spacing: -0.6),
      headlineLarge: serif(base.headlineLarge, spacing: -0.5),
      headlineMedium: serif(base.headlineMedium, spacing: -0.4),
      headlineSmall: serif(base.headlineSmall, spacing: -0.3),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.4),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45, color: cs.onSurface),
      bodySmall: base.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    );
  }

  static ThemeData _build(ColorScheme cs, Color background) {
    final text = _textTheme(cs);
    final isDark = cs.brightness == Brightness.dark;
    final radiusMd = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: cs.outlineVariant,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: cs.onSurface),
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: cs.onSurface,
        ),
      ),

      // ── Navigation bar ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: isDark ? cs.primaryContainer : cs.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            fontSize: 11.5,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? (isDark ? cs.onPrimaryContainer : cs.primary) : cs.onSurfaceVariant,
          );
        }),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size(64, 52),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size(64, 52),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: cs.onSurface),
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cs.surfaceContainer : cs.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 16),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: cs.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: cs.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: cs.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: cs.error, width: 1.6)),
        hintStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
        labelStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
      ),

      // ── Surfaces ──
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: AppSpacing.lg),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surface,
        selectedColor: cs.primary,
        secondarySelectedColor: cs.primary,
        side: BorderSide(color: cs.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(color: cs.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: cs.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkmarkColor: cs.onPrimary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        indicator: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(100)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? cs.onPrimary : cs.outline),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? cs.primary : cs.surfaceContainerHigh),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
      iconTheme: IconThemeData(color: cs.onSurface, size: 24),

      // ── Overlays ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: cs.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusMd, side: BorderSide(color: cs.outlineVariant)),
        textStyle: text.bodyMedium,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: text.labelLarge,
      ),

      // ── Page Transitions ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
