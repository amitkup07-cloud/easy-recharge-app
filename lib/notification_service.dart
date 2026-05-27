import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // 🔥 1. Initialize FCM & Topics
  static Future<void> initialize() async {
    // Permission maango
    NotificationSettings fcmSettings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (fcmSettings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("🔥 Notification Permission Granted!");

      // 🎯 Topic Subscribe: Ab sabko ek sath message bhej sakenge
      await _fcm.subscribeToTopic("all_users");
      debugPrint("🚀 Subscribed to 'all_users' Topic!");
    }

    // Local Notifications Setup (Foreground ke liye)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // 🔥 THE FINAL FIX: Yahan ab sirf 'settings:' likhna padta hai naye version me
    await _localNotifications.initialize(settings: initSettings);

    // Foreground me jab message aaye toh ye function chalega
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    // Token nikalna aur save karna (Back-up ke liye)
    String? token = await _fcm.getToken();
    if (token != null) {
      _saveTokenToFirestore(token);
    }

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  // 🔥 2. Foreground Me Notification Dikhane Ka Jadoo
  static void _showForegroundNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // channelId
            'High Importance Notifications', // channelName
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  // 🔥 3. Save Token To Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      debugPrint("🔥 Token updated in Firestore!");
    }
  }
}
