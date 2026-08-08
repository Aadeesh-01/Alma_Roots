import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// This function MUST be a top-level function (not inside a class)
// to handle messages when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // You can't do much UI-related work here, but you can handle data.
  print("Handling a background message: ${message.messageId}");
  print("Message data: ${message.data}");
  print("Message notification: ${message.notification?.title}");
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // A global navigator key is needed to handle navigation from a tap
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> init() async {
    // --- Setup for Local Notifications (for foreground messages) ---
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Uses your app icon

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // This handles the tap on a foreground notification
        _handleMessageTap(response.payload);
      },
    );

    // --- Setup for FCM Listeners ---

    // 1. For messages that arrive when the app is in the FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // 2. For messages that open the app from a BACKGROUND state (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleMessageTap(message.data.toString());
    });

    // 3. For messages that open the app from a TERMINATED state
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from a terminated state by a notification!');
        _handleMessageTap(message.data.toString());
      }
    });

    // 4. Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Helper method to display a local notification
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id', // This should be a unique channel ID
            'Default Channel',
            channelDescription: 'This is the default notification channel',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        // We pass the message data as a payload to handle taps
        payload: message.data.toString(),
      );
    }
  }

  // Handles navigation when a notification is tapped
  void _handleMessageTap(String? payload) {
    // In a real app, you would parse the payload and navigate based on the 'screen' data.
    // For now, we'll just print it.
    print("Notification tapped with payload: $payload");

    // Example of navigation logic:
    // final data = jsonDecode(payload);
    // if (data['screen'] == 'posts_page') {
    //   navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => PostsScreen()));
    // }
  }
}
