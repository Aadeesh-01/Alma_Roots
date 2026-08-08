import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cs261_project/service/chat_service.dart';
import 'package:cs261_project/model/message_model.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cs261_project/theme/app_spacing.dart';

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
  final DateFormat _timeFormat = DateFormat('hh:mm a');
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

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.profileImage != null)
                  CachedNetworkImage(
                    imageUrl: p.profileImage!,
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 40,
                      backgroundImage: imageProvider,
                    ),
                    placeholder: (context, url) => CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.dividerColor,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.dividerColor,
                      child: Icon(Icons.error, color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.dividerColor,
                    child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface)),
                  ),
                const SizedBox(height: 16),
                Text(p.name,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(p.role.toUpperCase(),
                    style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                if (p.department != null || p.year != null)
                  Text('${p.department ?? ""} ${p.year ?? ""}'.trim(),
                      style: textTheme.bodyLarge),
                if (p.company != null)
                  Text('At: ${p.company}',
                      style: textTheme.bodyLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (p.isMentor) _buildBadge('Mentor', colorScheme.primary),
                    if (p.isHiring) _buildBadge('Hiring', colorScheme.tertiary),
                    if (p.openToNetworking)
                      _buildBadge('Open to Connect', colorScheme.secondary),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary),
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
                    child: const Text('View Full Profile'),
                  ),
                )
              ],
            ),
          );
        });
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '🎉', '🔥', '👏'].map((emoji) {
                      final hasReacted =
                          msg.reactions[emoji]?.contains(_currentUserId) ??
                              false;
                      return InkWell(
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
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : theme.dividerColor,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit Message'),
                    onTap: () {
                      Navigator.pop(context);
                      _editMessagePrompt(msg);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete, color: colorScheme.error),
                  title: Text('Delete for me',
                      style: TextStyle(color: colorScheme.error)),
                  onTap: () {
                    Navigator.pop(context);
                    ChatService.deleteMessageForMe(
                        widget.instituteId, _chatId, msg.id, _currentUserId);
                  },
                ),
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
        title: const Text('Edit Message'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.handshake, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text("Start Networking",
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Send a quick introduction to connect with $_displayOtherUserName.",
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _introChip('Request Mentorship', Icons.school),
              _introChip('Career Guidance', Icons.work),
              _introChip('Referral Request', Icons.badge),
              _introChip('Project Collaboration', Icons.code),
            ],
          )
        ],
      ),
    );
  }

  Widget _introChip(String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ActionChip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(label),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3))),
      onPressed: () => _sendIntro(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        shadowColor: theme.dividerColor,
        title: Row(
          children: [
            if (_otherProfile?.profileImage != null && !_isOtherUserDeleted)
              CachedNetworkImage(
                imageUrl: _otherProfile!.profileImage!,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.error, color: colorScheme.primary, size: 16),
                ),
              )
            else
              CircleAvatar(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  _displayOtherUserName.isNotEmpty
                      ? _displayOtherUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayOtherUserName,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  if (_otherProfile != null && !_isOtherUserDeleted)
                    Text(
                      _otherProfile!.role.toUpperCase(),
                      style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (!_isOtherUserDeleted)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showProfilePreview,
            ),
        ],
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
                      common.add("Same Dept");
                    }
                    if (_myProfile!.year != null &&
                        _myProfile!.year == _otherProfile!.year) {
                      common.add("Class of ${_myProfile!.year}");
                    }
                    if (common.isEmpty) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hub, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(common.join(' • '),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                        ],
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
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe = msg.senderId == _currentUserId;

                                final timeStr = msg.timestamp == null
                                    ? 'Sending...'
                                    : _timeFormat.format(msg.timestamp!);

                                // Determine tick status
                                // We consider it "read" if the parent chat readStatus for other user is true
                                // AND this message was sent before the chat's lastMessageTimestamp.
                                // For simplicity, if otherHasRead is true, all messages sent by me are considered read.
                                final isRead = isMe && otherHasRead;

                                // Build reactions row
                                List<Widget> reactionWidgets = [];
                                msg.reactions.forEach((emoji, uids) {
                                  if (uids.isNotEmpty) {
                                    reactionWidgets.add(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(
                                          right: 4, top: 4),
                                      decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: theme.dividerColor)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(emoji,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          if (uids.length > 1)
                                            Text(' ${uids.length}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: colorScheme.onSurfaceVariant)),
                                        ],
                                      ),
                                    ));
                                  }
                                });

                                return Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: GestureDetector(
                                    onLongPress: () => _showMessageOptions(msg),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 12),
                                      constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75),
                                      child: Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? colorScheme.primary
                                                  : colorScheme.surfaceContainerHighest,
                                              border: Border.all(
                                                color: isMe ? colorScheme.primary : theme.dividerColor,
                                              ),
                                              borderRadius: BorderRadius.only(
                                                topLeft:
                                                    const Radius.circular(16),
                                                topRight:
                                                    const Radius.circular(16),
                                                bottomLeft: isMe
                                                    ? const Radius.circular(16)
                                                    : const Radius.circular(0),
                                                bottomRight: isMe
                                                    ? const Radius.circular(0)
                                                    : const Radius.circular(16),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  msg.text,
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      color: isMe
                                                          ? colorScheme.onPrimary
                                                          : colorScheme.onSurface),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (msg.isEdited)
                                                      Text("(edited) ",
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color: isMe
                                                                  ? colorScheme.onPrimary.withValues(alpha: 0.7)
                                                                  : colorScheme.onSurfaceVariant)),
                                                    Text(
                                                      timeStr,
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: isMe
                                                              ? colorScheme.onPrimary.withValues(alpha: 0.7)
                                                              : colorScheme.onSurfaceVariant),
                                                    ),
                                                    if (isMe) ...[
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        isRead
                                                            ? Icons.done_all
                                                            : Icons.check,
                                                        size: 14,
                                                        color: isRead
                                                            ? colorScheme.onPrimary
                                                            : colorScheme.onPrimary.withValues(alpha: 0.7),
                                                      )
                                                    ]
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                          if (reactionWidgets.isNotEmpty)
                                            Wrap(children: reactionWidgets),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }),
                ),
                if (_isOtherUserDeleted)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: colorScheme.surface,
                    child: Center(
                      child: Text(
                        "You cannot reply to this conversation because the user's account has been deactivated.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: "Type a message...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                          AppSpacing.gapSm,
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: colorScheme.primary,
                            child: IconButton(
                              icon: Icon(Icons.send, color: colorScheme.onPrimary),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
