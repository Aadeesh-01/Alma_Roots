import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/widget/app_empty_state.dart';
import 'package:cs261_project/widget/app_section.dart';

/// Read-only list of institutes. Creating or deleting institutes is restricted
/// to platform super admins by firestore.rules, so it is not offered here.
class AdminInstituteListScreen extends StatelessWidget {
  /// The signed-in admin's institute, highlighted in the list.
  final String? currentInstituteId;

  const AdminInstituteListScreen({super.key, this.currentInstituteId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Institutes')),
      body: StreamBuilder<QuerySnapshot>(
        // No orderBy: institutes without a createdAt field would be dropped by the query.
        stream: FirebaseFirestore.instance.collection('institutes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading institutes.', style: TextStyle(color: colorScheme.error)));
          }

          final institutes = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              if (a.id == currentInstituteId) return -1;
              if (b.id == currentInstituteId) return 1;
              final an = ((a.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
              final bn = ((b.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
              return an.compareTo(bn);
            });

          if (institutes.isEmpty) {
            return const AppEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No institutes yet',
              message: 'Institutes are created by the platform administrator.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: institutes.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${institutes.length} institute${institutes.length == 1 ? '' : 's'} on Alma Roots. '
                          'New institutes are added by the platform administrator.',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final doc = institutes[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] as String : 'Unnamed institute';
              final isMine = doc.id == currentInstituteId;

              return AppSurfaceCard(
                color: isMine ? colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isMine ? colorScheme.primary : colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.account_balance_rounded,
                        color: isMine ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text('ID: ${doc.id}', style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (isMine)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('Yours', style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimary)),
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
