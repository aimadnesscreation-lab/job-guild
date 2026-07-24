// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/home/views/home_view.dart';

/// OTP verification screen — user enters 6-digit code received via SMS.
/// Handles auto-submit, resend, and error states.
class OtpVerificationView extends ConsumerStatefulWidget {
  final String phoneNumber;

  /// The role selected during onboarding ('employer' or 'worker').
  /// Passed through so OTP resend preserves the correct role metadata.
  final String? initialRole;

  const OtpVerificationView({
    super.key,
    required this.phoneNumber,
    this.initialRole,
  });

  @override
  ConsumerState<OtpVerificationView> createState() =>
      _OtpVerificationViewState();
}

class _OtpVerificationViewState extends ConsumerState<OtpVerificationView> {
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 30;
  String? _error;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _resendCountdown = 30;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!context.mounted) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _countdownTimer?.cancel();
          _countdownTimer = null;
        }
      });
    });
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    // Guard: don't auto-submit if already verifying
    if (_isVerifying) return;
    setState(() => _error = null);
    if (value.length > 1) {
      // Pasted code — fill all fields
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _otpControllers[i].text = digits[i];
      }
      if (digits.length == 6) {
        _otpFocusNodes[5].unfocus();
        _verifyOtp();
      }
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move focus back on backspace
      _otpFocusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all filled
    if (_otpCode.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    // Guard against re-entrant calls (auto-submit + button tap)
    if (_isVerifying) return;

    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = ref.read(appStringsProvider).enterFullCode);
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .verifyOtp(phone: widget.phoneNumber, otp: code);
      // Auth state changes in main.dart, but the OTP screen was pushed on
      // top of the route stack — so we must navigate explicitly to HomeView
      // (clearing the stack) or the user stays stuck on this screen.
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeView()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _error = ref.read(appStringsProvider).invalidCode;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (!mounted) return;
    setState(() {
      _isResending = true;
      _error = null;
    });

    // Clear existing OTP fields for fresh entry
    for (final c in _otpControllers) {
      c.clear();
    }
    _otpFocusNodes[0].requestFocus();

    try {
      await ref
          .read(authProvider.notifier)
          .sendOtp(phone: widget.phoneNumber, initialRole: widget.initialRole);
      if (!mounted) return;
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ref.read(appStringsProvider).failedToResend);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appStringsProvider).verifyPhone)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // ─── Icon ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // ─── Instructions ────────────────────────────────
              Text(
                ref.watch(appStringsProvider).enterVerificationCode,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: ref.watch(appStringsProvider).enterCodeSentTo,
                  style: const TextStyle(color: AppTheme.textSecondary),
                  children: [
                    TextSpan(
                      text: widget.phoneNumber.replaceFirst('+92', '+92 '),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ─── OTP Input ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: index == 0 || index == 3 ? 4 : 4,
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 52,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required bool isFocused,
                              maxLength,
                            }) => null,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: _error != null
                                  ? AppTheme.errorColor
                                  : AppTheme.borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: _error != null
                                  ? AppTheme.errorColor
                                  : AppTheme.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) => _onDigitChanged(index, val),
                      ),
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ─── Verify Button ───────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          ref.watch(appStringsProvider).verify,
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Resend ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ref.watch(appStringsProvider).didntReceiveCode,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  if (_resendCountdown > 0)
                    Text(
                      '${ref.watch(appStringsProvider).resendIn}$_resendCountdown s',
                      style: const TextStyle(
                        color: AppTheme.textDisabled,
                        fontSize: 13,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isResending ? null : _resendOtp,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(ref.watch(appStringsProvider).resendCode),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
