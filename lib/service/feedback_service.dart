import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> submitFeedback({
    required String uid,
    required String instituteId,
    required String userRole,
    required String category,
    required String title,
    required String description,
    required String stepsToReproduce,
    required String expectedResult,
    required String actualResult,
    String? screenshotUrl,
    String? deviceInfo,
  }) async {
    final docRef = _db
        .collection('institutes')
        .doc(instituteId)
        .collection('feedback')
        .doc();
    await docRef.set({
      'id': docRef.id,
      'uid': uid,
      'instituteId': instituteId,
      'userRole': userRole,
      'category': category,
      'title': title,
      'description': description,
      'stepsToReproduce': stepsToReproduce,
      'expectedResult': expectedResult,
      'actualResult': actualResult,
      'screenshotUrl': screenshotUrl ?? '',
      'deviceInfo': deviceInfo ?? '',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'appVersion': '1.0.0', // Hardcoded as per constraints
    });
  }

  static Stream<QuerySnapshot> getFeedbackStream(String instituteId) {
    return _db
        .collection('institutes')
        .doc(instituteId)
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> updateFeedbackStatus(
      String instituteId, String id, String status) async {
    await _db
        .collection('institutes')
        .doc(instituteId)
        .collection('feedback')
        .doc(id)
        .update({
      'status': status,
    });
  }
}
