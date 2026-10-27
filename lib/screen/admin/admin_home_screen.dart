import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/admin/admin_add_user_screen.dart';
import 'package:cs261_project/screen/admin/admin_institute_list_screen.dart';
import 'package:cs261_project/screen/events_and_news/news_event_screen.dart';
import 'package:cs261_project/screen/message/inbox_screen.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/service/notification_service.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/service/search_migration_service.dart';
import 'package:cs261_project/screen/admin/admin_participant_list_screen.dart';
import 'package:cs261_project/screen/admin/admin_reactivation_requests_screen.dart';
import 'package:cs261_project/screen/admin/admin_deletion_queue_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/settings_screen.dart';
import 'package:cs261_project/screen/settings/help_support_screen.dart';
import 'package:cs261_project/screen/settings/about_screen.dart';
import 'package:cs261_project/screen/admin/admin_feedback_screen.dart';

/// Admin shell: Console, Feed, Inbox and Profile tabs.
class AdminHomeScreen extends StatefulWidget {
  final String instituteId;
  const AdminHomeScreen({super.key, required this.instituteId});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  final List<bool> _hasBeenBuilt = List.filled(4, false);
  Stream<ParticipantModel?>? _profileStream;

  static const _titles = ['Admin Console', 'News & Events', 'Inbox', 'Profile'];

