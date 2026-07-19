import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

class OtpView extends ConsumerStatefulWidget {
  final String phoneNumber;
  const OtpView({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends ConsumerState<OtpView> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    try {
      final otp = _otpController.text.trim();
      await ref.read(authProvider.notifier).verifyOtp(
        phone: widget.phoneNumber,
        otp: otp,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verification code sent to ${widget.phoneNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _verify,
                    child: const Text('Verify & Continue'),
                  ),
          ],
        ),
      ),
    );
  }
}
