import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/news_event_model.dart';
import '../../service/news_event_service.dart';
import 'news_event_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class NewsEventScreen extends StatefulWidget {
  final String instituteId;
  final bool isNested;
  const NewsEventScreen({super.key, required this.instituteId, this.isNested = false});

  @override
  State<NewsEventScreen> createState() => _NewsEventScreenState();
}

class _NewsEventScreenState extends State<NewsEventScreen> with SingleTickerProviderStateMixin {
  final NewsEventService _service = NewsEventService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  String _userRole = 'student';
  bool _isLoadingRole = true;

  late TabController _tabController;
  late Stream<List<NewsEventPost>> _postsStream;

  static const int _pageSize = 20;
  int _postLimit = _pageSize;
  // Last page shown, kept on screen while a bigger page loads.
  List<NewsEventPost>? _lastPosts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // The posts query depends on the role (see NewsEventService.visibilitiesFor),
    // so it starts once the role is known.
    _fetchUserRole();
  }

  void _loadMore() {
    setState(() {
      _postLimit += _pageSize;
      _postsStream = _streamPosts();
    });
  }

  Stream<List<NewsEventPost>> _streamPosts() =>
      _service.getPosts(widget.instituteId, role: _userRole, limit: _postLimit, includeDeleted: true);

  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      final doc = await _firestore
          .collection('institutes')
          .doc(widget.instituteId)
          .collection('participants')
          .doc(_currentUser!.uid)
          .get();

      String roleStr = 'student';
      if (doc.exists) {
        final dataRole = doc.data()?['role'];
        if (dataRole != null) {
          roleStr = dataRole.toString().trim().toLowerCase();
        }
      }

      if (mounted) {
        setState(() {
          _userRole = roleStr;
          _postsStream = _streamPosts();
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsStream = _streamPosts();
          _isLoadingRole = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddPostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000), // transparent
      builder: (context) => CreatePostModal(
        instituteId: widget.instituteId,
        userRole: _userRole,
        service: _service,
      ),
    );
  }

  Widget _buildFeed(ThemeData theme, List<NewsEventPost> allPosts, String filterType, bool hasMore) {
    var posts = allPosts;
    if (filterType != 'all') {
      posts = posts.where((p) => p.type == filterType).toList();
    }

    // Visibility filtering
    posts = posts.where((p) {
      if (p.visibility == 'public') return true;
      if (p.visibility == 'admins_only' && _userRole == 'admin') return true;
      if (p.visibility == 'alumni_only' && (_userRole == 'alumni' || _userRole == 'admin')) return true;
      if (p.visibility == 'students_only' && (_userRole == 'student' || _userRole == 'admin')) return true;
      return false;
    }).toList();

    if (posts.isEmpty && !hasMore) {
      return _buildEmptyFeed(theme, filterType);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: posts.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load older posts'),
            ),
          );
        }
        return _PostCard(
          post: posts[index],
          instituteId: widget.instituteId,
          userRole: _userRole,
          currentUserId: _currentUser?.uid ?? '',
          service: _service,
        );
      },
    );
  }

  Widget _buildEmptyFeed(ThemeData theme, String filterType) {
    final cs = theme.colorScheme;
    final label = switch (filterType) {
      'news' => 'No news yet',
      'event' => 'No events yet',
      'experience' => 'No experiences shared yet',
      _ => 'Your feed is quiet',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: cs.secondaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.forest_outlined, size: 34, color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            Text(label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Share an experience, an opportunity or an event with your network.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showAddPostModal,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Create a post'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: SizedBox(
          height: 40,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'News'),
              Tab(text: 'Events'),
              Tab(text: 'Experiences'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: widget.isNested ? null : AppBar(
        title: const Text('News & Events'),
        bottom: _buildTabBar(),
      ),
      body: Column(
        children: [
          if (widget.isNested) _buildTabBar(),
          Expanded(
            child: StreamBuilder<List<NewsEventPost>>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading posts.", style: TextStyle(color: colorScheme.error)));
                }
                final raw = snapshot.data ?? _lastPosts;
                if (raw == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                _lastPosts = raw;
                // A full raw page (deleted posts included) means older posts may exist.
                final hasMore = raw.length >= _postLimit;
                final allPosts = raw.where((p) => p.status != 'deleted').toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFeed(theme, allPosts, 'all', hasMore),
                    _buildFeed(theme, allPosts, 'news', hasMore),
                    _buildFeed(theme, allPosts, 'event', hasMore),
                    _buildFeed(theme, allPosts, 'experience', hasMore),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showAddPostModal,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Post'),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final NewsEventPost post;
  final String instituteId;
  final String userRole;
  final String currentUserId;
  final NewsEventService service;

  const _PostCard({
    required this.post,
    required this.instituteId,
    required this.userRole,
    required this.currentUserId,
    required this.service,
  });

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
              await service.deletePost(instituteId, post.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
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
        instituteId: instituteId,
        userRole: userRole,
        service: service,
        editPost: post,
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsEventDetailScreen(
          instituteId: instituteId,
          post: post,
          userRole: userRole,
        ),
      ),
    );
  }

  static String categoryLabel(String category) {
    final words = category.replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bool canEditOrDelete = currentUserId == post.authorUid || userRole == 'admin';
    final authorName = post.authorName.isNotEmpty ? post.authorName : 'Member';
    final isEvent = post.type == 'event' && post.eventDate != null;

    final (IconData typeIcon, Color typeColor) = switch (post.type) {
      'news' => (Icons.campaign_outlined, AppColors.clay),
      'event' => (Icons.event_outlined, AppColors.sage),
      _ => (Icons.auto_awesome_outlined, AppColors.goldDeep),
    };
    final chipFg = theme.brightness == Brightness.dark ? Color.lerp(typeColor, Colors.white, 0.45)! : typeColor;

    return AppSurfaceCard(
      onTap: () => _openDetail(context),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 0),
            child: Row(
              children: [
                AppAvatar(name: authorName, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          RoleBadge(role: post.authorRole, dense: true),
                          const SizedBox(width: 8),
                          Text(_getTimeAgo(post.createdAt), style: textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.isPinned)
                  Tooltip(
                    message: 'Pinned',
                    child: Icon(Icons.push_pin_rounded, color: AppColors.gold, size: 18),
                  ),
                if (canEditOrDelete)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, color: colorScheme.onSurfaceVariant),
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
                  )
                else
                  const SizedBox(width: 10),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 14, color: chipFg),
                      const SizedBox(width: 5),
                      Text(
                        categoryLabel(post.category),
                        style: textTheme.labelSmall?.copyWith(color: chipFg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(post.title, style: textTheme.titleLarge?.copyWith(fontSize: 19, height: 1.25)),
                const SizedBox(height: 6),
                Text(
                  post.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // Event block
          if (isEvent)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('MMM').format(post.eventDate!).toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimary.withValues(alpha: 0.8)),
                        ),
                        Text(
                          DateFormat('d').format(post.eventDate!),
                          style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary, height: 1.1),
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
                          DateFormat('EEEE, d MMMM').format(post.eventDate!),
                          style: textTheme.titleSmall,
                        ),
                        if (post.eventLocation != null && post.eventLocation!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  post.eventLocation!,
                                  style: textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          post.maxAttendees != null
                              ? '${post.attendeeCount} / ${post.maxAttendees} going'
                              : '${post.attendeeCount} going',
                          style: textTheme.labelSmall?.copyWith(color: colorScheme.secondary),
                        ),
                      ],
                    ),
                  ),
                  if (post.registrationRequired)
                    FilledButton.tonal(
                      onPressed: () => _openDetail(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('RSVP'),
                    ),
                ],
              ),
            ),

          // Engagement bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    if (currentUserId.isEmpty) return;
                    try {
                      final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
                      await service.toggleLike(instituteId, post.id, currentUserId, userName);
                    } catch (e) {
                      if (context.mounted) AppSnackBar.showError(context, 'Could not update like');
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
                  icon: const Icon(Icons.favorite_border_rounded, size: 19),
                  label: Text('${post.likeCount}'),
                ),
                TextButton.icon(
                  onPressed: () => _openDetail(context),
                  style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text('${post.commentCount}'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openDetail(context),
                  child: const Text('Read more'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreatePostModal extends StatefulWidget {
  final String instituteId;
  final String userRole;
  final NewsEventService service;
  final NewsEventPost? editPost;

  const CreatePostModal({
    super.key,
    required this.instituteId,
    required this.userRole,
    required this.service,
    this.editPost,
  });

  @override
  State<CreatePostModal> createState() => CreatePostModalState();
}

class CreatePostModalState extends State<CreatePostModal> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  String _uiPostType = 'Experience';
  String _visibility = 'public';
  bool _isPinned = false;
  
  DateTime? _eventDate;
  String _eventLocation = '';
  bool _registrationRequired = false;
  int? _maxAttendees;
  bool _waitlistEnabled = false;

  bool _isLoading = false;

  final Map<String, Map<String, String>> _typeMapping = {
    'Experience': {'type': 'experience', 'category': 'networking'},
    'Achievement': {'type': 'experience', 'category': 'achievements'},
    'Internship': {'type': 'experience', 'category': 'internships'},
    'Job Opportunity': {'type': 'experience', 'category': 'placements'},
    'Mentorship': {'type': 'experience', 'category': 'alumni_meet'},
    'Research': {'type': 'experience', 'category': 'research'},
    'Career Guidance': {'type': 'experience', 'category': 'career_guidance'},
    'Event': {'type': 'event', 'category': 'workshops'},
    'Hackathon': {'type': 'event', 'category': 'hackathons'},
    'Workshop': {'type': 'event', 'category': 'workshops'},
    'News': {'type': 'news', 'category': 'announcements'},
    'Announcement': {'type': 'news', 'category': 'announcements'},
  };

  String _getUIPostType(String type, String category) {
    if (type == 'news') {
      if (category == 'announcements') return 'Announcement';
      return 'News';
    }
    if (type == 'event') {
      if (category == 'hackathons') return 'Hackathon';
      if (category == 'workshops') return 'Workshop';
      return 'Event';
    }
    if (type == 'experience') {
      if (category == 'achievements') return 'Achievement';
      if (category == 'internships') return 'Internship';
      if (category == 'placements') return 'Job Opportunity';
      if (category == 'alumni_meet') return 'Mentorship';
      if (category == 'research') return 'Research';
      if (category == 'career_guidance') return 'Career Guidance';
    }
    return 'Experience';
  }

  @override
  void initState() {
    super.initState();
    if (widget.editPost != null) {
      final post = widget.editPost!;
      _titleCtrl.text = post.title;
      _descCtrl.text = post.description;
      
      _uiPostType = _getUIPostType(post.type, post.category);
      
      _visibility = post.visibility;
      _isPinned = post.isPinned;
      
      _eventDate = post.eventDate;
      _eventLocation = post.eventLocation ?? '';
      _registrationRequired = post.registrationRequired;
      _maxAttendees = post.maxAttendees;
      _waitlistEnabled = post.waitlistEnabled;
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() => _eventDate = date);
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final keywords = [..._titleCtrl.text.toLowerCase().split(' '), ..._descCtrl.text.toLowerCase().split(' ')];
      
      final mappedType = _typeMapping[_uiPostType]!['type']!;
      final mappedCategory = _typeMapping[_uiPostType]!['category']!;

      if (widget.editPost != null) {
        await widget.service.updatePost(widget.instituteId, widget.editPost!.id, {
          'type': mappedType,
          'category': mappedCategory,
          'visibility': _visibility,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'searchKeywords': keywords,
          'isPinned': _isPinned,
          'eventDate': mappedType == 'event' ? _eventDate : null,
          'eventLocation': mappedType == 'event' ? _eventLocation : null,
          'registrationRequired': mappedType == 'event' ? _registrationRequired : false,
          'maxAttendees': _maxAttendees,
          'waitlistEnabled': _waitlistEnabled,
        });
      } else {
        // Prefer the profile name; the Auth display name is usually empty or the email.
        String authorName = user.displayName?.trim() ?? '';
        try {
          final participant = await FirebaseFirestore.instance
              .collection('institutes')
              .doc(widget.instituteId)
              .collection('participants')
              .doc(user.uid)
              .get();
          final profileName = (participant.data()?['name'] as String?)?.trim() ?? '';
          if (profileName.isNotEmpty) authorName = profileName;
        } catch (_) {}
        if (authorName.isEmpty || authorName.contains('@')) {
          authorName = authorName.contains('@') ? authorName.split('@').first : 'Member';
        }

        final post = NewsEventPost(
          id: '',
          instituteId: widget.instituteId,
          type: mappedType,
          category: mappedCategory,
          visibility: _visibility,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          authorUid: user.uid,
          authorName: authorName,
          authorRole: widget.userRole,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          searchKeywords: keywords,
          isPinned: _isPinned,
          eventDate: mappedType == 'event' ? _eventDate : null,
          eventLocation: mappedType == 'event' ? _eventLocation : null,
          registrationRequired: mappedType == 'event' ? _registrationRequired : false,
          maxAttendees: _maxAttendees,
          waitlistEnabled: _waitlistEnabled,
        );
        await widget.service.addPost(post);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildChoiceGroup(ThemeData theme, String label, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((o) => ChoiceChip(
                    label: Text(o),
                    selected: _uiPostType == o,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _uiPostType = o),
                  ))
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';
    final isEditing = widget.editPost != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isEvent = _typeMapping[_uiPostType]!['type'] == 'event';

    const visibilityLabels = {
      'public': 'Everyone',
      'alumni_only': 'Alumni',
      'students_only': 'Students',
      'admins_only': 'Admins',
    };

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(isEditing ? "Edit post" : "Create a post", style: textTheme.headlineSmall),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildChoiceGroup(theme, 'SHARE', const [
                'Experience', 'Achievement', 'Internship', 'Job Opportunity',
                'Mentorship', 'Research', 'Career Guidance',
              ]),
              const SizedBox(height: 14),
              _buildChoiceGroup(theme, 'EVENT', const ['Event', 'Hackathon', 'Workshop']),
              if (isAdmin) ...[
                const SizedBox(height: 14),
                _buildChoiceGroup(theme, 'ANNOUNCE', const ['News', 'Announcement']),
              ],
              const SizedBox(height: 20),

              TextField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What would you like to share?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              Text('WHO CAN SEE THIS', style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: visibilityLabels.entries
                    .map((e) => ChoiceChip(
                          avatar: Icon(
                            e.key == 'public' ? Icons.public_rounded : Icons.group_outlined,
                            size: 16,
                            color: _visibility == e.key ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                          label: Text(e.value),
                          selected: _visibility == e.key,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _visibility = e.key),
                        ))
                    .toList(),
              ),

              if (isAdmin && _typeMapping[_uiPostType]!['type'] == 'news') ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.push_pin_outlined, color: AppColors.gold),
                  title: const Text("Pin to top of feed"),
                  value: _isPinned,
                  onChanged: (val) => setState(() => _isPinned = val),
                ),
              ],

              if (isEvent) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Event details", style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: colorScheme.surface,
                        ),
                        icon: Icon(Icons.calendar_month_outlined, color: colorScheme.primary),
                        label: Text(
                          _eventDate == null ? 'Pick a date' : DateFormat('EEEE, d MMMM yyyy').format(_eventDate!),
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _eventLocation,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.place_outlined, size: 20),
                        ),
                        onChanged: (val) => _eventLocation = val,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _maxAttendees?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Capacity (optional)',
                          prefixIcon: Icon(Icons.groups_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _maxAttendees = int.tryParse(val),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Registration required"),
                        value: _registrationRequired,
                        onChanged: (val) => setState(() => _registrationRequired = val),
                      ),
                      if (_registrationRequired)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Waitlist when full"),
                          value: _waitlistEnabled,
                          onChanged: (val) => setState(() => _waitlistEnabled = val),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.onPrimary),
                        )
                      : Text(isEditing ? "Save changes" : "Publish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