  @override
  void initState() {
    super.initState();
    _hasBeenBuilt[0] = true;
    final uid = _user?.uid;
    if (uid != null) {
      _profileStream = ProfileService(instituteId: widget.instituteId).getProfileStream(uid);
      NotificationService.instance.init(widget.instituteId);
    }
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _hasBeenBuilt[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Text(_titles[_currentIndex]),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context, theme),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _AdminConsole(instituteId: widget.instituteId, profileStream: _profileStream),
          _hasBeenBuilt[1] ? NewsEventScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[2] ? InboxScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[3] ? ProfileScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Console',
            ),
            NavigationDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed_rounded),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Inbox',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ThemeData theme) {
    final cs = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          StreamBuilder<ParticipantModel?>(
            stream: _profileStream,
            builder: (context, snap) {
              final profile = snap.data;
              final name = (profile?.name.isNotEmpty ?? false)
                  ? profile!.name
                  : (_user?.email?.split('@').first ?? 'Administrator');
              return Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, MediaQuery.of(context).padding.top + AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(name: name, imageUrl: profile?.profileImage, radius: 30, ring: true),
                    AppSpacing.gapMd,
                    Text(name, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_user?.email ?? '', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    const RoleBadge(role: 'admin', dense: true),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              children: [
                for (final (i, icon, label) in [
                  (0, Icons.space_dashboard_outlined, 'Console'),
                  (1, Icons.dynamic_feed_outlined, 'News & Events'),
                  (2, Icons.chat_bubble_outline_rounded, 'Inbox'),
                  (3, Icons.person_outline_rounded, 'My profile'),
                ])
                  _drawerItem(theme, icon, label, () {
                    _selectTab(i);
                    Navigator.pop(context);
                  }, selected: _currentIndex == i),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Divider(height: 1),
                ),
                _drawerItem(theme, Icons.person_add_alt_outlined, 'Add user', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAddParticipantScreen(instituteId: widget.instituteId)));
                }),
                _drawerItem(theme, Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(instituteId: widget.instituteId)));
                }),
                _drawerItem(theme, Icons.help_outline_rounded, 'Help & Support', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(instituteId: widget.instituteId)));
                }),
                _drawerItem(theme, Icons.info_outline_rounded, 'About', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _drawerItem(theme, Icons.logout_rounded, 'Log out', () async {
                await NotificationService.instance.unregister();
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }, color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(ThemeData theme, IconData icon, String title, VoidCallback onTap,
      {Color? color, bool selected = false}) {
    final cs = theme.colorScheme;
    final fg = color ?? (selected ? cs.primary : cs.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: cs.primaryContainer.withValues(alpha: 0.6),
        leading: Icon(icon, color: color ?? (selected ? cs.primary : cs.onSurfaceVariant)),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Console tab: institute summary, live counts and management actions.
class _AdminConsole extends StatefulWidget {
  final String instituteId;
  final Stream<ParticipantModel?>? profileStream;
  const _AdminConsole({required this.instituteId, this.profileStream});

  @override
  State<_AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<_AdminConsole> {
  late final DocumentReference _instituteRef;
  late final Future<DocumentSnapshot> _instituteFuture;
  late final Stream<QuerySnapshot> _membersStream;
  late final Stream<QuerySnapshot> _reactivationsStream;
  late final Stream<QuerySnapshot> _deletionsStream;
  late final Stream<QuerySnapshot> _feedbackStream;
  bool _isMigrating = false;

  @override
  void initState() {
    super.initState();
    _instituteRef = FirebaseFirestore.instance.collection('institutes').doc(widget.instituteId);
    _instituteFuture = _instituteRef.get();
    _membersStream = _instituteRef.collection('participants').snapshots();
    _reactivationsStream =
        _instituteRef.collection('reactivation_requests').where('status', isEqualTo: 'pending').snapshots();
    _deletionsStream =
        _instituteRef.collection('deletion_queue').where('status', isEqualTo: 'pending').snapshots();
    _feedbackStream = _instituteRef.collection('feedback').where('status', isEqualTo: 'open').snapshots();
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _runSearchMigration() async {
    setState(() => _isMigrating = true);
    try {
      await SearchMigrationService.migrateInstituteParticipants(widget.instituteId);
      if (mounted) AppSnackBar.showSuccess(context, 'Search index rebuilt for all members.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Rebuild failed: $e');
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _buildGreeting(theme),
        const SizedBox(height: 20),
        _buildInstituteCard(theme),
        const SizedBox(height: 16),
        _buildStatsRow(theme),
        const SizedBox(height: 28),
        const AppSectionHeader(title: 'People'),
        _countTile(
          theme,
          stream: null,
          icon: Icons.person_add_alt_1_outlined,
          title: 'Add user',
          subtitle: 'Create a student, alumni or admin account',
          onTap: () => _open(AdminAddParticipantScreen(instituteId: widget.instituteId)),
        ),
        const SizedBox(height: 10),
        _countTile(
          theme,
          stream: null,
          icon: Icons.manage_accounts_outlined,
          title: 'Manage users',
          subtitle: 'Deactivate, restore or permanently delete',
          onTap: () => _open(AdminParticipantListScreen(instituteId: widget.instituteId)),
        ),
        const SizedBox(height: 10),
        _countTile(
          theme,
          stream: _reactivationsStream,
          icon: Icons.how_to_reg_outlined,
          title: 'Reactivation requests',
          subtitle: 'Deactivated users asking to come back',
          onTap: () => _open(AdminReactivationRequestsScreen(instituteId: widget.instituteId)),
        ),
        const SizedBox(height: 10),
        _countTile(
          theme,
          stream: _deletionsStream,
          icon: Icons.auto_delete_outlined,
          title: 'Deletion queue',
          subtitle: 'Scheduled permanent deletions (24h grace)',
          onTap: () => _open(AdminDeletionQueueScreen(instituteId: widget.instituteId)),
          urgent: true,
        ),
        const SizedBox(height: 28),
        const AppSectionHeader(title: 'Institute'),
        _countTile(
          theme,
          stream: _feedbackStream,
          icon: Icons.feedback_outlined,
          title: 'Feedback reports',
          subtitle: 'Bugs and requests from members',
          onTap: () => _open(AdminFeedbackScreen(instituteId: widget.instituteId)),
        ),
        const SizedBox(height: 10),
        _countTile(
          theme,
          stream: null,
          icon: Icons.account_balance_outlined,
          title: 'Institutes',
          subtitle: 'All institutes on Alma Roots',
          onTap: () => _open(AdminInstituteListScreen(currentInstituteId: widget.instituteId)),
        ),
        const SizedBox(height: 10),
        _countTile(
          theme,
          stream: null,
          icon: Icons.manage_search_rounded,
          title: 'Rebuild search index',
          subtitle: 'Fix members who don\'t show up in search',
          onTap: _isMigrating ? null : _runSearchMigration,
          trailing: _isMigrating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
      ],
    );
  }

  Widget _buildGreeting(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<ParticipantModel?>(
      stream: widget.profileStream,
      builder: (context, snap) {
        final profile = snap.data;
        final name = (profile?.name.isNotEmpty ?? false)
            ? profile!.name.split(' ').first
            : (user?.email?.split('@').first ?? 'Admin');
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(name, style: theme.textTheme.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AppAvatar(name: name, imageUrl: profile?.profileImage, radius: 26, ring: true),
          ],
        );
      },
    );
  }

  Widget _buildInstituteCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.gold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: _instituteFuture,
                  builder: (context, snap) {
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final name = (data?['name'] as String?) ?? 'Your institute';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MANAGING',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.gold, letterSpacing: 1.4)),
                        const SizedBox(height: 2),
                        Text(name,
                            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _membersStream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int students = 0, alumni = 0, inactive = 0;
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final gone = m['isDeleted'] == true || (m['status'] != null && m['status'] != 'active');
          if (gone) {
            inactive++;
          } else if (m['role'] == 'alumni') {
            alumni++;
          } else if (m['role'] == 'student' || m['role'] == null) {
            students++;
          }
        }
        String v(int n) => snap.hasData ? '$n' : '–';
        return Row(
          children: [
            Expanded(child: _statCard(theme, v(students), 'Students', AppColors.sage)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(theme, v(alumni), 'Alumni', AppColors.goldDeep)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(theme, v(inactive), 'Inactive', AppColors.clay)),
          ],
        );
      },
    );
  }

  Widget _statCard(ThemeData theme, String value, String label, Color accent) {
    final cs = theme.colorScheme;
    final fg = theme.brightness == Brightness.dark ? Color.lerp(accent, Colors.white, 0.45)! : accent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: fg)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _countTile(
    ThemeData theme, {
    required Stream<QuerySnapshot>? stream,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool urgent = false,
    Widget? trailing,
  }) {
    final cs = theme.colorScheme;

    Widget badge(int count) {
      if (count == 0) return Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant);
      final color = urgent ? cs.error : AppColors.gold;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
        child: Text(
          '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            color: urgent ? cs.onError : AppColors.forestDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              (stream == null
                  ? Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant)
                  : StreamBuilder<QuerySnapshot>(
                      stream: stream,
                      builder: (context, snap) => badge(snap.data?.docs.length ?? 0),
                    )),
        ],
      ),
    );
  }
}
