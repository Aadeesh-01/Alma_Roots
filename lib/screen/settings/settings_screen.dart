import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/help_support_screen.dart';
import 'package:cs261_project/screen/settings/report_bug_screen.dart';
import 'package:cs261_project/screen/settings/about_screen.dart';
import 'package:cs261_project/main.dart';

class SettingsScreen extends StatefulWidget {
  final String instituteId;
  const SettingsScreen({super.key, required this.instituteId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state for toggles (mocking persistent local storage for now)
  bool _msgNotif = true;
  bool _eventNotif = true;
  bool _newsNotif = true;
  bool _reactNotif = true;
  bool _profileVisible = true;
  bool _showEmail = false;
  bool _showContact = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          _buildSectionHeader(theme, "Account"),
          _buildListTile(theme, "Edit Profile", Icons.edit, () => _showComingSoon(context)),
          _buildListTile(theme, "Change Profile Picture", Icons.photo_camera, () => _showComingSoon(context)),
          _buildListTile(theme, "Institute Information", Icons.account_balance, () => _showComingSoon(context)),
          _buildListTile(theme, "Account Status", Icons.verified_user, () => _showComingSoon(context)),
          
          _buildSectionDivider(theme),
          _buildSectionHeader(theme, "Notifications"),
          _buildSwitchTile(theme, "Message Notifications", Icons.message, _msgNotif, (val) => setState(() => _msgNotif = val)),
          _buildSwitchTile(theme, "Event Notifications", Icons.event, _eventNotif, (val) => setState(() => _eventNotif = val)),
          _buildSwitchTile(theme, "News Notifications", Icons.article, _newsNotif, (val) => setState(() => _newsNotif = val)),
          _buildSwitchTile(theme, "Reactivation Request Updates", Icons.update, _reactNotif, (val) => setState(() => _reactNotif = val)),
          
          _buildSectionDivider(theme),
          _buildSectionHeader(theme, "Appearance"),
          ListenableBuilder(
            listenable: themeService,
            builder: (context, _) {
              return _buildSwitchTile(
                theme,
                "Dark Theme", 
                Icons.dark_mode, 
                themeService.isDarkMode, 
                (val) => themeService.toggleTheme()
              );
            }
          ),
          
          _buildSectionDivider(theme),
          _buildSectionHeader(theme, "Privacy"),
          _buildSwitchTile(theme, "Profile Visibility", Icons.visibility, _profileVisible, (val) => setState(() => _profileVisible = val)),
          _buildSwitchTile(theme, "Show Email", Icons.email, _showEmail, (val) => setState(() => _showEmail = val)),
          _buildSwitchTile(theme, "Show Contact Information", Icons.contact_phone, _showContact, (val) => setState(() => _showContact = val)),
          
          _buildSectionDivider(theme),
          _buildSectionHeader(theme, "Support"),
          _buildListTile(theme, "Help & Support", Icons.help_outline, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(instituteId: widget.instituteId)));
          }),
          _buildListTile(theme, "Report Bug / Feedback", Icons.bug_report, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReportBugScreen(instituteId: widget.instituteId)));
          }),
          _buildListTile(theme, "About App", Icons.info_outline, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
          }),
          
          _buildSectionDivider(theme),
          _buildSectionHeader(theme, "Security"),
          _buildListTile(theme, "Account Information", Icons.security, () => _showComingSoon(context)),
          _buildListTile(theme, "Logout", Icons.logout, () async {
            await FirebaseAuth.instance.signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (route) => false,
            );
          }, isDestructive: true),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("This feature will be available in the next update.")),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(ThemeData theme, String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      leading: Icon(icon, color: isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(ThemeData theme, String title, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      secondary: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodyLarge),
      value: value,
      activeColor: theme.colorScheme.primary,
      onChanged: onChanged,
    );
  }

  Widget _buildSectionDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(color: theme.dividerColor, height: 1),
    );
  }
}
