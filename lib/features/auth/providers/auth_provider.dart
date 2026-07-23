import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

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

  /// Send OTP code to the given phone number
  Future<void> sendOtp({required String phone}) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: normalizePhone(phone),
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
      if (response.error != null) throw response.error!;
      if (response.session == null) throw Exception('Invalid session');
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
    await Supabase.instance.client.auth.signOut();
  }
}

/// Provider for auth actions (send OTP, verify, sign out)
final authProvider = NotifierProvider<AuthNotifier, void>(() => AuthNotifier());
