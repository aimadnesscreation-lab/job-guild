import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'otp_view.dart';

class PhoneLoginView extends ConsumerStatefulWidget {
  const PhoneLoginView({super.key});

  @override
  ConsumerState<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends ConsumerState<PhoneLoginView> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      await ref.read(authProvider.notifier).sendOtp(phone: phone);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpView(phoneNumber: phone),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your phone number',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We will send an OTP code for verification.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+92 300 1234567',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Send OTP'),
                  ),
          ],
        ),
      ),
    );
  }
}
