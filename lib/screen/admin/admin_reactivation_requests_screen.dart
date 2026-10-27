import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_empty_state.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class AdminReactivationRequestsScreen extends StatefulWidget {
  final String instituteId;

  const AdminReactivationRequestsScreen({super.key, required this.instituteId});

  @override
  State<AdminReactivationRequestsScreen> createState() => _AdminReactivationRequestsScreenState();
}

class _AdminReactivationRequestsScreenState extends State<AdminReactivationRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _handleRequest(ThemeData theme, String requestId, String targetUid, String name, bool approve) async {
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          approve ? Icons.how_to_reg_rounded : Icons.do_not_disturb_on_outlined,
          color: approve ? colorScheme.primary : colorScheme.error,
        ),
        title: Text(approve ? 'Reactivate $name?' : 'Reject request?'),
        content: Text(
          approve
              ? 'Their account is restored: they can log in and appear in search again. Any scheduled permanent deletion is cancelled.'
              : 'The request is rejected and $name stays deactivated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: approve ? colorScheme.primary : colorScheme.error,
              foregroundColor: approve ? colorScheme.onPrimary : colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject'),
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
      AppSnackBar.showSuccess(context, approve ? '$name has been reactivated.' : 'Request rejected.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reactivation requests')),
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
            return const AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No pending requests',
              message: 'When a deactivated user asks to come back, their request appears here.',
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              final targetUid = req['userUid'] ?? requestId;
              final email = (req['userEmail'] as String?) ?? '';
              final rawName = (req['userName'] as String?)?.trim() ?? '';
              final name = rawName.isNotEmpty && rawName != 'Unknown'
                  ? rawName
                  : (email.isNotEmpty ? email.split('@').first : 'Member');
              final timestamp = req['requestedAt'] as Timestamp?;
              final dateStr = timestamp != null
                  ? DateFormat('d MMM yyyy, h:mm a').format(timestamp.toDate())
                  : 'Unknown date';

              return AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AppAvatar(name: name, radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: textTheme.titleSmall),
                              if (email.isNotEmpty) Text(email, style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Requested $dateStr', style: textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleRequest(theme, requestId, targetUid, name, false),
                            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _handleRequest(theme, requestId, targetUid, name, true),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
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
