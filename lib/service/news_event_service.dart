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

  /// Post visibilities a role may read; null means everything (admins).
  /// Must match visibleTo() in firestore.rules, which rejects queries that
  /// could return posts the user isn't allowed to see.
  static List<String>? visibilitiesFor(String role) {
    switch (role) {
      case 'admin':
        return null;
      case 'alumni':
        return const ['public', 'alumni_only'];
      default:
        return const ['public', 'students_only'];
    }
  }

  /// Streams the newest [limit] posts; callers page by asking for a larger limit.
  /// Pass [includeDeleted] to get the raw page (e.g. to tell whether more pages exist).
  /// Pass the reader's [role] so the query only asks for posts they may see.
  Stream<List<NewsEventPost>> getPosts(String instituteId,
      {required String role, int limit = 20, bool includeDeleted = false}) {
    Query query = _postsRef(instituteId);
    final visibilities = visibilitiesFor(role);
    if (visibilities != null) {
      query = query.where('visibility', whereIn: visibilities);
    }
    return query
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NewsEventPost.fromFirestore(doc))
            .where((p) => includeDeleted || p.status != 'deleted')
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

  /// Deletes a comment and keeps the post's commentCount in step.
  Future<void> deleteComment(String instituteId, String postId, String commentId) async {
    final postRef = _postsRef(instituteId).doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final commentDoc = await transaction.get(commentRef);
      if (!commentDoc.exists) return;
      transaction.delete(commentRef);
      transaction.update(postRef, {'commentCount': FieldValue.increment(-1)});
    });
  }

  // --- RSVP Logic ---

  /// The current user's RSVP document (status: attending, waitlisted or declined).
  Stream<DocumentSnapshot> getMyRsvpStream(String instituteId, String postId, String uid) {
    return _postsRef(instituteId).doc(postId).collection('attendees').doc(uid).snapshots();
  }

  /// Returns the resulting status: 'attending', 'waitlisted' or 'declined'.
  Future<String> toggleRsvp(String instituteId, String postId, String uid, String name, String email, bool isAttending) async {
    final postRef = _postsRef(instituteId).doc(postId);
    final attendeeRef = postRef.collection('attendees').doc(uid);

    return _firestore.runTransaction<String>((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception("Post not found");

      final data = postDoc.data() as Map<String, dynamic>;
      final maxAttendees = data['maxAttendees'] as int?;
      final currentAttendees = data['attendeeCount'] as int? ?? 0;

      final attendeeDoc = await transaction.get(attendeeRef);
      final String? previousStatus = attendeeDoc.exists ? (attendeeDoc.data()?['status'] as String?) : null;
      final wasAttending = previousStatus == 'attending';
      final wasWaitlisted = previousStatus == 'waitlisted';

      if (isAttending && wasWaitlisted) return 'waitlisted';

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
            return 'waitlisted';
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
        return 'attending';
      }
      else if (!isAttending && (wasAttending || wasWaitlisted)) {
        // Cancel RSVP or leave the waitlist (only attendees count toward attendeeCount)
        transaction.update(attendeeRef, {
          'status': 'declined',
          'declinedAt': FieldValue.serverTimestamp(),
        });
        if (wasAttending) {
          transaction.update(postRef, {'attendeeCount': FieldValue.increment(-1)});
        }
        return 'declined';
      }
      return previousStatus ?? 'declined';
    });
  }
}
