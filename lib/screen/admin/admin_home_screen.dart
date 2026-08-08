import 'package:cs261_project/screen/admin/admin_add_user_screen.dart';
import 'package:cs261_project/screen/admin/admin_institute_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cs261_project/service/search_migration_service.dart';
import 'package:cs261_project/screen/admin/admin_participant_list_screen.dart';
import 'package:cs261_project/screen/admin/admin_reactivation_requests_screen.dart';
import 'package:cs261_project/screen/admin/admin_deletion_queue_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/settings_screen.dart';
import 'package:cs261_project/screen/admin/admin_feedback_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final String instituteId;
  const AdminHomeScreen({super.key, required this.instituteId});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  // Local cache for metrics (mocked per prompt constraint "fetch once, cache locally")

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: colorScheme.surface,
        shadowColor: theme.dividerColor,
        foregroundColor: colorScheme.onSurface,
        title: Text(
          "Admin Console",
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context, theme),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstituteSummary(theme),
            AppSpacing.gapXXl,
            Text("Management Actions", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapLg,
            _buildActionsGrid(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInstituteSummary(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child:
                Icon(Icons.business, color: colorScheme.onPrimary, size: 32),
          ),
          AppSpacing.gapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Institute Management",
                  style: textTheme.headlineMedium?.copyWith(color: colorScheme.onPrimary),
                ),
                AppSpacing.gapXs,
                Text(
                  "ID: ${widget.instituteId}",
                  style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.5,
      children: [
        _buildActionTile(theme,
            "Add User", Icons.person_add, const AdminAddParticipantScreen()),
        _buildActionTile(theme, "Manage Users", Icons.people,
            AdminParticipantListScreen(instituteId: widget.instituteId)),
        _buildActionTile(theme, "Reactivations", Icons.how_to_reg,
            AdminReactivationRequestsScreen(instituteId: widget.instituteId)),
        _buildActionTile(theme, "Deletion Queue", Icons.delete_sweep,
            AdminDeletionQueueScreen(instituteId: widget.instituteId)),
        _buildActionTile(theme, "View Institutes", Icons.account_balance,
            const AdminInstituteListScreen()),
        _buildActionTile(theme, "Feedback Reports", Icons.feedback_outlined,
            AdminFeedbackScreen(instituteId: widget.instituteId)),
        _buildSearchActionTile(theme),
      ],
    );
  }

  Widget _buildActionTile(ThemeData theme, String title, IconData icon, Widget screen) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchActionTile(ThemeData theme) {
    return InkWell(
      onTap: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting search migration...')),
        );
        try {
          await SearchMigrationService.migrateInstituteParticipants(
              widget.instituteId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Search migration completed successfully!'),
                backgroundColor: Colors.green, // Success
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Migration failed: $e'),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.build_circle, color: theme.colorScheme.primary, size: 20),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                "Fix Search Index",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 60, AppSpacing.xl, AppSpacing.xl),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_user?.photoURL != null)
                  CachedNetworkImage(
                    imageUrl: _user!.photoURL!,
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                      backgroundImage: imageProvider,
                    ),
                    placeholder: (context, url) => CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colorScheme.primary),
                      ),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.admin_panel_settings_rounded,
                          size: 32, color: colorScheme.primary),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.admin_panel_settings_rounded,
                        size: 32, color: colorScheme.primary),
                  ),
                AppSpacing.gapMd,
                Text(_user?.displayName ?? "Administrator",
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                AppSpacing.gapXs,
                Text(_user?.email ?? "",
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.sm)),
                    leading: Icon(Icons.person_add_rounded,
                        color: colorScheme.onSurfaceVariant),
                    title: Text('Add Participant',
                        style: textTheme.bodyLarge),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminAddParticipantScreen()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.sm)),
                    leading: Icon(Icons.settings_outlined,
                        color: colorScheme.onSurfaceVariant),
                    title: Text('Settings',
                        style: textTheme.bodyLarge),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SettingsScreen(instituteId: widget.instituteId)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm)),
                  leading:
                      Icon(Icons.logout_rounded, color: colorScheme.error),
                  title: Text('Logout',
                      style:
                          textTheme.bodyLarge?.copyWith(color: colorScheme.error)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
