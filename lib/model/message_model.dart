import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, document, system }

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final String? attachmentUrl;
  final Map<String, dynamic>? attachmentMetadata;
  final DateTime? timestamp;
  final bool isEdited;
  final bool isDeleted;
  final Map<String, bool> deletedBy;
  final String? replyToMessageId;
  final Map<String, List<String>> reactions;
  final List<String> searchKeywords;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    this.attachmentUrl,
    this.attachmentMetadata,
    this.timestamp,
    required this.isEdited,
    required this.isDeleted,
    required this.deletedBy,
    this.replyToMessageId,
    required this.reactions,
    required this.searchKeywords,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    MessageType msgType = MessageType.text;
    if (data['type'] == 'image') msgType = MessageType.image;
    if (data['type'] == 'document') msgType = MessageType.document;
    if (data['type'] == 'system') msgType = MessageType.system;

    Map<String, List<String>> parseReactions() {
      if (data['reactions'] == null) return {};
      final map = data['reactions'] as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, List<String>.from(v ?? [])));
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      type: msgType,
      attachmentUrl: data['attachmentUrl'],
      attachmentMetadata: data['attachmentMetadata'] as Map<String, dynamic>?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      deletedBy: (data['deletedBy'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool? ?? false)) ?? {},
      replyToMessageId: data['replyToMessageId'],
      reactions: parseReactions(),
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'attachmentUrl': attachmentUrl,
      'attachmentMetadata': attachmentMetadata,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'deletedBy': deletedBy,
      'replyToMessageId': replyToMessageId,
      'reactions': reactions,
      'searchKeywords': searchKeywords,
    };
  }
}
