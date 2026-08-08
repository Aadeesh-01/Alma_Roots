import 'package:flutter/material.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final Color? iconColor;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      elevation: 8,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (iconColor ?? colorScheme.primary).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor ?? colorScheme.primary,
                ),
              ),
              AppSpacing.gapLg,
            ],
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapMd,
            DefaultTextStyle(
              style: textTheme.bodyLarge ?? const TextStyle(),
              child: content,
            ),
            AppSpacing.gapLg,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions.map((action) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: action,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
