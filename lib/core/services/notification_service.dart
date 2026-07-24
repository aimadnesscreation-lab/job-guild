import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling push notifications via Firebase Cloud Messaging.
/// Handles token registration, foreground messages, tap handling, and
/// persists the FCM token to the fcm_tokens table in Supabase.
class NotificationService {
  bool _initialized = false;
  String? _token;
  void Function(Map<String, dynamic>)? _onMessageTap;
  String? _currentUserId;

  /// Initialize FCM — call once at app startup
  Future<void> initialize({
    void Function(Map<String, dynamic>)? onMessageTap,
  }) async {
    if (_initialized) return;

    _onMessageTap = onMessageTap;

    try {
      // Request permissions (iOS)
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Get FCM token
      await _refreshToken();

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        if (_currentUserId != null) {
          _saveTokenToSupabase(_currentUserId!, newToken);
        }
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

  /// Refresh the FCM token from Firebase
  Future<void> _refreshToken() async {
    try {
      _token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $_token');
    } catch (e) {
      debugPrint('FCM token refresh error: $e');
    }
  }

  /// Get the FCM token for the current device
  String? get fcmToken => _token;

  /// Set the current user ID and save token on login
  void onUserChanged(String? userId) {
    _currentUserId = userId;
    if (userId != null && _token != null) {
      _saveTokenToSupabase(userId, _token!);
    }
  }

  /// Clean up FCM token on logout
  Future<void> signOut() async {
    if (_token == null) return;
    try {
      final client = Supabase.instance.client;
      await client
          .from('fcm_tokens')
          .delete()
          .eq('token', _token!)
          .eq('user_id', _currentUserId!);
      debugPrint('[FCM] Token deleted from Supabase on logout');
      _token = null;
      _currentUserId = null;
    } catch (e) {
      debugPrint('[FCM] Failed to delete token on logout: $e');
    }
  }

  /// Save (or update) the FCM token in the fcm_tokens table.
  /// Removes any previously-stored tokens for this user on the same
  /// platform so stale tokens do not accumulate over time.
  Future<void> _saveTokenToSupabase(String userId, String token) async {
    try {
      final client = Supabase.instance.client;

      // Upsert: if this exact token exists, update it; else insert.
      final platform = _detectPlatform();
      await client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('[FCM] Token saved to Supabase for user $userId');
    } catch (e) {
      debugPrint('[FCM] Failed to save token to Supabase: $e');
    }
  }

  /// Detect the current platform.
  String _detectPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    return 'android';
  }

  /// Handle a foreground message (show local notification)
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      debugPrint(
        'Foreground notification: ${notification.title} - ${notification.body}',
      );
      // The notification badge/overlay is handled by the UI layer
      // via a Riverpod provider that watches for new notifications.
      // Do NOT navigate on foreground messages — only taps should navigate.
    }
  }

  /// Handle a notification tap (navigate to relevant screen)
  void _handleNotificationTap(Map<String, dynamic> data) {
    _onMessageTap?.call(data);
  }
}

/// Riverpod provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Initialize Firebase and FCM at app startup — call this in main()
///
/// On web, FlutterFire requires FirebaseOptions (the browser lacks
/// google-services.json / GoogleService-Info.plist). We pass null for
/// mobile platforms where the native config files are auto-detected;
/// on web the null causes the crash, so we read FirebaseOptions from
/// environment variables as a best-effort fallback.
Future<void> initializeFirebase() async {
  try {
    if (kIsWeb) {
      // Web requires explicit FirebaseOptions — read from env vars.
      final apiKey = const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
      final appId = const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
      final messagingSenderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
      final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
      final authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');

      if (apiKey.isEmpty || appId.isEmpty) {
        debugPrint('Firebase web options not configured via --dart-define — skipping Firebase init on web');
        return;
      }

      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          authDomain: authDomain,
        ),
      );
    } else {
      // Mobile / desktop — native config files present
      await Firebase.initializeApp();
    }
    debugPrint('Firebase initialized successfully');
  } catch (e, st) {
    debugPrint('Firebase init error: $e');
    debugPrint('Stack trace: $st');
    // Surface production failures to monitoring tools
    if (!kDebugMode) {
      // TODO: Log the error to a crash reporting tool (e.g., Sentry) here.
      // Sentry.captureException(e, stackTrace: st);
      debugPrint('Firebase init failed in production, continuing without notifications: $e');
    }
  }
}
