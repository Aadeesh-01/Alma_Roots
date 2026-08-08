import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { direct, group, channel, broadcast }

class ChatModel {
  final String id;
  final ChatType type;
  final String? name;
  final String? description;
  final String? imageUrl;
  final List<String> adminIds;
  final List<String> participants;
  final int participantCount;
  final Map<String, dynamic>? lastMessage;
  final DateTime? lastMessageTimestamp;
  final Map<String, bool> readStatus;
  final Map<String, bool> mutedBy;
  final Map<String, bool> archivedBy;
  final Map<String, bool> pinnedBy;

  ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.imageUrl,
    required this.adminIds,
    required this.participants,
    required this.participantCount,
    this.lastMessage,
    this.lastMessageTimestamp,
    required this.readStatus,
    required this.mutedBy,
    required this.archivedBy,
    required this.pinnedBy,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    // Safety mapping for type enum
    ChatType chatType = ChatType.direct;
    if (data['type'] == 'group') chatType = ChatType.group;
    if (data['type'] == 'channel') chatType = ChatType.channel;
    if (data['type'] == 'broadcast') chatType = ChatType.broadcast;

    // Safety mapping for maps to handle nulls gracefully
    Map<String, bool> parseMap(String key) {
      if (data[key] == null) return {};
      final map = data[key] as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as bool? ?? false));
    }

    return ChatModel(
      id: doc.id,
      type: chatType,
      name: data['name'],
      description: data['description'],
      imageUrl: data['imageUrl'],
      adminIds: List<String>.from(data['adminIds'] ?? []),
      participants: List<String>.from(data['participants'] ?? []),
      participantCount: data['participantCount'] ?? 0,
      lastMessage: data['lastMessage'] as Map<String, dynamic>?,
      lastMessageTimestamp: (data['lastMessageTimestamp'] as Timestamp?)?.toDate(),
      readStatus: parseMap('readStatus'),
      mutedBy: parseMap('mutedBy'),
      archivedBy: parseMap('archivedBy'),
      pinnedBy: parseMap('pinnedBy'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'adminIds': adminIds,
      'participants': participants,
      'participantCount': participantCount,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp != null 
          ? Timestamp.fromDate(lastMessageTimestamp!) 
          : null,
      'readStatus': readStatus,
      'mutedBy': mutedBy,
      'archivedBy': archivedBy,
      'pinnedBy': pinnedBy,
    };
  }
}
