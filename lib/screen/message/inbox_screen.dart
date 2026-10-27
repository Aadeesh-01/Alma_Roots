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
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';

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

  String _relativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat('h:mm a').format(dateTime);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(dateTime);
    return DateFormat('d MMM').format(dateTime);
  }

  void _openNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartConversationScreen(instituteId: widget.instituteId),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final (IconData icon, String title, String message) = _searchQuery.isNotEmpty
        ? (Icons.search_off_rounded, 'No matches', 'No conversations match "$_searchQuery".')
        : _showArchived
            ? (Icons.inventory_2_outlined, 'Nothing archived', 'Swipe a conversation left to archive it.')
            : (Icons.forum_outlined, 'No conversations yet', 'Reach out to alumni, mentors and classmates.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: colorScheme.secondaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (_searchQuery.isEmpty && !_showArchived) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openNewChat,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Start a conversation'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: colorScheme.surfaceContainerHigh,
          highlightColor: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const CircleAvatar(radius: 26, backgroundColor: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final unread = _totalUnreadCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _updateDisplayChats();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search conversations',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colorScheme.primary,
                selectedForegroundColor: colorScheme.onPrimary,
                side: BorderSide(color: colorScheme.outlineVariant),
                textStyle: theme.textTheme.labelLarge,
              ),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(unread > 0 ? 'Chats · $unread new' : 'Chats'),
                ),
                const ButtonSegment(
                  value: true,
                  icon: Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text('Archived'),
                ),
              ],
              selected: {_showArchived},
              onSelectionChanged: (s) {
                setState(() {
                  _showArchived = s.first;
                  _updateDisplayChats();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRow(ThemeData theme, ChatModel chat) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final otherUserId = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );

    final isUnread = chat.readStatus[_currentUserId] == false;
    final isPinned = chat.pinnedBy[_currentUserId] == true;
    final isArchived = chat.archivedBy[_currentUserId] == true;
    final userData = _userCache[otherUserId];
    final userName = (userData?.name.isNotEmpty ?? false) ? userData!.name : 'Member';
    final isMine = chat.lastMessage?['senderId'] == _currentUserId;
    final lastMsgText = chat.lastMessage?['text'] ?? '';

    return Slidable(
      key: ValueKey(chat.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) {
              ChatService.togglePinChat(widget.instituteId, chat.id, _currentUserId, !isPinned);
            },
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.forestDeep,
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            label: isPinned ? 'Unpin' : 'Pin',
          ),
          SlidableAction(
            onPressed: (_) {
              ChatService.toggleArchiveChat(widget.instituteId, chat.id, _currentUserId, !isArchived);
            },
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: isArchived ? 'Restore' : 'Archive',
          ),
        ],
      ),
      child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(name: userName, imageUrl: userData?.profileImage, radius: 26),
                  if (isUnread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPinned) ...[
                          const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.gold),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _relativeTime(chat.lastMessageTimestamp),
                          style: textTheme.bodySmall?.copyWith(
                            color: isUnread ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isMine ? 'You: $lastMsgText' : lastMsgText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                        color: isUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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

    return Scaffold(
      appBar: widget.isNested ? null : AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : _displayChats.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _displayChats.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 84,
                          endIndent: 16,
                          color: colorScheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) => _buildChatRow(theme, _displayChats[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _openNewChat,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New chat'),
      ),
    );
  }
}
