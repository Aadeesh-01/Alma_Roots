import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cs261_project/model/news_event_model.dart';
import 'package:cs261_project/screen/events_and_news/news_event_detail_screen.dart';
import 'package:cs261_project/screen/message/chat_screen.dart';

/// Must be top-level: handles data messages while the app is in the background.
/// Notification messages are displayed by the system, so nothing to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Registers this device for push notifications (FCM token stored on the
/// participant document), shows notifications while the app is open, and
/// routes notification taps to the right screen.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Attached to MaterialApp so notification taps can navigate from anywhere.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'alma_roots_default', // also set as the FCM default channel in AndroidManifest.xml
    'Alma Roots',
    description: 'Messages, news, events and account updates',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  String? _instituteId;
  bool _listenersAttached = false;
  StreamSubscription<String>? _tokenRefreshSub;

  DocumentReference<Map<String, dynamic>>? _participantRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _instituteId == null) return null;
    return FirebaseFirestore.instance
        .collection('institutes')
        .doc(_instituteId)
        .collection('participants')
        .doc(uid);
  }

  /// Call once the user is signed in and their institute is known.
  Future<void> init(String instituteId) async {
    _instituteId = instituteId;
    try {
      await _setUpLocalNotifications();

      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notifications: permission denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

      if (!_listenersAttached) {
        _listenersAttached = true;
        FirebaseMessaging.onMessage.listen(_showForegroundNotification);
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
        final initial = await _messaging.getInitialMessage();
        if (initial != null) _openFromData(initial.data);
      }
    } catch (e) {
      // Notifications are a nice-to-have; never block the app over them.
      debugPrint('Notifications: setup failed: $e');
    }
  }

  /// Call before signing out so this device stops receiving the user's notifications.
  Future<void> unregister() async {
    try {
      final token = await _messaging.getToken();
      final ref = _participantRef();
      if (token != null && ref != null) {
        await ref.update({'fcmTokens': FieldValue.arrayRemove([token])});
      }
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Notifications: unregister failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final ref = _participantRef();
    if (ref == null) return;
    await ref.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> _setUpLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _openFromData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _openFromData(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    final instituteId = (data['instituteId'] as String?) ?? _instituteId;
    if (navigator == null || instituteId == null || instituteId.isEmpty) return;

    switch (data['type']) {
      case 'chat':
        final otherUserId = data['otherUserId'] as String?;
        if (otherUserId == null || otherUserId.isEmpty) return;
        navigator.push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: otherUserId,
            otherUserName: (data['otherUserName'] as String?) ?? 'Member',
            instituteId: instituteId,
          ),
        ));
        break;
      case 'post':
        final postId = data['postId'] as String?;
        if (postId == null || postId.isEmpty) return;
        final inst = FirebaseFirestore.instance.collection('institutes').doc(instituteId);
        final postDoc = await inst.collection('posts').doc(postId).get();
        if (!postDoc.exists) return;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final me = uid == null ? null : await inst.collection('participants').doc(uid).get();
        navigator.push(MaterialPageRoute(
          builder: (_) => NewsEventDetailScreen(
            instituteId: instituteId,
            post: NewsEventPost.fromFirestore(postDoc),
            userRole: (me?.data()?['role'] as String?) ?? 'student',
          ),
        ));
        break;
    }
  }
}
