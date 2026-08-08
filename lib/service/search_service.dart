import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates searchable keywords from a string.
  /// Example for "John Doe": "j", "jo", ..., "john doe" AND "d", "do", "doe"
  static List<String> generateSearchKeywords(String text) {
    if (text.isEmpty) return [];
    
    final Set<String> keywords = {};
    final String lowercaseText = text.toLowerCase().trim();
    
    // Add prefixes for the entire string (allows matching "John D")
    String currentPrefix = "";
    for (int i = 0; i < lowercaseText.length; i++) {
      currentPrefix += lowercaseText[i];
      keywords.add(currentPrefix);
    }
    
    // Add prefixes for individual words (allows matching "Doe")
    final List<String> words = lowercaseText.split(RegExp(r'\s+'));
    for (String word in words) {
      if (word.isEmpty) continue;
      currentPrefix = "";
      for (int i = 0; i < word.length; i++) {
        currentPrefix += word[i];
        keywords.add(currentPrefix);
      }
    }
    
    return keywords.toList();
  }

  /// Searches the participants subcollection within an institute using Firestore array-contains.
  static Future<List<Map<String, dynamic>>> searchParticipants({
    required String queryText,
    required String instituteId,
  }) async {
    try {
      final String lowercaseQuery = queryText.toLowerCase().trim();
      if (lowercaseQuery.isEmpty) return [];

      print("🔍 [SEARCH START] Query: '$queryText' | Token: '$lowercaseQuery' | Institute: $instituteId");
      
      final collectionPath = 'institutes/$instituteId/participants';
      print("📂 [SEARCH PATH] Executing query on: $collectionPath");

      // Enforce multi-tenancy: Only search inside the specific institute's subcollection
      final QuerySnapshot snapshot = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('participants')
          .where('searchKeywords', arrayContains: lowercaseQuery)
          .limit(20) // Optimization: Limit results for large datasets
          .get();

      print("📊 [SEARCH RESULT] Found ${snapshot.docs.length} documents matching '$lowercaseQuery'.");

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Debugging verification
        final keywords = data['searchKeywords'] as List<dynamic>?;
        print("👤 [SEARCH MATCH] Found user: ${data['name'] ?? 'Unknown'} | Keywords present: ${keywords != null ? 'YES (${keywords.length})' : 'NO'}");
        
        return data;
      }).where((data) => data['isDeleted'] != true && data['status'] != 'deleted').toList();
    } catch (e) {
      print("❌ [SEARCH ERROR] Firestore search error: $e");
      return [];
    }
  }

  /// Fetches a participant by their email, ensuring it's within the specific institute.
  /// Used for QR Code scanning.
  static Future<Map<String, dynamic>?> getByEmail({
    required String email,
    required String instituteId,
  }) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('participants')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        if (data['isDeleted'] == true || data['status'] == 'deleted') {
          return null;
        }
        data['id'] = snapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print("❌ Firestore getByEmail error: $e");
      return null;
    }
  }
}
