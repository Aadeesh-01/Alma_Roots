import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class AdminReactivationRequestsScreen extends StatefulWidget {
  final String instituteId;

  const AdminReactivationRequestsScreen({super.key, required this.instituteId});

  @override
  State<AdminReactivationRequestsScreen> createState() => _AdminReactivationRequestsScreenState();
}

class _AdminReactivationRequestsScreenState extends State<AdminReactivationRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _handleRequest(ThemeData theme, String requestId, String targetUid, bool approve) async {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final action = approve ? 'Approve' : 'Reject';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Request?', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          approve
              ? 'This will restore the user\'s account, allowing them to log in and appear in searches.'
              : 'This will reject the reactivation request. The user will remain deactivated.',
          style: textTheme.bodyLarge,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (approve) {
        await AdminService.approveReactivation(
          instituteId: widget.instituteId,
          requestId: requestId,
          targetUid: targetUid,
        );
      } else {
        await AdminService.rejectReactivation(
          instituteId: widget.instituteId,
          requestId: requestId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green, // Success
          content: Text('Request successfully ${approve ? 'approved' : 'rejected'}.'),
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
        title: const Text('Reactivation Requests'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('institutes')
            .doc(widget.instituteId)
            .collection('reactivation_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading requests.", style: TextStyle(color: colorScheme.error)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No pending reactivation requests.", style: textTheme.bodyLarge));
          }

          final requests = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: requests.length,
            separatorBuilder: (context, index) => AppSpacing.gapMd,
            itemBuilder: (context, index) {
              final req = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              final targetUid = req['userUid'] ?? requestId;
              final name = req['userName'] ?? 'Unknown';
              final email = req['userEmail'] ?? 'Unknown Email';
              final timestamp = req['requestedAt'] as Timestamp?;
              final dateStr = timestamp != null
                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())
                  : 'Unknown Date';

              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: theme.dividerColor),
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
                            name,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57C00).withValues(alpha: 0.1), // Warning orange
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.5)),
                          ),
                          child: Text('Pending', style: textTheme.bodySmall?.copyWith(color: const Color(0xFFF57C00), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    AppSpacing.gapXs,
                    Text(email, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    AppSpacing.gapSm,
                    Text('Requested: $dateStr', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    AppSpacing.gapLg,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _handleRequest(theme, requestId, targetUid, false),
                          style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error, side: BorderSide(color: colorScheme.error)),
                          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        AppSpacing.gapSm,
                        ElevatedButton(
                          onPressed: () => _handleRequest(theme, requestId, targetUid, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
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
