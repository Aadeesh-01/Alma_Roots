import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/news_event_model.dart';
import '../../service/news_event_service.dart';
import 'news_event_detail_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _postsStream = _service.getPosts(widget.instituteId);
    _fetchUserRole();
  }

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
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
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

  Widget _buildFeed(ThemeData theme, List<NewsEventPost> allPosts, String filterType) {
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

    if (posts.isEmpty) {
      return Center(child: Text("No posts match this filter.", style: theme.textTheme.bodyLarge));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: posts.length,
      separatorBuilder: (_, __) => AppSpacing.gapMd,
      itemBuilder: (context, index) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.isNested ? null : AppBar(
        title: const Text('News & Events'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.primary.withValues(alpha: 0.1),
          ),
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'News'),
            Tab(text: 'Events'),
            Tab(text: 'Experiences'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.isNested)
            Container(
              color: colorScheme.surface,
              width: double.infinity,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'News'),
                  Tab(text: 'Events'),
                  Tab(text: 'Experiences'),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<NewsEventPost>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading posts.", style: TextStyle(color: colorScheme.error)));
          }
          final allPosts = snapshot.data ?? [];

          if (allPosts.isEmpty) {
            return Center(child: Text("No posts found.", style: textTheme.bodyLarge));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildFeed(theme, allPosts, 'all'),
              _buildFeed(theme, allPosts, 'news'),
              _buildFeed(theme, allPosts, 'event'),
              _buildFeed(theme, allPosts, 'experience'),
            ],
          );
        },
      ),
    ),
  ],
),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _showAddPostModal,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bool canEditOrDelete = currentUserId == post.authorUid || userRole == 'admin';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: () {
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
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author Section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${post.authorRole.toUpperCase()} • ${_getTimeAgo(post.createdAt)}',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (post.isPinned) Icon(Icons.push_pin, color: colorScheme.secondary, size: 20),
                  if (canEditOrDelete)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _editPost(context);
                        } else if (val == 'delete') {
                          _showDeleteConfirmation(context);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text("Edit")),
                        PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: colorScheme.error))),
                      ],
                    ),
                ],
              ),
            ),
            
            // Content Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  AppSpacing.gapSm,
                  Text(
                    post.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),

            // Event Info Block (if applicable)
            if (post.type == 'event' && post.eventDate != null) ...[
              AppSpacing.gapMd,
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_month, color: colorScheme.secondary),
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Upcoming Event", style: textTheme.bodySmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.bold)),
                          Text(
                            "${post.eventDate!.month}/${post.eventDate!.day}/${post.eventDate!.year}",
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (post.eventLocation != null && post.eventLocation!.isNotEmpty)
                            Text(post.eventLocation!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (post.registrationRequired)
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onSecondary,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text("RSVP"),
                      ),
                  ],
                ),
              ),
            ],

            AppSpacing.gapMd,
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),

            // Interactive Bottom Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      if (currentUserId.isEmpty) return;
                      try {
                        final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
                        await service.toggleLike(instituteId, post.id, currentUserId, userName);
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    icon: Icon(Icons.thumb_up_outlined, color: colorScheme.onSurfaceVariant, size: 20),
                    label: Text('Like (${post.likeCount})', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
                  ),
                  TextButton.icon(
                    onPressed: () {
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
                    },
                    icon: Icon(Icons.comment_outlined, color: colorScheme.onSurfaceVariant, size: 20),
                    label: Text('Comment (${post.commentCount})', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.share_outlined, color: colorScheme.onSurfaceVariant, size: 20),
                    label: Text('Share', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        final post = NewsEventPost(
          id: '',
          instituteId: widget.instituteId,
          type: mappedType,
          category: mappedCategory,
          visibility: _visibility,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          authorUid: user.uid,
          authorName: (user.displayName != null && user.displayName!.trim().isNotEmpty) ? user.displayName!.trim() : 'Anonymous User',
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';
    final isEditing = widget.editPost != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: AppSpacing.xl, left: AppSpacing.lg, right: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.md)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? "Edit Post" : "Create Post", style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapLg,
            
            DropdownButtonFormField<String>(
              value: _uiPostType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Post Type', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: 'Experience', child: Text('Experience')),
                const DropdownMenuItem(value: 'Achievement', child: Text('Achievement')),
                const DropdownMenuItem(value: 'Internship', child: Text('Internship')),
                const DropdownMenuItem(value: 'Job Opportunity', child: Text('Job Opportunity')),
                const DropdownMenuItem(value: 'Mentorship', child: Text('Mentorship')),
                const DropdownMenuItem(value: 'Research', child: Text('Research')),
                const DropdownMenuItem(value: 'Career Guidance', child: Text('Career Guidance')),
                const DropdownMenuItem(value: 'Event', child: Text('Event')),
                const DropdownMenuItem(value: 'Hackathon', child: Text('Hackathon')),
                const DropdownMenuItem(value: 'Workshop', child: Text('Workshop')),
                if (isAdmin) const DropdownMenuItem(value: 'News', child: Text('News')),
                if (isAdmin) const DropdownMenuItem(value: 'Announcement', child: Text('Announcement')),
              ],
              onChanged: (val) => setState(() => _uiPostType = val!),
            ),
            AppSpacing.gapMd,

            DropdownButtonFormField<String>(
              value: _visibility,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Visibility', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'alumni_only', child: Text('Alumni Only', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'students_only', child: Text('Students Only', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'admins_only', child: Text('Admins Only', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) => setState(() => _visibility = val!),
            ),
            AppSpacing.gapMd,

            if (isAdmin && _typeMapping[_uiPostType]!['type'] == 'news') ...[
               SwitchListTile(
                 title: Text("Pin Post", style: textTheme.bodyLarge),
                 value: _isPinned,
                 activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
                 activeColor: colorScheme.primary,
                 onChanged: (val) => setState(() => _isPinned = val),
               ),
               AppSpacing.gapMd,
            ],

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            AppSpacing.gapMd,
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            AppSpacing.gapMd,

            if (_typeMapping[_uiPostType]!['type'] == 'event') ...[
              Divider(color: theme.dividerColor),
              AppSpacing.gapSm,
              Text("Event Details", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              AppSpacing.gapMd,
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_eventDate == null ? 'Select Date' : '${_eventDate!.month}/${_eventDate!.day}/${_eventDate!.year}', style: textTheme.bodyLarge),
                trailing: Icon(Icons.calendar_today, color: colorScheme.primary),
                onTap: _pickDate,
              ),
              AppSpacing.gapSm,
              
              TextField(
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                onChanged: (val) => _eventLocation = val,
                controller: TextEditingController(text: _eventLocation),
              ),
              AppSpacing.gapMd,
              
              TextField(
                decoration: const InputDecoration(labelText: 'Max Attendees (Optional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (val) => _maxAttendees = int.tryParse(val),
                controller: TextEditingController(text: _maxAttendees?.toString() ?? ''),
              ),

              CheckboxListTile(
                title: Text("Registration Required", style: textTheme.bodyLarge),
                value: _registrationRequired,
                activeColor: colorScheme.primary,
                onChanged: (val) => setState(() => _registrationRequired = val!),
              ),
              if (_registrationRequired)
                CheckboxListTile(
                  title: Text("Enable Waitlist", style: textTheme.bodyLarge),
                  value: _waitlistEnabled,
                  activeColor: colorScheme.primary,
                  onChanged: (val) => setState(() => _waitlistEnabled = val!),
                ),
              AppSpacing.gapMd,
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: _isLoading ? CircularProgressIndicator(color: colorScheme.onPrimary) : Text(isEditing ? "Save Changes" : "Publish", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            AppSpacing.gapXl,
          ],
        ),
      ),
    );
  }
}
