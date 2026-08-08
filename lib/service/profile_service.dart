import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/service/search_service.dart';

class ProfileService {
  final String instituteId;
  late final CollectionReference _participantsCollection;

  ProfileService({required this.instituteId}) {
    // SINGLE SOURCE OF TRUTH: All profile data is in participants
    _participantsCollection = FirebaseFirestore.instance
        .collection('institutes')
        .doc(instituteId)
        .collection('participants');
  }

  /// Gets a real-time stream of a participant's profile
  Stream<ParticipantModel?> getProfileStream(String uid) {
    return _participantsCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return ParticipantModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Fetches a participant's profile once
  Future<ParticipantModel?> getProfile(String uid) async {
    try {
      final docSnapshot = await _participantsCollection.doc(uid).get();
      if (docSnapshot.exists) {
        return ParticipantModel.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      print("Error getting profile: $e");
      return null;
    }
  }

  /// Upserts a participant profile in the participants collection
  Future<void> saveProfile(String uid, Map<String, dynamic> updateData) async {
    try {
      // Fetch existing data to ensure searchKeywords aren't overwritten with partial data
      final docSnapshot = await _participantsCollection.doc(uid).get();
      Map<String, dynamic> mergedData = {};
      if (docSnapshot.exists && docSnapshot.data() != null) {
        mergedData = Map<String, dynamic>.from(docSnapshot.data() as Map<String, dynamic>);
      }
      
      // Merge updates
      mergedData.addAll(updateData);
      
      // Generate search keywords based on combined data
      final Set<String> keywords = {};
      if (mergedData['name'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['name']));
      }
      if (mergedData['email'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['email']));
      }
      if (mergedData['role'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['role']));
      }
      if (mergedData['company'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['company']));
      }
      if (mergedData['interest'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['interest']));
      }
      if (mergedData['year'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['year']));
      }
      if (mergedData['rollNo'] != null) {
        keywords.addAll(SearchService.generateSearchKeywords(mergedData['rollNo']));
      }
      
      updateData['searchKeywords'] = keywords.toList();

      await _participantsCollection
          .doc(uid)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      print("Error saving profile: $e");
      rethrow;
    }
  }

  /// Gets a real-time stream of all alumni documents
  Stream<List<ParticipantModel>> getAlumniStream() {
    return _participantsCollection
        .where('role', isEqualTo: 'alumni')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ParticipantModel.fromFirestore(doc);
      }).where((p) => !p.isDeleted && p.status != 'deleted').toList();
    });
  }

  /// Fetches the list of all alumni just once
  Future<List<ParticipantModel>> getAlumniOnce() async {
    try {
      final snapshot = await _participantsCollection
          .where('role', isEqualTo: 'alumni')
          .get();
      return snapshot.docs
          .map((doc) => ParticipantModel.fromFirestore(doc))
          .where((p) => !p.isDeleted && p.status != 'deleted')
          .toList();
    } catch (e) {
      print("Error fetching alumni: $e");
      return [];
    }
  }
}
