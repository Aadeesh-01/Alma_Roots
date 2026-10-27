import 'package:cs261_project/screen/events_and_news/news_event_screen.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/screen/message/inbox_screen.dart';
import 'package:cs261_project/screen/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/screen/main_home_screen.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/settings_screen.dart';
import 'package:cs261_project/screen/settings/help_support_screen.dart';
import 'package:cs261_project/screen/settings/about_screen.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';

class UserHomeScreen extends StatefulWidget {
  final String instituteId;
  const UserHomeScreen({super.key, required this.instituteId});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  final List<bool> _hasBeenBuilt = List.filled(5, false);
  Stream<ParticipantModel?>? _profileStream;

  static const _titles = ['Alma Roots', 'Network', 'News & Events', 'Profile', 'Inbox'];

  @override
  void initState() {
    super.initState();
    _hasBeenBuilt[0] = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _profileStream = ProfileService(instituteId: widget.instituteId).getProfileStream(uid);
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
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return Scaffold(
        body: Center(child: Text("User not found.", style: theme.textTheme.bodyLarge)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: _currentIndex == 0
            ? Row(
                children: [
                  ClipOval(
                    child: Image.asset('assets/images/logo.png', width: 30, height: 30, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Text(_titles[0]),
                ],
              )
            : Text(_titles[_currentIndex]),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context, user),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _hasBeenBuilt[0] ? MainHomeScreen(instituteId: widget.instituteId, onNavigate: _selectTab) : const SizedBox.shrink(),
          _hasBeenBuilt[1] ? SearchScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[2] ? NewsEventScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[3] ? ProfileScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[4] ? InboxScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
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
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Network',
            ),
            NavigationDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed_rounded),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Inbox',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, User user) {
    final theme = Theme.of(context);
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
                  : (user.email?.split('@').first ?? 'Member');
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
                    Text(user.email ?? '', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (profile != null) ...[
                      const SizedBox(height: 10),
                      RoleBadge(role: profile.role, dense: true),
                    ],
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              children: [
                _buildDrawerItem(Icons.home_outlined, "Home", () {
                  _selectTab(0);
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 0),
                _buildDrawerItem(Icons.people_outline_rounded, "Find people", () {
                  _selectTab(1);
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 1),
                _buildDrawerItem(Icons.dynamic_feed_outlined, "News & Events", () {
                  _selectTab(2);
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 2),
                _buildDrawerItem(Icons.person_outline_rounded, "My profile", () {
                  _selectTab(3);
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 3),
                _buildDrawerItem(Icons.chat_bubble_outline_rounded, "Inbox", () {
                  _selectTab(4);
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Divider(height: 1),
                ),
                _buildDrawerItem(Icons.settings_outlined, "Settings", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(instituteId: widget.instituteId)));
                }),
                _buildDrawerItem(Icons.help_outline_rounded, "Help & Support", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(instituteId: widget.instituteId)));
                }),
                _buildDrawerItem(Icons.info_outline_rounded, "About", () {
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
              child: _buildDrawerItem(Icons.logout_rounded, "Log out", () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }, color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color? color, bool isSelected = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = color ?? (isSelected ? cs.primary : cs.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: cs.primaryContainer.withValues(alpha: 0.6),
        leading: Icon(icon, color: color ?? (isSelected ? cs.primary : cs.onSurfaceVariant)),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: fg,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
