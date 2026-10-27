import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AdminDeletionQueueScreen extends StatefulWidget {
  final String instituteId;

  const AdminDeletionQueueScreen({super.key, required this.instituteId});

  @override
  State<AdminDeletionQueueScreen> createState() => _AdminDeletionQueueScreenState();
}

class _AdminDeletionQueueScreenState extends State<AdminDeletionQueueScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _cancelDeletion(ThemeData theme, String targetUid, String targetEmail, String queueDocId) async {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Permanent Deletion?', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        content: Text('This will remove the user from the permanent deletion queue. They will remain soft-deleted.', style: textTheme.bodyLarge),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No', style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green, // Success
          content: Text('Permanent deletion cancelled successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Could not cancel: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    }
  }

  Future<void> _processQueue({String? targetUid}) async {
    final theme = Theme.of(context);
    final isSingle = targetUid != null;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSingle ? 'Process Permanent Deletion Now?' : 'Process Entire Queue?'),
        content: Text(
          isSingle 
            ? 'This will bypass the 24-hour waiting period and permanently delete this user immediately.' 
            : 'This will permanently delete all eligible users in the queue whose 24-hour waiting period has expired.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Process', style: TextStyle(fontWeight: FontWeight.bold)),
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
          title: const Text('Processing Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Processed successfully: $processed', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              if (failed > 0) Text('Failed: $failed', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.error)),
              const SizedBox(height: AppSpacing.md),
              if (deletedUsers.isNotEmpty) ...[
                const Text('Deleted Users:'),
                const SizedBox(height: AppSpacing.sm),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: theme.colorScheme.error, content: Text('Error: $e')),
      );
    }
  }

  String _formatRemainingTime(DateTime scheduledFor) {
    final now = DateTime.now();
    final diff = scheduledFor.difference(now);
    if (diff.isNegative) return "Executing soon...";
    if (diff.inHours > 0) return "${diff.inHours}h ${diff.inMinutes.remainder(60)}m";
    return "${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Pending Deletions'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
        actions: [
          TextButton.icon(
            onPressed: () => _processQueue(),
            icon: Icon(Icons.cleaning_services, color: colorScheme.primary),
            label: Text('Process Queue', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
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
            return Center(child: Text("No users in deletion queue.", style: textTheme.bodyLarge));
          }

          final queueItems = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: queueItems.length,
            separatorBuilder: (context, index) => AppSpacing.gapMd,
            itemBuilder: (context, index) {
              final item = queueItems[index].data() as Map<String, dynamic>;
              final targetUid = item['uid'] ?? queueItems[index].id;
              final email = item['email'] ?? 'Unknown Email';
              final scheduledForTs = item['scheduledFor'] as Timestamp?;
              
              if (scheduledForTs == null) return const SizedBox.shrink();
              
              final scheduledFor = scheduledForTs.toDate();
              final dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(scheduledFor);

              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.05),
                  border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            email,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
                          ),
                          child: Text('Pending', style: textTheme.bodySmall?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
                        AppSpacing.gapSm,
                        Text('Scheduled: $dateStr', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: colorScheme.error),
                        AppSpacing.gapSm,
                        // Use StreamBuilder for countdown timer
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, _) {
                            return Text(
                              'Time Remaining: ${_formatRemainingTime(scheduledFor)}',
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
                            );
                          }
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _cancelDeletion(theme, targetUid, email, queueItems[index].id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: theme.dividerColor),
                          ),
                          child: const Text('Cancel Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        AppSpacing.gapSm,
                        ElevatedButton(
                          onPressed: () => _processQueue(targetUid: targetUid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                          ),
                          child: const Text('Process Now', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
