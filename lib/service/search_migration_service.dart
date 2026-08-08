import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/service/search_service.dart';

class SearchMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Batch migrates all legacy participants in an institute by generating and backfilling
  /// the 'searchKeywords' array. This ensures all legacy users become searchable.
  static Future<void> migrateInstituteParticipants(String instituteId) async {
    print("🚀 [MIGRATION START] Migrating participants for Institute: $instituteId");
    try {
      final participantsRef = _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('participants');

      final snapshot = await participantsRef.get();
      print("📊 [MIGRATION] Found ${snapshot.docs.length} total participants.");

      int migratedCount = 0;
      int skippedCount = 0;

      // Firestore batches support up to 500 writes
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // If the document already has searchKeywords, we can skip it,
        // OR we can choose to forcibly regenerate it to be safe. We will forcibly regenerate
        // to ensure the new tokenization algorithm is applied to everyone.
        
        final Set<String> keywords = {};
        if (data['name'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['name'].toString()));
        }
        if (data['email'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['email'].toString()));
        }
        if (data['role'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['role'].toString()));
        }
        if (data['company'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['company'].toString()));
        }
        if (data['interest'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['interest'].toString()));
        }
        if (data['year'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['year'].toString()));
        }
        if (data['rollNo'] != null) {
          keywords.addAll(SearchService.generateSearchKeywords(data['rollNo'].toString()));
        }

        if (keywords.isNotEmpty) {
          batch.update(doc.reference, {'searchKeywords': keywords.toList()});
          batchCount++;
          migratedCount++;
        } else {
          skippedCount++;
        }

        // Commit batch every 400 operations to stay under the 500 limit
        if (batchCount >= 400) {
          await batch.commit();
          print("💾 [MIGRATION] Committed batch of $batchCount updates.");
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Commit any remaining writes
      if (batchCount > 0) {
        await batch.commit();
        print("💾 [MIGRATION] Committed final batch of $batchCount updates.");
      }

      print("✅ [MIGRATION COMPLETE] Migrated: $migratedCount | Skipped: $skippedCount");
    } catch (e) {
      print("❌ [MIGRATION ERROR] Failed to migrate participants: $e");
      rethrow;
    }
  }
}
