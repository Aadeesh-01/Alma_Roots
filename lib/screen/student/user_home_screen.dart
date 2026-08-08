import 'package:cs261_project/screen/events_and_news/news_event_screen.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/screen/message/inbox_screen.dart';
import 'package:cs261_project/screen/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/screen/main_home_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/settings_screen.dart';
import 'package:cs261_project/screen/settings/help_support_screen.dart';
import 'package:cs261_project/screen/settings/about_screen.dart';

class UserHomeScreen extends StatefulWidget {
  final String instituteId;
  const UserHomeScreen({super.key, required this.instituteId});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  final List<bool> _hasBeenBuilt = List.filled(5, false);

  @override
  void initState() {
    super.initState();
    _hasBeenBuilt[0] = true;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (user == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(child: Text("User not found.", style: textTheme.bodyLarge)),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _getPageTitle(),
          style: textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildModernDrawer(context, user),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _hasBeenBuilt[0] ? MainHomeScreen(instituteId: widget.instituteId) : const SizedBox.shrink(),
          _hasBeenBuilt[1] ? SearchScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[2] ? NewsEventScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[3] ? ProfileScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
          _hasBeenBuilt[4] ? InboxScreen(instituteId: widget.instituteId, isNested: true) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
          _hasBeenBuilt[index] = true;
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.article_outlined),
          selectedIcon: Icon(Icons.article),
          label: 'News',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.question_answer_outlined),
          selectedIcon: Icon(Icons.question_answer),
          label: 'Inbox',
        ),
      ],
    );
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Alma Roots';
      case 1:
        return 'Network';
      case 2:
        return 'News & Events';
      case 3:
        return 'Profile';
      case 4:
        return 'Inbox';
      default:
        return 'Alma Roots';
    }
  }

  Widget _buildModernDrawer(BuildContext context, User user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: const Color(0x00000000),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 60, AppSpacing.xl, AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.5),
                  colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Icon(Icons.person, size: 32, color: colorScheme.primary)
                      : null,
                ),
                AppSpacing.gapMd,
                Text(user.displayName ?? "Alumni Member", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                AppSpacing.gapXs,
                Text(user.email ?? "user@email.com", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                _buildDrawerItem(Icons.home_outlined, "Home", () {
                  setState(() {
                    _currentIndex = 0;
                    _hasBeenBuilt[0] = true;
                  });
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 0),
                _buildDrawerItem(Icons.search_outlined, "Search Alumni", () {
                  setState(() {
                    _currentIndex = 1;
                    _hasBeenBuilt[1] = true;
                  });
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 1),
                _buildDrawerItem(Icons.article_outlined, "News & Events", () {
                  setState(() {
                    _currentIndex = 2;
                    _hasBeenBuilt[2] = true;
                  });
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 2),
                _buildDrawerItem(Icons.person_outline, "My Profile", () {
                  setState(() {
                    _currentIndex = 3;
                    _hasBeenBuilt[3] = true;
                  });
                  Navigator.pop(context);
                }, isSelected: _currentIndex == 3),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Divider(),
                ),
                _buildDrawerItem(Icons.settings_outlined, "Settings", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(instituteId: widget.instituteId)));
                }),
                _buildDrawerItem(Icons.help_outline, "Help & Support", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(instituteId: widget.instituteId)));
                }),
                _buildDrawerItem(Icons.info_outline, "About", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                }),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: _buildDrawerItem(Icons.logout, "Logout", () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }, textColor: colorScheme.error, iconColor: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color? textColor, Color? iconColor, bool isSelected = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
        selected: isSelected,
        selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
        leading: Icon(icon, color: iconColor ?? (isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant)),
        title: Text(title,
            style: textTheme.bodyLarge?.copyWith(
                color: textColor ?? (isSelected ? colorScheme.primary : colorScheme.onSurface),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        onTap: onTap,
      ),
    );
  }
}
