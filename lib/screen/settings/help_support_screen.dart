import 'package:flutter/material.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/report_bug_screen.dart';
import 'package:cs261_project/screen/settings/about_screen.dart';


class HelpSupportScreen extends StatelessWidget {
  final String instituteId;
  const HelpSupportScreen({super.key, required this.instituteId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        children: [
          _buildSectionTitle(theme, "Frequently Asked Questions"),
          AppSpacing.gapMd,
          _buildFAQItem(theme, 
            "How do I search alumni?",
            "Navigate to the 'Search' tab from the home screen. You can search by name, role, or graduation year.",
          ),
          _buildFAQItem(theme, 
            "How do I send messages?",
            "Go to the 'Inbox' tab or visit an alumni's profile and click the 'Message' button to start a conversation.",
          ),
          _buildFAQItem(theme, 
            "How do I join events?",
            "Visit the 'News' tab and click on the 'Events' filter. Tap on any event to view details and RSVP.",
          ),
          _buildFAQItem(theme, 
            "How do I update my profile?",
            "Go to the 'Profile' tab, or navigate to Settings > Edit Profile to update your professional information.",
          ),
          _buildFAQItem(theme, 
            "How do I request account reactivation?",
            "If your account is deactivated, contact your institute administrator through the support email provided below.",
          ),
          
          AppSpacing.gapXXl,
          _buildSectionTitle(theme, "Contact Support"),
          AppSpacing.gapMd,
          _buildContactCard(theme, 
            Icons.email_outlined,
            "Support Email",
            "support@alumniconnect.com",
          ),
          AppSpacing.gapSm,
          _buildContactCard(theme, 
            Icons.business_outlined,
            "Institute Contact",
            "admin@institute.edu",
          ),
          
          AppSpacing.gapXXl,
          _buildSectionTitle(theme, "Quick Links"),
          AppSpacing.gapMd,
          _buildQuickLink(theme, 
            "Report a Bug / Feedback",
            Icons.bug_report_outlined,
            () {
              // We need the instituteId. We can get it from the user's custom claims or just pass an empty string 
              // for now, but ideally we should pass it. Since we don't have it in context easily, we can just 
              // for now, but ideally we should pass it. Since we don't have it in context easily, we can just 
              // fetch it or require it. For simplicity in the UI, we'll pass a placeholder or get it.
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReportBugScreen(instituteId: instituteId)));
            },
          ),
          AppSpacing.gapSm,
          _buildQuickLink(theme, 
            "About App",
            Icons.info_outline,
            () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
          AppSpacing.gapXXl,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFAQItem(ThemeData theme, String question, String answer) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: BorderSide(color: theme.dividerColor),
      ),
      color: theme.colorScheme.surface,
      child: ExpansionTile(
        title: Text(question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: theme.colorScheme.onSurfaceVariant,
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildContactCard(ThemeData theme, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          AppSpacing.gapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(subtitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLink(ThemeData theme, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface),
            AppSpacing.gapMd,
            Expanded(
              child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
