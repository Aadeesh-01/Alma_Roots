import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/theme/app_spacing.dart';
class MainHomeScreen extends StatefulWidget {
  final String instituteId;
  const MainHomeScreen({super.key, required this.instituteId});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileSummary(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.gapLg,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummary() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final name = _user?.displayName ?? 'Alumni Member';
    final email = _user?.email ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cover Banner
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primaryContainer, colorScheme.primary.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.md)),
            ),
          ),
          // Avatar & Info
          Container(
            transform: Matrix4.translationValues(0.0, -32.0, 0.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                    child: _user?.photoURL == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.primary),
                          )
                        : null,
                  ),
                ),
                AppSpacing.gapSm,
                Text(
                  name,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.gapXs,
                Text(
                  "Professional Network",
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                if (email.isNotEmpty) ...[
                  AppSpacing.gapXs,
                  Text(
                    email,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
