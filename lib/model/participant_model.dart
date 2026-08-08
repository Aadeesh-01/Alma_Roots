import 'package:cloud_firestore/cloud_firestore.dart';

class ParticipantModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String instituteId;
  final String? profileImage;
  
  // Student Specific
  final String? rollNo;
  final String? department;
  
  // Student & Alumni
  final String? year;
  final String? interest; // Also used as skills for Alumni
  final String? bio;

  // Alumni Specific
  final String? company;

  final bool isProfileComplete;
  final List<String> searchKeywords;
  
  // Networking Specific
  final bool isMentor;
  final bool isHiring;
  final bool openToNetworking;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // Soft Delete & Status
  final bool isDeleted;
  final Timestamp? deletedAt;
  final String? deletedBy;
  final String status; // active, suspended, deleted, pending, permanently_deleted

  // Permanent Delete Fields
  final bool pendingPermanentDeletion;
  final Timestamp? permanentDeletionRequestedAt;
  final Timestamp? permanentDeletionScheduledFor;
  final String? permanentDeletionRequestedBy;

  ParticipantModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.instituteId,
    this.profileImage,
    this.rollNo,
    this.department,
    this.year,
    this.interest,
    this.bio,
    this.company,
    this.isProfileComplete = false,
    this.searchKeywords = const [],
    this.isMentor = false,
    this.isHiring = false,
    this.openToNetworking = false,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.status = 'active',
    this.pendingPermanentDeletion = false,
    this.permanentDeletionRequestedAt,
    this.permanentDeletionScheduledFor,
    this.permanentDeletionRequestedBy,
  });

  factory ParticipantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Support legacy field names for backward compatibility
    final pic = data['profileImage'] ?? data['picture'];
    final skills = data['interest'] ?? data['skills'];

    return ParticipantModel(
      uid: data['uid'] ?? doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      instituteId: data['instituteId'] ?? '',
      profileImage: pic,
      rollNo: data['rollNo'],
      department: data['department'],
      year: data['year'],
      interest: skills,
      bio: data['bio'],
      company: data['company'],
      isProfileComplete: data['isProfileComplete'] ?? false,
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      isMentor: data['isMentor'] ?? false,
      isHiring: data['isHiring'] ?? false,
      openToNetworking: data['openToNetworking'] ?? false,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      isDeleted: data['isDeleted'] ?? false,
      deletedAt: data['deletedAt'] as Timestamp?,
      deletedBy: data['deletedBy'],
      status: data['status'] ?? 'active',
      pendingPermanentDeletion: data['pendingPermanentDeletion'] ?? false,
      permanentDeletionRequestedAt: data['permanentDeletionRequestedAt'] as Timestamp?,
      permanentDeletionScheduledFor: data['permanentDeletionScheduledFor'] as Timestamp?,
      permanentDeletionRequestedBy: data['permanentDeletionRequestedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'instituteId': instituteId,
      'profileImage': profileImage,
      'rollNo': rollNo,
      'department': department,
      'year': year,
      'interest': interest,
      'bio': bio,
      'company': company,
      'isProfileComplete': isProfileComplete,
      'searchKeywords': searchKeywords,
      'isMentor': isMentor,
      'isHiring': isHiring,
      'openToNetworking': openToNetworking,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (deletedBy != null) 'deletedBy': deletedBy,
      'status': status,
      'pendingPermanentDeletion': pendingPermanentDeletion,
      if (permanentDeletionRequestedAt != null) 'permanentDeletionRequestedAt': permanentDeletionRequestedAt,
      if (permanentDeletionScheduledFor != null) 'permanentDeletionScheduledFor': permanentDeletionScheduledFor,
      if (permanentDeletionRequestedBy != null) 'permanentDeletionRequestedBy': permanentDeletionRequestedBy,
    };
  }
}
