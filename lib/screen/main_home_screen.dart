import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cs261_project/model/chat_model.dart';
import 'package:cs261_project/model/news_event_model.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/events_and_news/news_event_detail_screen.dart';
import 'package:cs261_project/screen/profile/profile_edit_screen.dart';
import 'package:cs261_project/service/chat_service.dart';
import 'package:cs261_project/service/news_event_service.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';

/// Home dashboard: greeting, profile progress, quick actions, events and recent posts.
class MainHomeScreen extends StatefulWidget {
  final String instituteId;

  /// Switches the parent bottom-navigation tab (1 Search, 2 News, 3 Profile, 4 Inbox).
  final ValueChanged<int>? onNavigate;

  const MainHomeScreen({super.key, required this.instituteId, this.onNavigate});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final NewsEventService _newsService = NewsEventService();

  Stream<ParticipantModel?>? _profileStream;
  Stream<List<NewsEventPost>>? _postsStream;
  Stream<List<ChatModel>>? _inboxStream;

  @override
  void initState() {
    super.initState();
    final uid = _user?.uid;
    if (uid != null) {
      _profileStream = ProfileService(instituteId: widget.instituteId).getProfileStream(uid);
      _inboxStream = ChatService.streamInbox(widget.instituteId, uid);
    }
  }

  /// Posts query for [role]; rebuilt only when the role changes (it decides which
  /// visibilities the query may ask for).
  String? _postsRole;
  Stream<List<NewsEventPost>> _postsFor(String role) {
    if (_postsStream == null || _postsRole != role) {
      _postsRole = role;
      _postsStream = _newsService.getPosts(widget.instituteId, role: role);
    }
    return _postsStream!;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Mirrors the completeness check used at login.
  double _completeness(ParticipantModel p) {
    bool has(String? v) => v != null && v.trim().isNotEmpty;
    final checks = <bool>[has(p.name), has(p.bio), has(p.interest), has(p.year)];
    if (p.role == 'student') checks.add(has(p.rollNo));
    if (p.role == 'alumni') checks.add(has(p.company));
    return checks.where((c) => c).length / checks.length;
  }

  bool _isVisible(NewsEventPost p, String role) {
    switch (p.visibility) {
      case 'admins_only':
        return role == 'admin';
      case 'alumni_only':
        return role == 'alumni' || role == 'admin';
      case 'students_only':
        return role == 'student' || role == 'admin';
      default:
        return true;
    }
  }

  void _openPost(NewsEventPost post, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsEventDetailScreen(
          instituteId: widget.instituteId,
          post: post,
          userRole: role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ParticipantModel?>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final role = profile?.role ?? 'student';

        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _postsStream = _newsService.getPosts(widget.instituteId, role: role);
          }),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildGreeting(profile),
              AppSpacing.gapLg,
              _buildHeroCard(profile),
              AppSpacing.gapLg,
              _buildQuickActions(),
              AppSpacing.gapLg,
              _buildInboxSummary(),
              StreamBuilder<List<NewsEventPost>>(
                stream: profile == null ? null : _postsFor(role),
                builder: (context, snap) {
                  final posts = (snap.data ?? []).where((p) => _isVisible(p, role)).toList();
                  final now = DateTime.now();
                  final events = posts
                      .where((p) => p.type == 'event' && p.eventDate != null && p.eventDate!.isAfter(now.subtract(const Duration(days: 1))))
                      .toList()
                    ..sort((a, b) => a.eventDate!.compareTo(b.eventDate!));
                  final recent = posts.where((p) => p.type != 'event').take(3).toList();

                  if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSpacing.gapLg,
                      AppSectionHeader(
                        title: 'Upcoming events',
                        actionLabel: 'See all',
                        onAction: () => widget.onNavigate?.call(2),
                      ),
                      if (events.isEmpty)
                        _buildEmptyHint(Icons.event_available_outlined, 'No upcoming events yet')
                      else
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => _buildEventCard(events[i], role),
                          ),
                        ),
                      AppSpacing.gapLg,
                      AppSectionHeader(
                        title: 'Latest from your network',
                        actionLabel: 'Open feed',
                        onAction: () => widget.onNavigate?.call(2),
                      ),
                      if (recent.isEmpty)
                        _buildEmptyHint(Icons.forum_outlined, 'Nothing posted yet. Be the first!')
                      else
                        ...recent.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildPostRow(p, role),
                            )),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreeting(ParticipantModel? profile) {
    final theme = Theme.of(context);
    final name = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
        : (_user?.email?.split('@').first ?? 'there');
    final firstName = name.split(' ').first;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: theme.textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (profile != null) ...[
                const SizedBox(height: 8),
                RoleBadge(role: profile.role),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: () => widget.onNavigate?.call(3),
          child: AppAvatar(name: name, imageUrl: profile?.profileImage, radius: 28, ring: true),
        ),
      ],
    );
  }

  Widget _buildHeroCard(ParticipantModel? profile) {
    final theme = Theme.of(context);
    final progress = profile == null ? 1.0 : _completeness(profile);
    final incomplete = progress < 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incomplete ? 'Complete your profile' : 'Grow your network',
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                incomplete
                    ? 'A full profile helps alumni and mentors find you.'
                    : 'Find alumni, mentors and classmates in your institute.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
              ),
              if (incomplete) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.forestDeep,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () {
                  final uid = _user?.uid;
                  if (incomplete && uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(
                          userDocumentId: uid,
                          instituteId: widget.instituteId,
                        ),
                      ),
                    );
                  } else {
                    widget.onNavigate?.call(1);
                  }
                },
                icon: Icon(incomplete ? Icons.edit_outlined : Icons.travel_explore_rounded, size: 18),
                label: Text(incomplete ? 'Finish profile' : 'Explore people'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.person_search_outlined, 'Find people', 1),
      (Icons.dynamic_feed_outlined, 'Feed', 2),
      (Icons.chat_bubble_outline_rounded, 'Messages', 4),
      (Icons.badge_outlined, 'My profile', 3),
    ];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        for (final (icon, label, tab) in actions)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => widget.onNavigate?.call(tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Icon(icon, color: cs.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInboxSummary() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = _user?.uid;

    return StreamBuilder<List<ChatModel>>(
      stream: _inboxStream,
      builder: (context, snap) {
        final chats = snap.data ?? [];
        final unread = chats
            .where((c) => c.readStatus[uid] == false && c.archivedBy[uid] != true)
            .length;

        return AppSurfaceCard(
          onTap: () => widget.onNavigate?.call(4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.mark_chat_unread_outlined, color: cs.onSecondaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unread == 0
                          ? 'You\'re all caught up'
                          : '$unread unread conversation${unread == 1 ? '' : 's'}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chats.isEmpty
                          ? 'Start a conversation with alumni'
                          : '${chats.length} conversation${chats.length == 1 ? '' : 's'} in your inbox',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(NewsEventPost event, String role) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = event.eventDate!;

    return SizedBox(
      width: 240,
      child: AppSurfaceCard(
        onTap: () => _openPost(event, role),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer),
                  ),
                  Text(
                    DateFormat('d').format(date),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if ((event.eventLocation ?? '').isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.eventLocation!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.attendeeCount} going',
                    style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostRow(NewsEventPost post, String role) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final author = post.authorName.isNotEmpty ? post.authorName : 'Member';

    return AppSurfaceCard(
      onTap: () => _openPost(post, role),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: author, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        author,
                        style: theme.textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM').format(post.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  post.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  post.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.likeCount}', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 14),
                    Icon(Icons.chat_bubble_outline_rounded, size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.commentCount}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(IconData icon, String text) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}
