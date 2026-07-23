import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/auth/views/otp_verification_view.dart';
import 'package:local_services_marketplace/features/home/views/home_view.dart';

/// Email + password signup / signin screen — the default auth method.
/// Has a "Continue with Phone Number" button at the bottom for OTP signin.
class EmailAuthView extends ConsumerStatefulWidget {
  /// The role selected in RoleSelectionView ('employer' or 'worker').
  final String initialRole;

  const EmailAuthView({super.key, required this.initialRole});

  @override
  ConsumerState<EmailAuthView> createState() => _EmailAuthViewState();
}

class _EmailAuthViewState extends ConsumerState<EmailAuthView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = true; // toggle between signup and signin
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final s = ref.read(appStringsProvider);

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = s.emailAuthEmptyFieldsError);
      return;
    }
    if (_isSignUp && _nameController.text.trim().isEmpty) {
      setState(() => _error = s.emailAuthEmptyNameError);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = s.emailAuthShortPasswordError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider.notifier);

      if (_isSignUp) {
        final confirmationMsg = await auth.signUpWithEmail(
          email: email,
          password: password,
          fullName: _nameController.text.trim(),
          initialRole: widget.initialRole,
        );
        if (confirmationMsg != null) {
          // Email confirmation required — show success and switch to sign-in.
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isSignUp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(confirmationMsg),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      } else {
        await auth.signInWithEmail(email: email, password: password);
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeView()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _goToPhoneAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _PhoneOtpEntryView(initialRole: widget.initialRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Header
              Icon(
                Icons.handyman_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                _isSignUp ? s.emailAuthCreateTitle : s.emailAuthWelcomeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? s.emailAuthCreateSubtitle
                    : s.emailAuthSignInSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),

              // Name field (signup only)
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: s.emailAuthFullNameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: s.emailAuthFullNameHint,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.next,
                decoration: InputDecoration(
                  labelText: s.emailAuthEmailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
                  hintText: s.emailAuthEmailHint,
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: s.emailAuthPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  hintText: _isSignUp ? s.emailAuthPasswordHint : s.emailAuthPasswordSignInHint,
                ),
              ),
              const SizedBox(height: 8),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 20,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Submit button
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSignUp ? s.emailAuthCreateButton : s.emailAuthSignInButton,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // Toggle signup/signin
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? s.emailAuthHasAccount
                        : s.emailAuthNoAccount,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                    }),
                    child: Text(
                      _isSignUp ? s.emailAuthSignInButton : s.emailAuthToggleSignUp,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Divider with "or"
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      s.emailAuthOr,
                      style: TextStyle(color: AppTheme.textDisabled),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              // Phone OTP fallback
              OutlinedButton.icon(
                onPressed: _goToPhoneAuth,
                icon: const Icon(Icons.phone_android_rounded),
                label: Text(s.emailAuthPhoneFallback),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.borderColor),
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.goBack),
              ),
              const SizedBox(height: 32),
              // Footer
              Text(
                s.termsFooter,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textDisabled),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple phone number entry screen that feeds into the OTP verification
/// flow — used as the secondary auth path from [EmailAuthView].
class _PhoneOtpEntryView extends ConsumerStatefulWidget {
  final String initialRole;

  const _PhoneOtpEntryView({required this.initialRole});

  @override
  ConsumerState<_PhoneOtpEntryView> createState() =>
      _PhoneOtpEntryViewState();
}

class _PhoneOtpEntryViewState extends ConsumerState<_PhoneOtpEntryView> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final s = ref.read(appStringsProvider);
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = s.emptyPhoneError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Normalize phone for consistent display in OTP view
    final normalizedPhone = AuthNotifier.normalizePhone(phone);
    try {
      await ref.read(authProvider.notifier).sendOtp(
        phone: phone,
        initialRole: widget.initialRole,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationView(
            phoneNumber: normalizedPhone,
            initialRole: widget.initialRole,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '${s.failedToSendCode} $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.handyman_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                s.enterPhone,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixText: '+92 ',
                  hintText: s.phoneHint,
                  labelText: s.phoneLabel,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isLoading ? null : _sendOtp,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(s.continueEnglish),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.goBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
