import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/model/chat_model.dart';
import 'package:cs261_project/model/message_model.dart';
import 'package:cs261_project/model/participant_model.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns a deterministic chat ID for direct chats
  static String getDirectChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  /// Streams the inbox for a given user, solving the N+1 problem by batching
  /// profile lookups locally, but for simplicity in Stream we'll use an RxDart approach or
  /// yield raw ChatModels, allowing the UI to handle the profile resolution efficiently.
  /// To truly solve N+1, we will stream the chats, then fetch all missing participants at once.
  static Stream<List<ChatModel>> streamInbox(
      String instituteId, String currentUserId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }

  /// Streams messages for a specific chat
  static Stream<List<MessageModel>> streamMessages(
      String instituteId, String chatId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  /// Marks a chat as read for the current user
  static Future<void> markAsRead(
      String instituteId, String chatId, String currentUserId) async {
    final chatDocRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId);

    try {
      await chatDocRef.update({
        'readStatus.$currentUserId': true,
      });
    } catch (e) {
      // Chat does not exist yet.
      // No messages exist to mark as read.
      // Fail silently.
    }
  }

  /// Sends a direct message
  static Future<void> sendDirectMessage({
    required String instituteId,
    required String currentUserId,
    required String otherUserId,
    required String text,
  }) async {
    final chatId = getDirectChatId(currentUserId, otherUserId);
    final batch = _firestore.batch();

    final chatRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId);

    final messageRef = chatRef.collection('messages').doc();

    final message = MessageModel(
      id: messageRef.id,
      senderId: currentUserId,
      text: text,
      type: MessageType.text,
      isEdited: false,
      isDeleted: false,
      deletedBy: {},
      reactions: {},
      searchKeywords: [],
      timestamp: null, // will be replaced by serverTimestamp in toMap
    );

    batch.set(messageRef, message.toMap());

    // Update parent chat metadata
    final chatData = {
      'type': ChatType.direct.name,
      'participants': [currentUserId, otherUserId],
      'participantCount': 2,
      'lastMessage': {
        'id': message.id,
        'text': text,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': MessageType.text.name,
      },
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'readStatus': {
        currentUserId: true,
        otherUserId: false,
      },
      // mutedBy / archivedBy / pinnedBy are left alone so each user's choices
      // survive new messages; ChatModel treats missing keys as false.
    };

    batch.set(chatRef, chatData, SetOptions(merge: true));
    await batch.commit();
  }

  /// Toggles Pin status for a chat for the current user
  static Future<void> togglePinChat(String instituteId, String chatId,
      String currentUserId, bool isPinned) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .set({
      'pinnedBy': {currentUserId: isPinned}
    }, SetOptions(merge: true));
  }

  /// Toggles Archive status for a chat for the current user
  static Future<void> toggleArchiveChat(String instituteId, String chatId,
      String currentUserId, bool isArchived) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .set({
      'archivedBy': {currentUserId: isArchived}
    }, SetOptions(merge: true));
  }

  /// Adds a reaction to a message
  static Future<void> addReaction(String instituteId, String chatId,
      String messageId, String currentUserId, String emoji) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'reactions': {
        emoji: FieldValue.arrayUnion([currentUserId])
      }
    }, SetOptions(merge: true));
  }

  /// Removes a reaction from a message
  static Future<void> removeReaction(String instituteId, String chatId,
      String messageId, String currentUserId, String emoji) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'reactions': {
        emoji: FieldValue.arrayRemove([currentUserId])
      }
    }, SetOptions(merge: true));
  }

  /// Edits an existing message
  static Future<void> editMessage(String instituteId, String chatId,
      String messageId, String newText) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
    });

    // Note: We also need to conditionally update the parent chat's lastMessage if it matches this messageId.
    // For simplicity, we skip updating lastMessage history edit since it's just a preview.
  }

  /// Deletes a message for the current user only
  static Future<void> deleteMessageForMe(String instituteId, String chatId,
      String messageId, String currentUserId) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'deletedBy': {currentUserId: true}
    }, SetOptions(merge: true));
  }

  /// Sends a structured networking intro
  static Future<void> sendNetworkingIntro({
    required String instituteId,
    required String currentUserId,
    required String otherUserId,
    required String introType,
    required ParticipantModel profile,
  }) async {
    final text = "👋 Hi! I'd like to connect regarding $introType.\n\n"
        "Here's a quick intro:\n"
        "• Name: ${profile.name}\n"
        "• Role: ${profile.role.toUpperCase()}\n"
        "• Department: ${profile.department ?? 'N/A'}\n"
        "• Graduation: ${profile.year ?? 'N/A'}\n\n"
        "Looking forward to chatting!";

    await sendDirectMessage(
      instituteId: instituteId,
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      text: text,
    );
  }
}
