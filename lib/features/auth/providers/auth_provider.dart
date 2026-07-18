import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks the current authentication state (session, loading, error)
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Provides the current user directly
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

/// Provides access to the Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
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
    // Strip all non-digit characters
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // If starts with 92, use as-is (but ensure it's exactly 92xxxxxxxxx)
    if (digits.startsWith('92')) {
      if (digits.length == 12) return '+$digits';
      if (digits.length == 13) return '+$digits'; // Already has leading 0+92
    }
    // If starts with 0 (e.g., 03001234567), strip the leading 0 and add 92
    if (digits.startsWith('0')) {
      final withoutLeading = digits.substring(1);
      return '+92$withoutLeading';
    }
    // Otherwise, prepend +92
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
  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
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
