import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_empty_state.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class AdminDeletionQueueScreen extends StatefulWidget {
  final String instituteId;

  const AdminDeletionQueueScreen({super.key, required this.instituteId});

  @override
  State<AdminDeletionQueueScreen> createState() => _AdminDeletionQueueScreenState();
}

class _AdminDeletionQueueScreenState extends State<AdminDeletionQueueScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // One shared ticker drives every countdown on the screen.
  final Stream<DateTime> _clock = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  Future<void> _cancelDeletion(ThemeData theme, String targetUid, String targetEmail, String queueDocId) async {
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.restore_rounded, color: colorScheme.primary),
        title: const Text('Cancel permanent deletion?'),
        content: Text('$targetEmail is removed from the queue and stays deactivated. You can restore them from Manage users.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep scheduled')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel deletion'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AdminService.cancelPermanentDeletion(
        instituteId: widget.instituteId,
        targetUid: targetUid,
        targetEmail: targetEmail,
        queueDocId: queueDocId,
      );

      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'Permanent deletion cancelled.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Could not cancel: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _processQueue({String? targetUid, String? label}) async {
    final theme = Theme.of(context);
    final isSingle = targetUid != null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        title: Text(isSingle ? 'Delete ${label ?? 'this user'} now?' : 'Process the whole queue?'),
        content: Text(
          isSingle
            ? 'This skips the remaining grace period and permanently deletes the account right away. This cannot be undone.'
            : 'Every user whose 24-hour grace period has ended is permanently deleted now. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await AdminService.processDeletionQueue(
        instituteId: widget.instituteId,
        targetUid: targetUid,
      );

      if (!mounted) return;
      Navigator.pop(context); // pop loading

      final processed = result['processed'] ?? 0;
      final failed = result['failed'] ?? 0;
      final deletedUsers = (result['deletedUsers'] as List?)?.cast<String>() ?? [];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            failed > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: failed > 0 ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          title: Text(processed == 0 && failed == 0 ? 'Nothing to process' : 'Done'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deleted: $processed', style: theme.textTheme.titleSmall),
              if (failed > 0)
                Text('Failed: $failed', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
              if (processed == 0 && failed == 0)
                const Text('No entries have finished their grace period yet.'),
              if (deletedUsers.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...deletedUsers.map((e) => Text('• $e')),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // pop loading
      AppSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _formatRemainingTime(DateTime scheduledFor, DateTime now) {
    final diff = scheduledFor.difference(now);
    if (diff.isNegative) return "Overdue · runs within 5 minutes";
    if (diff.inHours > 0) return "${diff.inHours}h ${diff.inMinutes.remainder(60)}m left";
    return "${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s left";
  }

  Widget _buildInfoBanner(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: cs.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Accounts are deleted automatically 24 hours after scheduling. Cancel here to keep someone, or use Delete now to skip the wait.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deletion queue'),
        actions: [
          TextButton.icon(
            onPressed: () => _processQueue(),
            icon: const Icon(Icons.playlist_remove_rounded),
            label: const Text('Process due'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('institutes')
            .doc(widget.instituteId)
            .collection('deletion_queue')
            .where('status', isEqualTo: 'pending')
            .orderBy('scheduledFor', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading queue.", style: TextStyle(color: colorScheme.error)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Queue is empty',
              message: 'No accounts are scheduled for permanent deletion.',
            );
          }

          final queueItems = snapshot.data!.docs.where((d) {
            return (d.data() as Map<String, dynamic>)['scheduledFor'] is Timestamp;
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: queueItems.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) return _buildInfoBanner(theme);
              final doc = queueItems[index - 1];
              final item = doc.data() as Map<String, dynamic>;
              final targetUid = item['uid'] ?? doc.id;
              final email = (item['email'] as String?) ?? 'Unknown email';
              final scheduledFor = (item['scheduledFor'] as Timestamp).toDate();
              final requestedAt = (item['requestedAt'] as Timestamp?)?.toDate() ??
                  scheduledFor.subtract(const Duration(hours: 24));
              final dateStr = DateFormat('d MMM yyyy, h:mm a').format(scheduledFor);
              final total = scheduledFor.difference(requestedAt).inSeconds.clamp(1, 1 << 31);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          AppAvatar(name: email, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('Deletes on $dateStr', style: textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      StreamBuilder<DateTime>(
                        stream: _clock,
                        builder: (context, snap) {
                          final now = snap.data ?? DateTime.now();
                          final overdue = scheduledFor.isBefore(now);
                          final elapsed = now.difference(requestedAt).inSeconds;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(overdue ? Icons.hourglass_bottom_rounded : Icons.timer_outlined,
                                      size: 16, color: colorScheme.error),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatRemainingTime(scheduledFor, now),
                                    style: textTheme.labelLarge?.copyWith(color: colorScheme.error),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: LinearProgressIndicator(
                                  value: (elapsed / total).clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: colorScheme.surfaceContainerHigh,
                                  valueColor: AlwaysStoppedAnimation(colorScheme.error),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cancelDeletion(theme, targetUid, email, doc.id),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _processQueue(targetUid: targetUid, label: email),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                              ),
                              child: const Text('Delete now'),
                            ),
                          ),
                        ],
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
