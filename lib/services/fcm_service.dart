//fcm_service.dart
// This file defines a service for handling Firebase Cloud Messaging (FCM) notifications in a Flutter application.
// It includes methods for initializing FCM, requesting notification permissions, and handling incoming messages.
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else {
        print('User declined or has not granted permission');
      }

      // Get the FCM token
      final token = await _messaging.getToken();
      print('FCM Token: $token');

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received a foreground message: ${message.notification?.title}');
      });

      // Listen for messages when the app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification clicked: ${message.notification?.title}');
      });
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }
}
