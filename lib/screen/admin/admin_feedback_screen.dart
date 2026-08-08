import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/service/feedback_service.dart';
import 'package:intl/intl.dart';

class AdminFeedbackScreen extends StatefulWidget {
  final String instituteId;
  const AdminFeedbackScreen({super.key, required this.instituteId});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  String _statusFilter = 'All';
  String _categoryFilter = 'All';

  final List<String> _statuses = [
    'All',
    'open',
    'investigating',
    'resolved',
    'closed'
  ];
  final List<String> _categories = [
    'All',
    'Bug',
    'UI Issue',
    'Feature Request',
    'Performance Issue',
    'Security Concern',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Feedback Reports'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
      ),
      body: Column(
        children: [
          _buildFilters(theme),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(child: _buildReportList(theme)),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              theme,
              'Status',
              _statusFilter,
              _statuses,
              (val) => setState(() => _statusFilter = val!),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: _buildDropdown(
              theme,
              'Category',
              _categoryFilter,
              _categories,
              (val) => setState(() => _categoryFilter = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(ThemeData theme, String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(
              value: e, child: Text(e, style: theme.textTheme.bodyMedium)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildReportList(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FeedbackService.getFeedbackStream(widget.instituteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: colorScheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading reports: ${snapshot.error}',
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.error)));
        }

        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final matchesStatus =
              _statusFilter == 'All' || data['status'] == _statusFilter;
          final matchesCategory =
              _categoryFilter == 'All' || data['category'] == _categoryFilter;
          return matchesStatus && matchesCategory;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: theme.dividerColor),
                AppSpacing.gapMd,
                Text('No feedback reports found.',
                    style: textTheme.titleMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => AppSpacing.gapMd,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final id = filteredDocs[index].id;
            return _buildReportCard(theme, id, data);
          },
        );
      },
    );
  }

  Widget _buildReportCard(ThemeData theme, String id, Map<String, dynamic> data) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final status = data['status'] as String? ?? 'open';
    final category = data['category'] as String? ?? 'Bug';
    final title = data['title'] as String? ?? 'No Title';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat.yMMMd().add_Hm().format(createdAt.toDate())
        : 'Unknown Date';

    Color statusColor;
    switch (status) {
      case 'open':
        statusColor = colorScheme.error;
        break;
      case 'investigating':
        statusColor = const Color(0xFFF57C00); // Orange
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'closed':
        statusColor = colorScheme.onSurfaceVariant;
        break;
      default:
        statusColor = colorScheme.primary;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: BorderSide(color: theme.dividerColor),
      ),
      color: colorScheme.surface,
      child: InkWell(
        onTap: () => _showReportDetails(context, theme, id, data, statusColor),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(category,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(status.toUpperCase(),
                        style: textTheme.bodySmall?.copyWith(
                            color: statusColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              AppSpacing.gapSm,
              Text(title,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              AppSpacing.gapXs,
              Row(
                children: [
                  Icon(Icons.person,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text("UID: ${data['uid'] ?? 'Unknown'}",
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(dateStr,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetails(BuildContext context, ThemeData theme, String id,
      Map<String, dynamic> data, Color statusColor) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpacing.lg))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2))),
                ),
                AppSpacing.gapLg,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child:
                            Text(data['title'] ?? '', style: textTheme.headlineMedium)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                AppSpacing.gapMd,
                _buildDetailSection(theme, "Description", data['description']),
                _buildDetailSection(
                    theme, "Steps to Reproduce", data['stepsToReproduce']),
                _buildDetailSection(theme, "Expected Result", data['expectedResult']),
                _buildDetailSection(theme, "Actual Result", data['actualResult']),
                if (data['screenshotUrl'] != null &&
                    data['screenshotUrl'].toString().isNotEmpty)
                  _buildDetailSection(theme, "Screenshot URL", data['screenshotUrl']),
                if (data['deviceInfo'] != null &&
                    data['deviceInfo'].toString().isNotEmpty)
                  _buildDetailSection(theme, "Device Info", data['deviceInfo']),
                AppSpacing.gapXl,
                Text("Update Status", style: textTheme.titleMedium),
                AppSpacing.gapSm,
                Wrap(
                  spacing: 8,
                  children:
                      ['open', 'investigating', 'resolved', 'closed'].map((s) {
                    final isSelected = data['status'] == s;
                    return ChoiceChip(
                      label: Text(s.toUpperCase()),
                      selected: isSelected,
                      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                      onSelected: (selected) async {
                        if (selected) {
                          await FeedbackService.updateFeedbackStatus(
                              widget.instituteId, id, s);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
                AppSpacing.gapXXl,
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(ThemeData theme, String label, dynamic content) {
    if (content == null || content.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          AppSpacing.gapXs,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(color: theme.dividerColor),
            ),
            child:
                SelectableText(content.toString(), style: textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
