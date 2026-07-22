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

  /// Normalize a Pakistani phone number to international format (+92xxxxxxxxx)
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Pakistani mobile numbers are +92 followed by exactly 10 digits,
    // so the full digit string must be 12 characters long.
    if (digits.startsWith('92')) {
      // Only 12-digit 92-prefixed numbers are valid Pakistani mobile numbers
      // (92 + 10-digit local number). Anything else (e.g. 11 digits) is
      // ambiguous — we fall through to the catch-all and let Supabase auth
      // handle validation rather than silently producing an invalid number.
      if (digits.length == 12) return '+$digits';
      return '+$digits';
    }
    if (digits.startsWith('0')) {
      final withoutLeading = digits.substring(1);
      return '+92$withoutLeading';
    }
    return '+92$digits';
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
