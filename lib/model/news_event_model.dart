import 'package:cloud_firestore/cloud_firestore.dart';

class NewsEventPost {
  final String id;
  final String instituteId;
  final String type; // "news", "event", "experience"
  final String category; // placements, hackathons, workshops, alumni_meet, research, announcements, achievements, internships, networking, career_guidance
  final String visibility; // public, alumni_only, students_only, admins_only
  final String title;
  final String description;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String status; // published, deleted
  final List<String> searchKeywords;
  
  // Event Specific
  final DateTime? eventDate;
  final String? eventLocation;
  final String? eventStatus; // upcoming, ongoing, past
  final bool registrationRequired;
  final DateTime? registrationDeadline;
  final bool waitlistEnabled;
  final int attendeeCount;
  final int? maxAttendees;
  
  // Media & Engagement
  final List<String> mediaUrls;
  final int likeCount;
  final int commentCount;

  // Legacy fields preserved for UI compatibility during migration, to be removed later
  final String imageUrl;

  NewsEventPost({
    required this.id,
    required this.instituteId,
    required this.type,
    this.category = 'announcements',
    this.visibility = 'public',
    required this.title,
    required this.description,
    required this.authorUid,
    required this.authorName,
    this.authorRole = 'student',
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.status = 'published',
    this.searchKeywords = const [],
    this.eventDate,
    this.eventLocation,
    this.eventStatus,
    this.registrationRequired = false,
    this.registrationDeadline,
    this.waitlistEnabled = false,
    this.attendeeCount = 0,
    this.maxAttendees,
    this.mediaUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.imageUrl = '', // legacy
  });

  factory NewsEventPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NewsEventPost(
      id: doc.id,
      instituteId: data['instituteId'] ?? '',
      type: data['type'] ?? 'news',
      category: data['category'] ?? 'announcements',
      visibility: data['visibility'] ?? 'public',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      authorUid: data['authorUid'] ?? data['createdBy'] ?? '', // fallback for legacy
      authorName: data['authorName'] ?? data['createdByName'] ?? '', // fallback
      authorRole: data['authorRole'] ?? 'student',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPinned: data['isPinned'] ?? false,
      status: data['status'] ?? 'published',
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      eventLocation: data['eventLocation'],
      eventStatus: data['eventStatus'],
      registrationRequired: data['registrationRequired'] ?? false,
      registrationDeadline: (data['registrationDeadline'] as Timestamp?)?.toDate(),
      waitlistEnabled: data['waitlistEnabled'] ?? false,
      attendeeCount: data['attendeeCount'] ?? 0,
      maxAttendees: data['maxAttendees'],
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      likeCount: data['likeCount'] ?? (data['likes'] as List?)?.length ?? 0, // fallback
      commentCount: data['commentCount'] ?? (data['comments'] as List?)?.length ?? 0, // fallback
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'instituteId': instituteId,
      'type': type,
      'category': category,
      'visibility': visibility,
      'title': title,
      'description': description,
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPinned': isPinned,
      'status': status,
      'searchKeywords': searchKeywords,
      'eventDate': eventDate,
      'eventLocation': eventLocation,
      'eventStatus': eventStatus,
      'registrationRequired': registrationRequired,
      'registrationDeadline': registrationDeadline,
      'waitlistEnabled': waitlistEnabled,
      'attendeeCount': attendeeCount,
      if (maxAttendees != null) 'maxAttendees': maxAttendees,
      'mediaUrls': mediaUrls,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'imageUrl': imageUrl,
    };
  }
}
