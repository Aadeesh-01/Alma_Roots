import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/news_event_model.dart';
import '../../service/news_event_service.dart';
import 'news_event_screen.dart'; // To access CreatePostModal
import 'package:cs261_project/theme/app_spacing.dart';

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

  Widget _buildEventDetails(ThemeData theme) {
    if (widget.post.type != 'event') return const SizedBox.shrink();

    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: colorScheme.secondary),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  widget.post.eventDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy - h:mm a')
                          .format(widget.post.eventDate!)
                      : 'Date TBD',
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary),
                ),
              ),
            ],
          ),
          if (widget.post.eventLocation != null &&
              widget.post.eventLocation!.isNotEmpty) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                Icon(Icons.location_on, color: colorScheme.secondary),
                AppSpacing.gapSm,
                Expanded(
                    child: Text(widget.post.eventLocation!,
                        style: textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.secondary))),
              ],
            ),
          ],
          AppSpacing.gapLg,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  "Attendees: ${widget.post.attendeeCount}${widget.post.maxAttendees != null ? ' / ${widget.post.maxAttendees}' : ''}",
                  style: textTheme.bodyMedium),
              if (widget.post.registrationRequired)
                ElevatedButton(
                  onPressed: _isRsvping
                      ? null
                      : () => _handleRsvp(
                          true), // TODO: determine if already attending
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary),
                  child: const Text("RSVP Now",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          )
        ],
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.post.category.toUpperCase(),
            style: textTheme.titleMedium?.copyWith(letterSpacing: 1.0)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
        actions: [
          if (canEditOrDelete)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: colorScheme.onSurface),
              onSelected: (val) {
                if (val == 'edit') {
                  _editPost(context);
                } else if (val == 'delete') {
                  _showDeleteConfirmation(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text("Edit")),
                PopupMenuItem(
                    value: 'delete',
                    child: Text("Delete",
                        style: TextStyle(color: colorScheme.error))),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _showSnackBar(
                "Share functionality coming soon", colorScheme.primary),
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

          return SingleChildScrollView(
            child: Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post.title,
                      style: textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  AppSpacing.gapMd,
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(
                            widget.post.authorName.isNotEmpty
                                ? widget.post.authorName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary)),
                      ),
                      AppSpacing.gapSm,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.post.authorName,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            widget.post.authorRole.toUpperCase(),
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                              DateFormat('MMM d, yyyy')
                                  .format(widget.post.createdAt),
                              style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,
                  Text(widget.post.description,
                      style: textTheme.bodyLarge?.copyWith(height: 1.6)),

                  // Event Details
                  if (widget.post.type == 'event')
                    Container(
                      margin:
                          const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(
                            color:
                                colorScheme.secondary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event, color: colorScheme.secondary),
                              AppSpacing.gapSm,
                              Expanded(
                                child: Text(
                                  widget.post.eventDate != null
                                      ? DateFormat(
                                              'EEEE, MMMM d, yyyy - h:mm a')
                                          .format(widget.post.eventDate!)
                                      : 'Date TBD',
                                  style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.secondary),
                                ),
                              ),
                            ],
                          ),
                          if (widget.post.eventLocation != null &&
                              widget.post.eventLocation!.isNotEmpty) ...[
                            AppSpacing.gapSm,
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: colorScheme.secondary),
                                AppSpacing.gapSm,
                                Expanded(
                                    child: Text(widget.post.eventLocation!,
                                        style: textTheme.bodyLarge?.copyWith(
                                            color: colorScheme.secondary))),
                              ],
                            ),
                          ],
                          AppSpacing.gapLg,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  "Attendees: $currentAttendeeCount${widget.post.maxAttendees != null ? ' / ${widget.post.maxAttendees}' : ''}",
                                  style: textTheme.bodyMedium),
                              if (widget.post.registrationRequired)
                                ElevatedButton(
                                  onPressed: _isRsvping
                                      ? null
                                      : () => _handleRsvp(true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary),
                                  child: const Text("RSVP Now",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          )
                        ],
                      ),
                    ),

                  Divider(color: theme.dividerColor, height: AppSpacing.xxl),
                  Row(
                    children: [
                      InkWell(
                        onTap: _isLiking ? null : _handleLike,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Row(
                            children: [
                              Icon(Icons.thumb_up_outlined,
                                  color: colorScheme.onSurfaceVariant),
                              AppSpacing.gapXs,
                              Text('$currentLikeCount Likes',
                                  style: TextStyle(
                                      color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.gapLg,
                      Icon(Icons.comment_outlined,
                          color: colorScheme.onSurfaceVariant),
                      AppSpacing.gapXs,
                      Text('$currentCommentCount Comments',
                          style:
                              TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  Divider(color: theme.dividerColor, height: AppSpacing.xxl),

                  Text("Comments",
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  AppSpacing.gapLg,

                  // Add comment field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: "Add a comment...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm),
                            filled: true,
                            fillColor: colorScheme.surface,
                          ),
                        ),
                      ),
                      AppSpacing.gapSm,
                      CircleAvatar(
                        backgroundColor: colorScheme.primary,
                        child: IconButton(
                          icon: Icon(Icons.send,
                              color: colorScheme.onPrimary, size: 18),
                          onPressed: _postComment,
                        ),
                      )
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Comments Stream
                  StreamBuilder<QuerySnapshot>(
                    stream: _service.getCommentsStream(
                        widget.instituteId, widget.post.id),
                    builder: (context, commentsSnapshot) {
                      if (commentsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (commentsSnapshot.hasError) {
                        return const Center(
                            child: Text("Error loading comments."));
                      }
                      final comments = commentsSnapshot.data?.docs ?? [];
                      if (comments.isEmpty) {
                        return Center(
                            child: Text(
                                "No comments yet. Be the first to comment!",
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant)));
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final cData =
                              comments[index].data() as Map<String, dynamic>;
                          final cName = cData['name'] ?? 'Unknown';
                          final cText = cData['text'] ?? '';
                          final cTime = cData['timestamp'] as Timestamp?;
                          final timeStr = cTime != null
                              ? DateFormat('MMM d, hh:mm a')
                                  .format(cTime.toDate())
                              : 'Just now';

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                    cName.isNotEmpty
                                        ? cName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              AppSpacing.gapSm,
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(cName,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                          Text(timeStr,
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant)),
                                        ],
                                      ),
                                      AppSpacing.gapXs,
                                      Text(cText, style: textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
