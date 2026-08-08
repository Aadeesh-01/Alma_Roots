import 'dart:async';
import 'package:cs261_project/screen/message/chat_screen.dart';
import 'package:cs261_project/service/chat_service.dart';
import 'package:cs261_project/model/chat_model.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cs261_project/screen/message/start_conversation_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cs261_project/theme/app_spacing.dart';

class InboxScreen extends StatefulWidget {
  final String instituteId;
  final bool isNested;
  const InboxScreen({super.key, required this.instituteId, this.isNested = false});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final String _currentUserId;
  late final ProfileService _profileService;
  
  final Map<String, ParticipantModel> _userCache = {};
  List<ChatModel> _chats = [];
  bool _isLoading = true;
  StreamSubscription? _inboxSub;

  bool _showArchived = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  List<ChatModel> _displayChats = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _profileService = ProfileService(instituteId: widget.instituteId);
    _initInboxStream();
  }

  void _initInboxStream() {
    _inboxSub = ChatService.streamInbox(widget.instituteId, _currentUserId).listen((chats) async {
      // 1. Find missing profiles
      final Set<String> missingUids = {};
      for (var chat in chats) {
        final otherId = chat.participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );
        if (otherId.isNotEmpty && !_userCache.containsKey(otherId)) {
          missingUids.add(otherId);
        }
      }

      // 2. Fetch missing profiles concurrently
      if (missingUids.isNotEmpty) {
        final futures = missingUids.map((uid) async {
          final profile = await _profileService.getProfile(uid);
          if (profile != null) {
            _userCache[uid] = profile;
          }
        });
        await Future.wait(futures);
      }

      // 3. Update UI
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
          _updateDisplayChats();
        });
      }
    }, onError: (e) {
      debugPrint("Inbox stream error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _inboxSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _timeFormat.format(dateTime);
  }

  void _updateDisplayChats() {
    var list = _chats.where((c) {
      final isArchived = c.archivedBy[_currentUserId] == true;
      if (_showArchived && !isArchived) return false;
      if (!_showArchived && isArchived) return false;
      
      if (_searchQuery.isNotEmpty) {
        final otherUserId = c.participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
        final name = _userCache[otherUserId]?.name.toLowerCase() ?? '';
        final msg = (c.lastMessage?['text'] as String?)?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || msg.contains(query);
      }
      return true;
    }).toList();
    
    list.sort((a, b) {
      final aPinned = a.pinnedBy[_currentUserId] == true;
      final bPinned = b.pinnedBy[_currentUserId] == true;
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      
      final aTime = a.lastMessageTimestamp ?? DateTime(2000);
      final bTime = b.lastMessageTimestamp ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    
    _displayChats = list;
  }

  int get _totalUnreadCount {
    return _chats.where((c) => c.readStatus[_currentUserId] == false && c.archivedBy[_currentUserId] != true).length;
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : (_showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline),
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          AppSpacing.gapMd,
          Text(
            _searchQuery.isNotEmpty 
                ? "No results found" 
                : (_showArchived ? "No archived chats" : "No conversations yet"),
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surfaceContainerHighest,
          highlightColor: theme.colorScheme.surface,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: colorScheme.surface),
            title: Container(
              height: 16,
              width: 150,
              color: colorScheme.surface,
            ),
            subtitle: Container(
              height: 12,
              width: double.infinity,
              color: colorScheme.surface,
              margin: const EdgeInsets.only(top: 8),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.isNested ? null : AppBar(
        title: Row(
          children: [
            const Text('Messages'),
            if (_totalUnreadCount > 0) ...[
              AppSpacing.gapSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalUnreadCount',
                  style: TextStyle(color: colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ]
          ],
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
                _updateDisplayChats();
              });
            },
            tooltip: _showArchived ? 'View Active' : 'View Archived',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _updateDisplayChats();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search messages',
                      prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    ),
                  ),
                ),
                if (widget.isNested) ...[
                  AppSpacing.gapSm,
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: IconButton(
                      icon: Icon(_showArchived ? Icons.unarchive : Icons.archive, color: colorScheme.onSurfaceVariant),
                      onPressed: () {
                        setState(() {
                          _showArchived = !_showArchived;
                          _updateDisplayChats();
                        });
                      },
                      tooltip: _showArchived ? 'View Active' : 'View Archived',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_showArchived)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: colorScheme.tertiary.withValues(alpha: 0.1),
              child: Text(
                'Viewing Archived Chats',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.tertiary, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : _displayChats.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _displayChats.length,
                        itemBuilder: (context, index) {
                          final chat = _displayChats[index];
                          final otherUserId = chat.participants.firstWhere(
                            (id) => id != _currentUserId,
                            orElse: () => '',
                          );

                          final isUnread = chat.readStatus[_currentUserId] == false;
                          final isPinned = chat.pinnedBy[_currentUserId] == true;
                          final isArchived = chat.archivedBy[_currentUserId] == true;
                          final userData = _userCache[otherUserId];
                          final userName = userData?.name ?? 'Unknown User';
                          
                          final lastMsgText = chat.lastMessage?['text'] ?? '';
                          final lastMsgTime = chat.lastMessageTimestamp;

                          return Slidable(
                            key: ValueKey(chat.id),
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    ChatService.togglePinChat(widget.instituteId, chat.id, _currentUserId, !isPinned);
                                  },
                                  backgroundColor: colorScheme.secondary,
                                  foregroundColor: colorScheme.onSecondary,
                                  icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                  label: isPinned ? 'Unpin' : 'Pin',
                                ),
                                SlidableAction(
                                  onPressed: (_) {
                                    ChatService.toggleArchiveChat(widget.instituteId, chat.id, _currentUserId, !isArchived);
                                  },
                                  backgroundColor: colorScheme.onSurfaceVariant,
                                  foregroundColor: colorScheme.surface,
                                  icon: isArchived ? Icons.unarchive : Icons.archive,
                                  label: isArchived ? 'Unarchive' : 'Archive',
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isUnread ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surface,
                                border: isUnread 
                                  ? Border(left: BorderSide(color: colorScheme.primary, width: 4))
                                  : null,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                                leading: Stack(
                                  children: [
                                    if (userData?.profileImage != null)
                                      CachedNetworkImage(
                                        imageUrl: userData!.profileImage!,
                                        imageBuilder: (context, imageProvider) => CircleAvatar(
                                          backgroundColor: theme.dividerColor,
                                          backgroundImage: imageProvider,
                                          radius: 24,
                                        ),
                                        placeholder: (context, url) => CircleAvatar(
                                          backgroundColor: theme.dividerColor,
                                          radius: 24,
                                        ),
                                        errorWidget: (context, url, error) => CircleAvatar(
                                          backgroundColor: theme.dividerColor,
                                          radius: 24,
                                          child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
                                        ),
                                      )
                                    else
                                      CircleAvatar(
                                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                        radius: 24,
                                        child: Text(
                                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        userName,
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isPinned)
                                      Icon(Icons.push_pin, size: 14, color: colorScheme.onSurfaceVariant),
                                  ],
                                ),
                                subtitle: Text(
                                  lastMsgText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                    color: isUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTime(lastMsgTime),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isUnread ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      AppSpacing.gapXs,
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    ]
                                  ],
                                ),
                                onTap: () {
                                  ChatService.markAsRead(widget.instituteId, chat.id, _currentUserId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        otherUserId: otherUserId,
                                        otherUserName: userName,
                                        instituteId: widget.instituteId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StartConversationScreen(instituteId: widget.instituteId),
            ),
          );
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.message),
      ),
    );
  }
}
