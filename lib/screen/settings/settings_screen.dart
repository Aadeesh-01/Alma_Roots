import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/screen/profile/profile_edit_screen.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/service/notification_service.dart';
import 'package:cs261_project/screen/settings/help_support_screen.dart';
import 'package:cs261_project/screen/settings/report_bug_screen.dart';
import 'package:cs261_project/screen/settings/about_screen.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/main.dart';

class SettingsScreen extends StatefulWidget {
  final String instituteId;
  const SettingsScreen({super.key, required this.instituteId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  Stream<ParticipantModel?>? _profileStream;

  // Push notification categories; checked by the Cloud Functions before sending.
  static const _notificationCategories = [
    ('messages', Icons.chat_bubble_outline_rounded, 'Messages', 'When someone sends you a message'),
    ('posts', Icons.campaign_outlined, 'News & events', 'New announcements, events and waitlist spots'),
    ('account', Icons.verified_user_outlined, 'Account updates', 'Reactivation decisions'),
  ];
  Map<String, bool> _notificationPrefs = {};

  DocumentReference<Map<String, dynamic>>? get _participantRef {
    final uid = _user?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('institutes')
        .doc(widget.instituteId)
        .collection('participants')
        .doc(uid);
  }

  @override
  void initState() {
    super.initState();
    final uid = _user?.uid;
    if (uid != null) {
      _profileStream = ProfileService(instituteId: widget.instituteId).getProfileStream(uid);
      _loadNotificationPrefs();
    }
  }

  Future<void> _loadNotificationPrefs() async {
    final doc = await _participantRef?.get();
    final raw = doc?.data()?['notificationPrefs'];
    if (!mounted || raw is! Map) return;
    setState(() {
      _notificationPrefs = raw.map((k, v) => MapEntry(k.toString(), v != false));
    });
  }

  Future<void> _setNotificationPref(String key, bool value) async {
    final previous = _notificationPrefs[key];
    setState(() => _notificationPrefs[key] = value);
    try {
      await _participantRef?.update({'notificationPrefs.$key': value});
    } catch (e) {
      if (!mounted) return;
      setState(() => _notificationPrefs[key] = previous ?? true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save that setting.')));
    }
  }

  void _openEditProfile() {
    final uid = _user?.uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen(userDocumentId: uid, instituteId: widget.instituteId)),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastInstituteId');
    await NotificationService.instance.unregister();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildProfileCard(theme),
          const SizedBox(height: 24),

          _sectionLabel(theme, 'Appearance'),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('Theme', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 14),
                ListenableBuilder(
                  listenable: themeService,
                  builder: (context, _) => SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colorScheme.primary,
                      selectedForegroundColor: colorScheme.onPrimary,
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18), label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Dark')),
                    ],
                    selected: {themeService.themeMode},
                    onSelectionChanged: (s) => themeService.setThemeMode(s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionLabel(theme, 'Notifications'),
          AppSurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, (key, icon, title, subtitle)) in _notificationCategories.indexed) ...[
                  if (i > 0) _divider(theme),
                  SwitchListTile(
                    secondary: Icon(icon, color: colorScheme.onSurfaceVariant),
                    title: Text(title, style: theme.textTheme.bodyLarge),
                    subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
                    value: _notificationPrefs[key] ?? true,
                    onChanged: (v) => _setNotificationPref(key, v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionLabel(theme, 'Support'),
          AppSurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _tile(theme, Icons.help_outline_rounded, 'Help & Support', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(instituteId: widget.instituteId)));
                }),
                _divider(theme),
                _tile(theme, Icons.bug_report_outlined, 'Report a bug or give feedback', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportBugScreen(instituteId: widget.instituteId)));
                }),
                _divider(theme),
                _tile(theme, Icons.info_outline_rounded, 'About Alma Roots', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Alma Roots v1.0.0', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    return StreamBuilder<ParticipantModel?>(
      stream: _profileStream,
      builder: (context, snap) {
        final profile = snap.data;
        final name = (profile?.name.isNotEmpty ?? false)
            ? profile!.name
            : (_user?.email?.split('@').first ?? 'Member');
        return AppSurfaceCard(
          onTap: _openEditProfile,
          child: Row(
            children: [
              AppAvatar(name: name, imageUrl: profile?.profileImage, radius: 28, ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_user?.email ?? '', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (profile != null) ...[
                      const SizedBox(height: 6),
                      RoleBadge(role: profile.role, dense: true),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(height: 2),
                  Text('Edit', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tile(ThemeData theme, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodyLarge),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  Widget _divider(ThemeData theme) =>
      Divider(height: 1, indent: 56, endIndent: 16, color: theme.colorScheme.outlineVariant);
}
