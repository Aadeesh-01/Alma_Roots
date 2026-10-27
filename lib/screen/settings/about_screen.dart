import 'package:flutter/material.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppHeader(theme),
            AppSpacing.gapXXl,
            _buildSection(theme, "Platform Purpose", [
              "• Alumni Networking & Mentorship",
              "• Student Connections",
              "• Exclusive Institute Events",
              "• Direct Messaging",
              "• Professional Networking & Growth",
            ]),
            AppSpacing.gapXl,
            _buildSection(theme, "Technologies Used", [
              "• Flutter framework for cross-platform UI",
              "• Firebase Authentication for security",
              "• Cloud Firestore for real-time database",
              "• Cloud Functions for scalable backend",
            ]),
            AppSpacing.gapXl,
            _buildSection(theme, "Credits", [
              "• Development Team: CS261 Students",
              "• Institution: National Institute of Technology",
            ]),
            AppSpacing.gapXXl,
            _buildLegalLinks(context, theme),
            AppSpacing.gapXXl,
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: Image.asset('assets/images/logo.png', width: 96, height: 96, fit: BoxFit.cover)),
          ),
          AppSpacing.gapLg,
          Column(
          children: [
            Text("Alma Roots", style: textTheme.headlineMedium),
            Text("Version 1.0.0", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<String> items) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapMd,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(item, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLegalLinks(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        _buildLegalLink(theme, "Privacy Policy", () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Privacy Policy coming soon.")));
        }),
        Divider(color: theme.dividerColor, height: 1),
        _buildLegalLink(theme, "Terms of Use", () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Terms of Use coming soon.")));
        }),
      ],
    );
  }

  Widget _buildLegalLink(ThemeData theme, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
