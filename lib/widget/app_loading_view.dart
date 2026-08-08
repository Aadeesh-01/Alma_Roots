import 'package:flutter/material.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AppLoadingView extends StatelessWidget {
  final String? message;
  final bool isOverlay;

  const AppLoadingView({
    super.key,
    this.message,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            strokeWidth: 3,
          ),
          if (message != null) ...[
            AppSpacing.gapMd,
            Text(
              message!,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );

    if (isOverlay) {
      return Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: content,
      );
    }

    return content;
  }
}
