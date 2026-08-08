import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/news_event_model.dart';

class NewsEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _postsRef(String instituteId) {
    return _firestore.collection('institutes').doc(instituteId).collection('posts');
  }

  Future<void> addPost(NewsEventPost post) async {
    await _postsRef(post.instituteId).add(post.toMap());
  }

  // Uses limit(20) for pagination
  Stream<List<NewsEventPost>> getPosts(String instituteId) {
    return _postsRef(instituteId)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NewsEventPost.fromFirestore(doc))
            .where((p) => p.status != 'deleted') // Filter deleted locally for now
            .toList());
  }

  Stream<DocumentSnapshot> getPostStream(String instituteId, String postId) {
    return _postsRef(instituteId).doc(postId).snapshots();
  }

  Stream<QuerySnapshot> getCommentsStream(String instituteId, String postId) {
    return _postsRef(instituteId)
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updatePost(String instituteId, String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _postsRef(instituteId).doc(id).update(data);
  }

  Future<void> deletePost(String instituteId, String id) async {
    await _postsRef(instituteId).doc(id).update({
      'status': 'deleted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Engagement Methods ---

  Future<void> toggleLike(String instituteId, String postId, String uid, String name) async {
    final postRef = _postsRef(instituteId).doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final likeDoc = await transaction.get(likeRef);

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        // Like
        transaction.set(likeRef, {
          'uid': uid,
          'name': name,
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> addComment(String instituteId, String postId, String uid, String name, String text) async {
    final postRef = _postsRef(instituteId).doc(postId);
    final commentRef = postRef.collection('comments').doc();

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      transaction.set(commentRef, {
        'uid': uid,
        'name': name,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });

      transaction.update(postRef, {'commentCount': FieldValue.increment(1)});
    });
  }

  // --- RSVP Logic ---

  Future<void> toggleRsvp(String instituteId, String postId, String uid, String name, String email, bool isAttending) async {
    final postRef = _postsRef(instituteId).doc(postId);
    final attendeeRef = postRef.collection('attendees').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception("Post not found");

      final data = postDoc.data() as Map<String, dynamic>;
      final maxAttendees = data['maxAttendees'] as int?;
      final currentAttendees = data['attendeeCount'] as int? ?? 0;

      final attendeeDoc = await transaction.get(attendeeRef);
      final wasAttending = attendeeDoc.exists && attendeeDoc.data()?['status'] == 'attending';

      if (isAttending && !wasAttending) {
        if (maxAttendees != null && currentAttendees >= maxAttendees) {
          if (data['waitlistEnabled'] == true) {
             // Add to waitlist instead
             transaction.set(attendeeRef, {
              'uid': uid,
              'name': name,
              'email': email,
              'status': 'waitlisted',
              'rsvpAt': FieldValue.serverTimestamp(),
            });
            return;
          } else {
             throw Exception("Event is full");
          }
        }

        // Attend
        transaction.set(attendeeRef, {
          'uid': uid,
          'name': name,
          'email': email,
          'status': 'attending',
          'rsvpAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'attendeeCount': FieldValue.increment(1)});
      } 
      else if (!isAttending && wasAttending) {
        // Cancel RSVP
        transaction.update(attendeeRef, {
          'status': 'declined',
          'declinedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'attendeeCount': FieldValue.increment(-1)});
      }
    });
  }
}
