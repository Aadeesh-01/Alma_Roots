import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/screen/admin/admin_permanent_delete_confirm_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AdminParticipantListScreen extends StatefulWidget {
  final String instituteId;

  const AdminParticipantListScreen({super.key, required this.instituteId});

  @override
  State<AdminParticipantListScreen> createState() => _AdminParticipantListScreenState();
}

class _AdminParticipantListScreenState extends State<AdminParticipantListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showDeleted = false;

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
    final textTheme = theme.textTheme;

    final action = user.isDeleted ? 'restore' : 'deactivate';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.isDeleted ? 'Restore' : 'Deactivate'} User?', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          user.isDeleted
              ? 'This will restore their access and make them visible in searches.'
              : 'This action will prevent them from logging in and hide them from searches. Type DELETE to confirm (optional for now).',
          style: textTheme.bodyLarge,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: user.isDeleted ? Colors.green : colorScheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(user.isDeleted ? 'Restore' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (user.isDeleted) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green, // Success
          content: Text('User successfully ${user.isDeleted ? 'restored' : 'deactivated'}.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Manage Participants'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
        actions: [
          Row(
            children: [
              Text('Show Deleted', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              Switch(
                value: _showDeleted,
                activeColor: colorScheme.primary,
                activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _showDeleted = val),
              ),
            ],
          )
        ],
      ),
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No participants found.", style: textTheme.bodyLarge));
          }

          final allUsers = snapshot.data!.docs
              .map((doc) => ParticipantModel.fromFirestore(doc))
              .where((u) => _showDeleted ? true : (!u.isDeleted && u.status != 'deleted'))
              .toList();

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: allUsers.length,
            separatorBuilder: (context, index) => AppSpacing.gapSm,
            itemBuilder: (context, index) {
              final user = allUsers[index];
              final isDeleted = user.isDeleted || user.status == 'deleted';
              final isPendingPermDelete = user.pendingPermanentDeletion;

              Color rowBgColor = colorScheme.surface;
              Color rowBorderColor = theme.dividerColor;
              
              if (isPendingPermDelete) {
                rowBgColor = colorScheme.error.withValues(alpha: 0.1);
                rowBorderColor = colorScheme.error.withValues(alpha: 0.3);
              } else if (isDeleted) {
                rowBgColor = colorScheme.error.withValues(alpha: 0.05);
                rowBorderColor = colorScheme.error.withValues(alpha: 0.2);
              }

              return Container(
                decoration: BoxDecoration(
                  color: rowBgColor,
                  border: Border.all(color: rowBorderColor),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  leading: CircleAvatar(
                    backgroundColor: isDeleted ? colorScheme.error.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(color: isDeleted ? colorScheme.error : colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    user.name.isEmpty ? "No Name" : user.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSpacing.gapXs,
                      Text(user.email, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                      AppSpacing.gapXs,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  trailing: user.role == 'admin'
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('ADMIN', style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDeleted && !isPendingPermDelete)
                              IconButton(
                                icon: Icon(Icons.delete_forever, color: colorScheme.error),
                                tooltip: 'Schedule Permanent Deletion',
                                onPressed: () => _showPermanentDeleteScreen(user),
                              ),
                            if (isPendingPermDelete)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.timer, color: colorScheme.error, size: 20),
                              ),
                            IconButton(
                              icon: Icon(
                                isDeleted ? Icons.restore : Icons.delete_outline,
                                color: isDeleted ? Colors.green : colorScheme.error,
                              ),
                              tooltip: isDeleted ? 'Restore User' : 'Soft Delete',
                              onPressed: () => _toggleUserStatus(theme, user),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
