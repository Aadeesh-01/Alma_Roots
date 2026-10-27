import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/screen/admin/admin_permanent_delete_confirm_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class AdminParticipantListScreen extends StatefulWidget {
  final String instituteId;

  const AdminParticipantListScreen({super.key, required this.instituteId});

  @override
  State<AdminParticipantListScreen> createState() => _AdminParticipantListScreenState();
}

class _AdminParticipantListScreenState extends State<AdminParticipantListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _filters = ['All', 'Students', 'Alumni', 'Admins', 'Inactive'];
  String _filter = 'All';
  String _query = '';

  void _showPermanentDeleteScreen(ParticipantModel user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPermanentDeleteConfirmScreen(
          instituteId: widget.instituteId,
          user: user,
        ),
      ),
    );

    if (result == true) {
      // The screen will handle the scheduling and showing snackbars.
      // We don't need to do anything here except let the stream rebuild.
    }
  }

  Future<void> _toggleUserStatus(ThemeData theme, ParticipantModel user) async {
    final colorScheme = theme.colorScheme;
    final restoring = user.isDeleted || user.status == 'deleted';
    final name = user.name.isEmpty ? user.email : user.name;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          restoring ? Icons.settings_backup_restore_rounded : Icons.person_off_outlined,
          color: restoring ? colorScheme.primary : colorScheme.error,
        ),
        title: Text(restoring ? 'Restore $name?' : 'Deactivate $name?'),
        content: Text(
          restoring
              ? 'They can log in again and will show up in search. Any scheduled permanent deletion is cancelled.'
              : 'They will be signed out of the app, hidden from search, and unable to log in until restored.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: restoring ? colorScheme.primary : colorScheme.error,
              foregroundColor: restoring ? colorScheme.onPrimary : colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(restoring ? 'Restore' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (restoring) {
        await AdminService.restoreUser(
          instituteId: widget.instituteId,
          targetUid: user.uid,
          targetEmail: user.email,
        );
      } else {
        await AdminService.softDeleteUser(
          instituteId: widget.instituteId,
          targetUid: user.uid,
          targetEmail: user.email,
        );
      }
      if (!mounted) return;
      AppSnackBar.showSuccess(context, restoring ? '$name restored.' : '$name deactivated.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  bool _isInactive(ParticipantModel u) => u.isDeleted || u.status != 'active';

  bool _matchesFilter(ParticipantModel u, String filter) {
    switch (filter) {
      case 'Students':
        return !_isInactive(u) && u.role == 'student';
      case 'Alumni':
        return !_isInactive(u) && u.role == 'alumni';
      case 'Admins':
        return !_isInactive(u) && u.role == 'admin';
      case 'Inactive':
        return _isInactive(u);
      default:
        return !_isInactive(u);
    }
  }

  Widget _statusChip(ThemeData theme, String label, Color color, IconData icon) {
    final fg = theme.brightness == Brightness.dark ? Color.lerp(color, Colors.white, 0.45)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }

  Widget _buildUserRow(ThemeData theme, ParticipantModel user) {
    final cs = theme.colorScheme;
    final text = theme.textTheme;
    final tombstone = user.status == 'permanently_deleted';
    final deactivated = !tombstone && (user.isDeleted || user.status == 'deleted');
    final pendingPerm = user.pendingPermanentDeletion && !tombstone;
    final name = user.name.isEmpty ? (user.email.isEmpty ? 'No name' : user.email.split('@').first) : user.name;
    final isSelf = user.uid == FirebaseAuth.instance.currentUser?.uid;

    return Opacity(
      opacity: tombstone ? 0.6 : 1,
      child: AppSurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            AppAvatar(name: name, imageUrl: tombstone ? null : user.profileImage, radius: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Text('(you)', style: text.bodySmall),
                      ],
                    ],
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(user.email, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (!tombstone) RoleBadge(role: user.role, dense: true),
                      if (tombstone) _statusChip(theme, 'Permanently deleted', cs.onSurfaceVariant, Icons.delete_forever_outlined),
                      if (deactivated && !pendingPerm) _statusChip(theme, 'Deactivated', AppColors.clay, Icons.block_rounded),
                      if (pendingPerm) _statusChip(theme, 'Deletion scheduled', cs.error, Icons.timer_outlined),
                    ],
                  ),
                ],
              ),
            ),
            if (!tombstone && user.role != 'admin')
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                onSelected: (v) {
                  if (v == 'toggle') _toggleUserStatus(theme, user);
                  if (v == 'permanent') _showPermanentDeleteScreen(user);
                  if (v == 'profile') {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(instituteId: widget.instituteId, viewUid: user.uid),
                    ));
                  }
                },
                itemBuilder: (context) => [
                  if (!deactivated)
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(leading: Icon(Icons.person_outline_rounded), title: Text('View profile'), contentPadding: EdgeInsets.zero),
                    ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        deactivated ? Icons.settings_backup_restore_rounded : Icons.person_off_outlined,
                        color: deactivated ? cs.primary : AppColors.clay,
                      ),
                      title: Text(deactivated ? 'Restore' : 'Deactivate'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (deactivated && !pendingPerm)
                    PopupMenuItem(
                      value: 'permanent',
                      child: ListTile(
                        leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                        title: Text('Delete permanently…', style: TextStyle(color: cs.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('institutes')
            .doc(widget.instituteId)
            .collection('participants')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final everyone = (snapshot.data?.docs ?? [])
              .map((doc) => ParticipantModel.fromFirestore(doc))
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          final counts = {
            for (final f in _filters) f: everyone.where((u) => _matchesFilter(u, f)).length,
          };

          final q = _query.toLowerCase();
          final visible = everyone.where((u) {
            if (!_matchesFilter(u, _filter)) return false;
            if (q.isEmpty) return true;
            return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _filters[i];
                    return ChoiceChip(
                      label: Text('$f  ${counts[f]}'),
                      selected: _filter == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = f),
                    );
                  },
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_off_outlined, size: 40, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text(
                              q.isNotEmpty ? 'No one matches "$_query"' : 'No users here',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildUserRow(theme, visible[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
