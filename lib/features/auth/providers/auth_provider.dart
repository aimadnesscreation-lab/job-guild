import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_services_marketplace/core/services/notification_service.dart';

/// Tracks the current authentication state (session, loading, error)
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateChangesProvider).value?.session?.user;
});

class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  // ─── Email Auth ──────────────────────────────────────────

  /// Sign up with email + password, storing the role in user metadata so the
  /// database trigger can create the public.users row with the correct flags.
  /// Returns null on success, or an "email confirmation" message if the user
  /// needs to verify their email.
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String initialRole,
  }) async {
    try {
      final isEmployer = initialRole == 'employer';
      final isWorker = initialRole == 'worker';

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'is_employer': isEmployer,
          'is_worker': isWorker,
        },
      );
      if (response.session == null && response.user == null) {
        throw Exception(
          'Sign-up failed. Please try again.',
        );
      }
      // If user was created but session is null, email confirmation is required.
      if (response.user != null && response.session == null) {
        return 'Account created! Please check your email to confirm your account before signing in.';
      }
      return null; // signed in immediately (email confirmation disabled)
    } on AuthException catch (e) {
      debugPrint('[Auth] Email sign-up failed: ${e.message}');
      throw Exception('Sign-up failed: ${e.message}');
    } on SocketException {
      throw Exception('Network error: Please check your connection.');
    }
  }

  /// Sign in with email + password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      debugPrint('[Auth] Email sign-in failed: ${e.message}');
      throw Exception('Sign-in failed: ${e.message}');
    } on SocketException {
      throw Exception('Network error: Please check your connection.');
    }
  }

  // ─── Phone OTP Auth ─────────────────────────────────────

  /// Normalize a Pakistani phone number to international format (+92xxxxxxxxx).
  /// Throws [FormatException] if the number is not a valid Pakistani mobile.
  static String normalizePhone(String phone) {
    if (phone.length > 30) {
      throw const FormatException('Phone number is too long.');
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Pakistani mobile numbers are +92 followed by exactly 10 digits,
    // so the full digit string must be 12 characters long.
    if (digits.startsWith('92')) {
      if (digits.length == 12) return '+$digits';
      throw const FormatException(
        'Invalid Pakistani mobile number. Expected 12 digits (e.g. 923001234567).',
      );
    }
    if (digits.startsWith('0')) {
      if (digits.length == 11) return '+92${digits.substring(1)}';
      throw const FormatException(
        'Invalid Pakistani mobile number. Expected 11 digits starting with 0 (e.g. 03001234567).',
      );
    }
    if (digits.length == 10) return '+92$digits';

    throw const FormatException(
      'Invalid Pakistani mobile number. Please enter a valid 10 or 11 digit mobile number.',
    );
  }

  /// Send OTP code to the given phone number.
  /// [initialRole] is passed as metadata so the DB trigger can set
  /// is_employer/is_worker on the public.users row at creation time.
  Future<void> sendOtp({required String phone, String? initialRole}) async {
    final Map<String, dynamic>? data = initialRole != null
        ? {
            'is_employer': initialRole == 'employer',
            'is_worker': initialRole == 'worker',
          }
        : null;
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: normalizePhone(phone),
        data: data,
      );
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Verify OTP code and sign in
  Future<void> verifyOtp({required String phone, required String otp}) async {
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: normalizePhone(phone),
        token: otp,
        type: OtpType.sms,
      );
      if (response.session == null) throw Exception('Invalid session');
    } on SocketException catch (e) {
      debugPrint('[Auth] Network error: $e');
      throw Exception('Network error: Please check your connection.');
    } on AuthException catch (e) {
      debugPrint('[Auth] OTP verification failed: ${e.message}');
      throw Exception('Verification failed: ${e.message}');
    } catch (e) {
      debugPrint('[Auth] OTP verification error: $e');
      throw Exception('An unexpected error occurred during verification.');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await ref.read(notificationServiceProvider).signOut();
    await Supabase.instance.client.auth.signOut();
  }
}

/// Provider for auth actions (send OTP, verify, sign out)
final authProvider = NotifierProvider<AuthNotifier, void>(() => AuthNotifier());
