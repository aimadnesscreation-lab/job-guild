import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service for handling push notifications via Firebase Cloud Messaging.
/// Handles token registration, foreground messages, and tap handling.
class NotificationService {
  bool _initialized = false;
  String? _fcmToken;
  void Function(Map<String, dynamic>)? _onMessageTap;

  /// Initialize FCM — call once at app startup
  Future<void> initialize({
    void Function(Map<String, dynamic>)? onMessageTap,
  }) async {
    if (_initialized) return;

    _onMessageTap = onMessageTap;

    try {
      // Request permissions (iOS)
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token
      _fcmToken = await messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        // TODO: Update token in Supabase
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (app opened from terminated state)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }

      // Handle notification taps (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message.data);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  }

  /// Get the FCM token for the current device
  String? get fcmToken => _fcmToken;

  /// Handle a foreground message (show local notification)
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      // TODO: Show in-app notification banner or update notification badge
      debugPrint(
        'Foreground notification: ${notification.title} - ${notification.body}',
      );
    }
  }

  /// Handle a notification tap (navigate to relevant screen)
  void _handleNotificationTap(Map<String, dynamic> data) {
    _onMessageTap?.call(data);
  }

  /// Update FCM token in Supabase
  Future<void> updateTokenInDatabase(String userId) async {
    if (_fcmToken == null) return;
    // TODO: Save _fcmToken to user's profile in Supabase
  }
}

/// Riverpod provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Initialize Firebase and FCM at app startup — call this in main()
Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error (may be already initialized): $e');
  }
}
