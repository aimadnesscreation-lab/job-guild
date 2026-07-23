import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks the current authentication state (session, loading, error)
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Provides the current user directly.
/// Returns null when `Supabase` has not been initialized yet (e.g. in widget
/// tests) instead of throwing on `Supabase.instance.client`.
final currentUserProvider = Provider<User?>((ref) {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
});

/// Provides access to the Supabase client.
/// Returns null when `Supabase` has not been initialized yet (e.g. in widget
/// tests) instead of throwing on `Supabase.instance.client`. Consumers must
/// handle a null client (the app always initializes Supabase in `main()`
/// before any UI is built, so this is only ever null in tests).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Whether the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.asData?.value.session != null;
});

/// Auth notifier for phone OTP flow
class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Normalize a Pakistani phone number to international format (+92xxxxxxxxx).
  /// Throws [FormatException] if the number is not a valid Pakistani mobile.
  static String normalizePhone(String phone) {
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
      if (response.session == null) {
        throw Exception('Invalid or expired code');
      }
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}

/// Provider for auth actions (send OTP, verify, sign out)
final authProvider = NotifierProvider<AuthNotifier, void>(() => AuthNotifier());
