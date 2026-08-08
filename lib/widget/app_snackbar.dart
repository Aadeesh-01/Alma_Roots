import 'package:flutter/material.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AppSnackBar {
  AppSnackBar._();

  static void showSuccess(BuildContext context, String message) {
    // Green 800 for success
    const successColor = Color(0xFF2E7D32);
    _showSnackBar(context, message, successColor, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    final theme = Theme.of(context);
    _showSnackBar(context, message, theme.colorScheme.error, Icons.error_outline);
  }

  static void showInfo(BuildContext context, String message) {
    final theme = Theme.of(context);
    _showSnackBar(context, message, theme.colorScheme.primary, Icons.info_outline);
  }

  static void _showSnackBar(BuildContext context, String message, Color bgColor, IconData icon) {
    final theme = Theme.of(context);
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          margin: const EdgeInsets.all(AppSpacing.md),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
