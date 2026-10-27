import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/news_event_model.dart';
import '../../service/news_event_service.dart';
import 'news_event_screen.dart'; // To access CreatePostModal
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';

class NewsEventDetailScreen extends StatefulWidget {
  final String instituteId;
  final NewsEventPost post;
  final String userRole; // passed from list screen to enforce UI

  const NewsEventDetailScreen({
    super.key,
    required this.instituteId,
    required this.post,
    required this.userRole,
  });

  @override
  State<NewsEventDetailScreen> createState() => _NewsEventDetailScreenState();
}

class _NewsEventDetailScreenState extends State<NewsEventDetailScreen> {
  final NewsEventService _service = NewsEventService();
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLiking = false;
  bool _isRsvping = false;

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _handleLike() async {
    final user = _currentUser;
    if (user == null) return;
    setState(() => _isLiking = true);
    try {
      await _service.toggleLike(
        widget.instituteId,
        widget.post.id,
        user.uid,
        user.displayName ?? 'Unknown',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          "Error updating like: $e", Theme.of(context).colorScheme.error);
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _handleRsvp(bool isAttending) async {
    final user = _currentUser;
    if (user == null) return;
    setState(() => _isRsvping = true);
    try {
      await _service.toggleRsvp(
        widget.instituteId,
        widget.post.id,
        user.uid,
        user.displayName ?? 'Unknown',
        user.email ?? '',
        isAttending,
      );
      if (!mounted) return;
      _showSnackBar(
          isAttending ? "RSVP Confirmed!" : "RSVP Cancelled", Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("RSVP failed: $e", Theme.of(context).colorScheme.error);
    } finally {
      if (mounted) setState(() => _isRsvping = false);
    }
  }

  Future<void> _postComment() async {
    final user = _currentUser;
    if (user == null || _commentController.text.trim().isEmpty) return;
    try {
      await _service.addComment(
        widget.instituteId,
        widget.post.id,
        user.uid,
        user.displayName ?? 'Unknown',
        _commentController.text.trim(),
      );
      _commentController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          "Failed to post comment", Theme.of(context).colorScheme.error);
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deletePost(widget.instituteId, widget.post.id);
              if (!context.mounted) return;
              Navigator.pop(context); // Go back to feed
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _editPost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000), // transparent
      builder: (context) => CreatePostModal(
        instituteId: widget.instituteId,
        userRole: widget.userRole,
        service: _service,
        editPost: widget.post,
      ),
    );
  }

  Widget _buildEventCard(ThemeData theme, int attendeeCount) {
    final cs = theme.colorScheme;
    final text = theme.textTheme;
    final date = widget.post.eventDate;
    final capacity = widget.post.maxAttendees;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      date != null ? DateFormat('MMM').format(date).toUpperCase() : 'TBD',
                      style: text.labelSmall?.copyWith(color: AppColors.gold),
                    ),
                    Text(
                      date != null ? DateFormat('d').format(date) : '–',
                      style: text.headlineSmall?.copyWith(color: Colors.white, height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null ? DateFormat('EEEE, d MMMM yyyy').format(date) : 'Date to be announced',
                      style: text.titleSmall,
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 2),
                      Text(DateFormat('h:mm a').format(date), style: text.bodySmall),
                    ],
                    if (widget.post.eventLocation != null && widget.post.eventLocation!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 15, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(child: Text(widget.post.eventLocation!, style: text.bodySmall)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: cs.secondary),
              const SizedBox(width: 6),
              Text(
                capacity != null ? '$attendeeCount of $capacity spots taken' : '$attendeeCount attending',
                style: text.labelLarge?.copyWith(color: cs.secondary),
              ),
            ],
          ),
          if (capacity != null && capacity > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (attendeeCount / capacity).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
          ],
          if (widget.post.registrationRequired) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isRsvping ? null : () => _handleRsvp(true),
              icon: _isRsvping
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Icon(Icons.how_to_reg_outlined, size: 18),
              label: const Text('RSVP to this event'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComment(ThemeData theme, Map<String, dynamic> cData) {
    final cs = theme.colorScheme;
    final cName = (cData['name'] as String?)?.trim().isNotEmpty == true ? cData['name'] as String : 'Member';
    final cText = cData['text'] ?? '';
    final cTime = cData['timestamp'] as Timestamp?;
    final timeStr = cTime != null ? DateFormat('d MMM, h:mm a').format(cTime.toDate()) : 'Just now';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(name: cName, radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
                topLeft: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(cName, style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(timeStr, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(cText, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: cs.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _postComment,
              tooltip: 'Send',
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
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
    final bool canEditOrDelete = _currentUser?.uid == widget.post.authorUid ||
        widget.userRole == 'admin';
    final authorName = widget.post.authorName.isNotEmpty ? widget.post.authorName : 'Member';

    final categoryWords = widget.post.category.replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty);
    final categoryLabel = categoryWords.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.post.type == 'event'
              ? 'Event'
              : widget.post.type == 'news'
                  ? 'News'
                  : 'Post',
        ),
        actions: [
          if (canEditOrDelete)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (val) {
                if (val == 'edit') {
                  _editPost(context);
                } else if (val == 'delete') {
                  _showDeleteConfirmation(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                    title: Text('Delete', style: TextStyle(color: colorScheme.error)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.getPostStream(widget.instituteId, widget.post.id),
        builder: (context, postSnapshot) {
          int currentLikeCount = widget.post.likeCount;
          int currentCommentCount = widget.post.commentCount;
          int currentAttendeeCount = widget.post.attendeeCount;

          if (postSnapshot.hasData && postSnapshot.data!.exists) {
            final data = postSnapshot.data!.data() as Map<String, dynamic>;
            currentLikeCount =
                data['likeCount'] ?? (data['likes'] as List?)?.length ?? 0;
            currentCommentCount = data['commentCount'] ?? 0;
            currentAttendeeCount = data['attendeeCount'] ?? 0;
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryLabel,
                            style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer),
                          ),
                        ),
                        if (widget.post.isPinned) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.gold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.post.title, style: textTheme.headlineMedium?.copyWith(height: 1.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        AppAvatar(name: authorName, radius: 21),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(authorName, style: textTheme.titleSmall),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  RoleBadge(role: widget.post.authorRole, dense: true),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('d MMM yyyy').format(widget.post.createdAt),
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(widget.post.description, style: textTheme.bodyLarge?.copyWith(height: 1.65)),

                    if (widget.post.type == 'event') _buildEventCard(theme, currentAttendeeCount),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLiking ? null : _handleLike,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.favorite_border_rounded, size: 18),
                          label: Text('$currentLikeCount ${currentLikeCount == 1 ? 'like' : 'likes'}'),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.chat_bubble_outline_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          '$currentCommentCount ${currentCommentCount == 1 ? 'comment' : 'comments'}',
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 20),
                    Text('Comments', style: textTheme.titleLarge),
                    const SizedBox(height: 14),

                    StreamBuilder<QuerySnapshot>(
                      stream: _service.getCommentsStream(widget.instituteId, widget.post.id),
                      builder: (context, commentsSnapshot) {
                        if (commentsSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (commentsSnapshot.hasError) {
                          return const Center(child: Text("Error loading comments."));
                        }
                        final comments = commentsSnapshot.data?.docs ?? [];
                        if (comments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(Icons.forum_outlined, size: 32, color: colorScheme.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text(
                                  "No comments yet. Start the conversation!",
                                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final c in comments) ...[
                              _buildComment(theme, c.data() as Map<String, dynamic>),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              _buildComposer(theme),
            ],
          );
        },
      ),
    );
  }
}
