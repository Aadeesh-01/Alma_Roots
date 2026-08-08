import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Soft deletes a user
  static Future<void> softDeleteUser({
    required String instituteId,
    required String targetUid,
    required String targetEmail,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Admin must be logged in.");
    if (currentUser.uid == targetUid) throw Exception("Admins cannot delete themselves.");

    final participantRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('participants')
        .doc(targetUid);

    // Verify user exists and is not super admin
    final doc = await participantRef.get();
    if (!doc.exists) throw Exception("User not found.");
    if (doc.data()?['role'] == 'admin') throw Exception("Cannot delete another admin.");

    final batch = _firestore.batch();

    // 1. Update participant document
    batch.update(participantRef, {
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': currentUser.uid,
      'status': 'deleted',
    });

    // 2. Audit Logging
    final auditRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('admin_actions')
        .doc();

    batch.set(auditRef, {
      'adminUid': currentUser.uid,
      'adminEmail': currentUser.email,
      'targetUid': targetUid,
      'targetEmail': targetEmail,
      'action': 'USER_SOFT_DELETED',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Restores a soft-deleted user
  static Future<void> restoreUser({
    required String instituteId,
    required String targetUid,
    required String targetEmail,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Admin must be logged in.");

    final participantRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('participants')
        .doc(targetUid);

    final batch = _firestore.batch();

    // 1. Update participant document
    batch.update(participantRef, {
      'isDeleted': false,
      'deletedAt': null,
      'deletedBy': null,
      'status': 'active',
    });

    // 2. Audit Logging
    final auditRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('admin_actions')
        .doc();

    batch.set(auditRef, {
      'adminUid': currentUser.uid,
      'adminEmail': currentUser.email,
      'targetUid': targetUid,
      'targetEmail': targetEmail,
      'action': 'USER_RESTORED',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// User requests reactivation
  static Future<void> requestReactivation({
    required String instituteId,
    required String userUid,
    required String userEmail,
    required String userName,
  }) async {
    final requestRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('reactivation_requests')
        .doc(userUid); // Use userUid as requestId to easily prevent duplicates

    final doc = await requestRef.get();
    if (doc.exists && doc.data()?['status'] == 'pending') {
      throw Exception("You already have a pending reactivation request.");
    }

    await requestRef.set({
      'userUid': userUid,
      'userEmail': userEmail,
      'userName': userName,
      'instituteId': instituteId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Admin approves a reactivation request
  static Future<void> approveReactivation({
    required String instituteId,
    required String requestId,
    required String targetUid,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Admin must be logged in.");

    final requestRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('reactivation_requests')
        .doc(requestId);

    final participantRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('participants')
        .doc(targetUid);

    final batch = _firestore.batch();

    batch.update(participantRef, {
      'isDeleted': false,
      'status': 'active',
      'deletedAt': null,
      'deletedBy': null,
    });

    batch.update(requestRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': currentUser.uid,
    });

    final auditRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('admin_actions')
        .doc();

    batch.set(auditRef, {
      'adminUid': currentUser.uid,
      'adminEmail': currentUser.email,
      'targetUid': targetUid,
      'action': 'USER_RESTORED',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Admin rejects a reactivation request
  static Future<void> rejectReactivation({
    required String instituteId,
    required String requestId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Admin must be logged in.");

    final requestRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('reactivation_requests')
        .doc(requestId);

    await requestRef.update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': currentUser.uid,
    });
  }

  /// Admin schedules a permanent deletion (adds to queue)
  static Future<void> schedulePermanentDeletion({
    required String instituteId,
    required String targetUid,
    required String targetEmail,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Admin must be logged in.");
    if (currentUser.uid == targetUid) throw Exception("Admins cannot delete themselves.");

    final participantRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('participants')
        .doc(targetUid);

    final doc = await participantRef.get();
    if (!doc.exists) throw Exception("User not found.");
    if (doc.data()?['role'] == 'admin') throw Exception("Cannot delete another admin.");
    if (doc.data()?['isDeleted'] != true) throw Exception("User must be soft-deleted first.");
    if (doc.data()?['pendingPermanentDeletion'] == true) throw Exception("User is already scheduled for permanent deletion.");

    final queueRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('deletion_queue')
        .doc(targetUid); // using targetUid as doc id to prevent duplicates

    final batch = _firestore.batch();
    
    final now = FieldValue.serverTimestamp();
    // In Dart we use a DateTime to compute 24h from now to store in Firestore.
    // However, FieldValue.serverTimestamp() cannot be manipulated in Dart easily before saving.
    // So we use DateTime.now() instead.
    final scheduledDate = DateTime.now().add(const Duration(hours: 24));
    final scheduledTimestamp = Timestamp.fromDate(scheduledDate);
    final nowTimestamp = Timestamp.now();

    // 1. Add to Deletion Queue
    batch.set(queueRef, {
      'uid': targetUid,
      'email': targetEmail,
      'instituteId': instituteId,
      'scheduledFor': scheduledTimestamp,
      'requestedBy': currentUser.uid,
      'requestedAt': nowTimestamp,
      'status': 'pending',
    });

    // 2. Update Participant Doc
    batch.update(participantRef, {
      'pendingPermanentDeletion': true,
      'permanentDeletionRequestedAt': nowTimestamp,
      'permanentDeletionScheduledFor': scheduledTimestamp,
      'permanentDeletionRequestedBy': currentUser.uid,
    });

    // 3. Audit Logging
    final auditRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('admin_actions')
        .doc();

    batch.set(auditRef, {
      'adminUid': currentUser.uid,
      'adminEmail': currentUser.email,
      'targetUid': targetUid,
      'targetEmail': targetEmail,
      'action': 'USER_PERMANENT_DELETE_SCHEDULED',
      'timestamp': nowTimestamp,
      'scheduledFor': scheduledTimestamp,
    });

    await batch.commit();
  }

  /// Admin cancels a scheduled permanent deletion
  static Future<void> cancelPermanentDeletion({
    required String instituteId,
    required String targetUid,
    required String targetEmail,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Admin must be logged in.");

    final participantRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('participants')
        .doc(targetUid);

    final queueRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('deletion_queue')
        .doc(targetUid);

    final batch = _firestore.batch();

    // 1. Remove/Update Queue Entry
    batch.update(queueRef, {
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': currentUser.uid,
    });

    // 2. Reset Participant Doc
    batch.update(participantRef, {
      'pendingPermanentDeletion': false,
      'permanentDeletionRequestedAt': null,
      'permanentDeletionScheduledFor': null,
      'permanentDeletionRequestedBy': null,
    });

    // 3. Audit Logging
    final auditRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('admin_actions')
        .doc();

    batch.set(auditRef, {
      'adminUid': currentUser.uid,
      'adminEmail': currentUser.email,
      'targetUid': targetUid,
      'targetEmail': targetEmail,
      'action': 'USER_PERMANENT_DELETE_CANCELLED',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
  static Future<Map<String, dynamic>> processDeletionQueue({required String instituteId, String? targetUid}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('processDeletionQueueNow');
      final result = await callable.call({
        'instituteId': instituteId,
        'targetUid': targetUid,
      });

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return {'processed': 0, 'failed': 0, 'deletedUsers': []};
    } catch (e) {
      throw Exception('Failed to process deletion queue: $e');
    }
  }
}
