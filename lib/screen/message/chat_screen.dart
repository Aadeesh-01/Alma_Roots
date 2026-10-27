import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cs261_project/service/chat_service.dart';
import 'package:cs261_project/model/message_model.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String instituteId;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.instituteId,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final ProfileService _profileService;

  late final String _chatId;
  late final String _currentUserId;
  bool _isVerified = false;

  ParticipantModel? _myProfile;
  ParticipantModel? _otherProfile;

  bool _isOtherUserDeleted = false;
  late String _displayOtherUserName;

  late Stream<DocumentSnapshot> _chatDocStream;
  late Stream<List<MessageModel>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _profileService = ProfileService(instituteId: widget.instituteId);

    List<String> ids = [_currentUserId, widget.otherUserId];
    ids.sort();
    _chatId = ids.join('_');

    if (widget.initialMessage != null) {
      _controller.text = widget.initialMessage!;
    }

    _chatDocStream = _firestore
        .collection('institutes')
        .doc(widget.instituteId)
        .collection('chats')
        .doc(_chatId)
        .snapshots();
    _messagesStream = ChatService.streamMessages(widget.instituteId, _chatId);

    _displayOtherUserName = widget.otherUserName;

    _verifyInstituteIsolationAndFetchProfiles();
  }

  Future<void> _verifyInstituteIsolationAndFetchProfiles() async {
    try {
      final futures = await Future.wait([
        _profileService.getProfile(_currentUserId),
        _profileService.getProfile(widget.otherUserId),
      ]);

      _myProfile = futures[0];
      _otherProfile = futures[1];

      if (_myProfile == null || _otherProfile == null) {
        if (!mounted) return;
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text("Cannot start chat: Users are not in the same institute."),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        _isVerified = true;
        _isOtherUserDeleted =
            _otherProfile!.isDeleted || _otherProfile!.status == 'deleted';
        if (_isOtherUserDeleted) {
          _displayOtherUserName = "Deleted User";
        } else {
          _displayOtherUserName = _otherProfile!.name;
        }
      });

      await ChatService.markAsRead(widget.instituteId, _chatId, _currentUserId);
    } catch (e) {
      if (!mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Error verifying chat permissions."),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _sendMessage() async {
    if (!_isVerified || _isOtherUserDeleted) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      await ChatService.sendDirectMessage(
        instituteId: widget.instituteId,
        currentUserId: _currentUserId,
        otherUserId: widget.otherUserId,
        text: text,
      );
      
      if (mounted) {
        setState(() {
          _chatDocStream = _firestore
              .collection('institutes')
              .doc(widget.instituteId)
              .collection('chats')
              .doc(_chatId)
              .snapshots();
          _messagesStream = ChatService.streamMessages(widget.instituteId, _chatId);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to send message"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _sendIntro(String type) async {
    if (!_isVerified || _myProfile == null || _isOtherUserDeleted) return;
    try {
      await ChatService.sendNetworkingIntro(
        instituteId: widget.instituteId,
        currentUserId: _currentUserId,
        otherUserId: widget.otherUserId,
        introType: type,
        profile: _myProfile!,
      );
      
      if (mounted) {
        setState(() {
          _chatDocStream = _firestore
              .collection('institutes')
              .doc(widget.instituteId)
              .collection('chats')
              .doc(_chatId)
              .snapshots();
          _messagesStream = ChatService.streamMessages(widget.instituteId, _chatId);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to send intro"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _showProfilePreview() {
    if (_otherProfile == null || _isOtherUserDeleted) return;
    final p = _otherProfile!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final details = <String>[
      if (p.company?.isNotEmpty == true) p.company!,
      if (p.department?.isNotEmpty == true) p.department!,
      if (p.year?.isNotEmpty == true) 'Class of ${p.year}',
    ];

    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAvatar(name: p.name, imageUrl: p.profileImage, radius: 40, ring: true),
                  const SizedBox(height: 14),
                  Text(p.name, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  RoleBadge(role: p.role),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      details.join('  ·  '),
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (p.isMentor || p.isHiring || p.openToNetworking) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (p.isMentor) _buildBadge('Mentor', AppColors.forest),
                        if (p.isHiring) _buildBadge('Hiring', AppColors.clay),
                        if (p.openToNetworking) _buildBadge('Open to connect', AppColors.goldDeep),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                  instituteId: widget.instituteId,
                                  viewUid: widget.otherUserId),
                            ));
                      },
                      child: const Text('View full profile'),
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }

  Widget _buildBadge(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Color.lerp(color, Colors.white, 0.45)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  void _showMessageOptions(MessageModel msg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMe = msg.senderId == _currentUserId;
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '🎉', '🔥', '👏'].map((emoji) {
                      final hasReacted =
                          msg.reactions[emoji]?.contains(_currentUserId) ??
                              false;
                      return InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.pop(context);
                          if (hasReacted) {
                            ChatService.removeReaction(widget.instituteId,
                                _chatId, msg.id, _currentUserId, emoji);
                          } else {
                            ChatService.addReaction(widget.instituteId, _chatId,
                                msg.id, _currentUserId, emoji);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasReacted
                                ? colorScheme.secondaryContainer
                                : colorScheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasReacted ? AppColors.gold : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit message'),
                    onTap: () {
                      Navigator.pop(context);
                      _editMessagePrompt(msg);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                  title: Text('Delete for me',
                      style: TextStyle(color: colorScheme.error)),
                  onTap: () {
                    Navigator.pop(context);
                    ChatService.deleteMessageForMe(
                        widget.instituteId, _chatId, msg.id, _currentUserId);
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          );
        });
  }

  void _editMessagePrompt(MessageModel msg) {
    final editCtrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              if (editCtrl.text.trim().isNotEmpty &&
                  editCtrl.text != msg.text) {
                ChatService.editMessage(
                    widget.instituteId, _chatId, msg.id, editCtrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 24),
        Center(
          child: AppAvatar(
            name: _displayOtherUserName,
            imageUrl: _isOtherUserDeleted ? null : _otherProfile?.profileImage,
            radius: 40,
            ring: true,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Say hello to ${_displayOtherUserName.split(' ').first}",
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Start with a quick introduction. Pick one below and we'll send it for you.",
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _introChip('Request Mentorship', Icons.volunteer_activism_outlined),
            _introChip('Career Guidance', Icons.explore_outlined),
            _introChip('Referral Request', Icons.badge_outlined),
            _introChip('Project Collaboration', Icons.code_rounded),
          ],
        )
      ],
    );
  }

  Widget _introChip(String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      label: Text(label),
      onPressed: () => _sendIntro(label),
    );
  }

  String _dayLabel(DateTime? t) {
    if (t == null) return 'Today';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(t);
    return DateFormat('d MMMM yyyy').format(t);
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    final x = a ?? DateTime.now();
    final y = b ?? DateTime.now();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Widget _buildDaySeparator(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, MessageModel msg, bool isMe, bool isRead) {
    final colorScheme = theme.colorScheme;
    final timeStr = msg.timestamp == null ? 'Sending…' : DateFormat('h:mm a').format(msg.timestamp!);
    final metaColor = isMe ? colorScheme.onPrimary.withValues(alpha: 0.72) : colorScheme.onSurfaceVariant;

    final reactions = msg.reactions.entries.where((e) => e.value.isNotEmpty).toList();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Container(
          margin: EdgeInsets.fromLTRB(isMe ? 56 : 12, 3, isMe ? 12 : 56, reactions.isEmpty ? 3 : 14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
                decoration: BoxDecoration(
                  color: isMe ? colorScheme.primary : colorScheme.surface,
                  border: isMe ? null : Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.35,
                        color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.isEdited)
                          Text("edited · ", style: TextStyle(fontSize: 10.5, color: metaColor)),
                        Text(timeStr, style: TextStyle(fontSize: 10.5, color: metaColor)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? Icons.done_all_rounded : Icons.check_rounded,
                            size: 15,
                            color: isRead ? AppColors.gold : metaColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (reactions.isNotEmpty)
                Positioned(
                  bottom: -12,
                  right: isMe ? null : 10,
                  left: isMe ? 10 : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in reactions) ...[
                          Text(e.key, style: const TextStyle(fontSize: 12)),
                          if (e.value.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 2, right: 2),
                              child: Text('${e.value.length}',
                                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "Message",
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              tooltip: 'Send',
              style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _isOtherUserDeleted ? null : _showProfilePreview,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                AppAvatar(
                  name: _displayOtherUserName,
                  imageUrl: _isOtherUserDeleted ? null : _otherProfile?.profileImage,
                  radius: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayOtherUserName,
                        style: textTheme.titleSmall?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_otherProfile != null && !_isOtherUserDeleted)
                        Text(
                          '${_otherProfile!.role[0].toUpperCase()}${_otherProfile!.role.substring(1)} · tap for profile',
                          style: textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!_isOtherUserDeleted)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Profile',
              onPressed: _showProfilePreview,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
      ),
      body: !_isVerified
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_myProfile != null &&
                    _otherProfile != null &&
                    !_isOtherUserDeleted)
                  Builder(builder: (context) {
                    List<String> common = [];
                    if (_myProfile!.department != null &&
                        _myProfile!.department == _otherProfile!.department) {
                      common.add("Same department");
                    }
                    if (_myProfile!.year != null &&
                        _myProfile!.year!.isNotEmpty &&
                        _myProfile!.year == _otherProfile!.year) {
                      common.add("Class of ${_myProfile!.year}");
                    }
                    if (common.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hub_outlined, size: 14, color: colorScheme.onSecondaryContainer),
                            const SizedBox(width: 6),
                            Text(common.join(' · '),
                                style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer)),
                          ],
                        ),
                      ),
                    );
                  }),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                      // Listen to parent chat doc to get readStatus
                      stream: _chatDocStream,
                      builder: (context, chatSnapshot) {
                        final chatData =
                            chatSnapshot.data?.data() as Map<String, dynamic>?;
                        final readMap =
                            chatData?['readStatus'] as Map<String, dynamic>? ??
                                {};
                        final otherHasRead =
                            readMap[widget.otherUserId] == true;

                        return StreamBuilder<List<MessageModel>>(
                          stream: _messagesStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return _buildEmptyState();
                            }

                            final allMessages = snapshot.data!;
                            final messages = allMessages
                                .where(
                                    (m) => m.deletedBy[_currentUserId] != true)
                                .toList();

                            if (messages.isEmpty) {
                              return Center(
                                  child: Text("All messages deleted.",
                                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)));
                            }

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe = msg.senderId == _currentUserId;
                                // If the other user has read the chat, everything I sent is read.
                                final isRead = isMe && otherHasRead;

                                // Messages are newest-first; show a day label above the
                                // first message of each day.
                                final older = index + 1 < messages.length ? messages[index + 1] : null;
                                final showDay = older == null || !_sameDay(older.timestamp, msg.timestamp);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (showDay) _buildDaySeparator(theme, _dayLabel(msg.timestamp)),
                                    _buildBubble(theme, msg, isMe, isRead),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      }),
                ),
                if (_isOtherUserDeleted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "This account has been deactivated, so you can't reply.",
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildComposer(theme),
              ],
            ),
    );
  }
}
