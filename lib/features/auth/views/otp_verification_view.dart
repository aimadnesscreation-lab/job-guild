import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// OTP verification screen — user enters 6-digit code received via SMS.
/// Handles auto-submit, resend, and error states.
class OtpVerificationView extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerificationView({super.key, required this.phoneNumber});

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

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
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
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
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
    }
    // Auto-submit when all filled
    if (_otpCode.length == 6) {
      _verifyOtp();
    }
  }

  void _onDigitBackspace(int index) {
    if (_otpControllers[index].text.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).verifyOtp(
            phone: widget.phoneNumber,
            otp: code,
          );
      // Auth state changes will trigger navigation in main.dart
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _error = 'Invalid code. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
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
      await ref.read(authProvider.notifier).sendOtp(
            phone: widget.phoneNumber,
          );
      _startResendCountdown();
    } catch (e) {
      setState(() => _error = 'Failed to resend code');
    } finally {
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone'),
      ),
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
            const Text(
              'Enter Verification Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'Enter the 6-digit code sent to ',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: '${widget.phoneNumber.replaceFirst('+92', '+92 ')}',
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
                    : const Text(
                        'Verify',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Resend ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive the code? ",
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                if (_resendCountdown > 0)
                  Text(
                    'Resend in $_resendCountdown s',
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Resend Code'),
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
