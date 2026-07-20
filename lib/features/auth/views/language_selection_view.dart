import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/auth/views/otp_verification_view.dart';

/// Onboarding screen for language selection (Urdu / English)
/// and phone number entry for OTP-based authentication.
class LanguageSelectionView extends ConsumerStatefulWidget {
  const LanguageSelectionView({super.key});

  @override
  ConsumerState<LanguageSelectionView> createState() =>
      _LanguageSelectionViewState();
}

class _LanguageSelectionViewState
    extends ConsumerState<LanguageSelectionView> {
  String _selectedLanguage = 'en';
  final _phoneController = TextEditingController();
  bool _showPhoneInput = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(String lang) {
    setState(() {
      _selectedLanguage = lang;
      _showPhoneInput = true;
    });
    ref.read(localeProvider.notifier).setLocale(lang);
  }

  bool _isLoading = false;

  void _onContinue() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Normalize phone for consistent display in OTP view
    final normalizedPhone = AuthNotifier.normalizePhone(phone);
    try {
      await ref.read(authProvider.notifier).sendOtp(phone: phone);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationView(phoneNumber: normalizedPhone),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send code: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // App logo / branding area
              Icon(
                Icons.handyman_rounded,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedLanguage == 'ur'
                    ? AppConstants.appNameUrdu
                    : AppConstants.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedLanguage == 'ur'
                    ? 'قریبی پیشہ ور افراد سے اپنی ضروریات پوری کریں'
                    : 'Get your local jobs done by nearby professionals',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const Spacer(flex: 1),
              // Language selection (shown before phone input)
              if (!_showPhoneInput) ...[
                _LanguageCard(
                  emoji: '🇬🇧',
                  title: 'English',
                  subtitle: 'Continue in English',
                  isSelected: _selectedLanguage == 'en',
                  onTap: () => _onLanguageSelected('en'),
                ),
                const SizedBox(height: 12),
                _LanguageCard(
                  emoji: '🇵🇰',
                  title: 'اردو',
                  subtitle: 'اردو میں جاری رکھیں',
                  isSelected: _selectedLanguage == 'ur',
                  onTap: () => _onLanguageSelected('ur'),
                ),
              ],
              // Phone input (shown after language selection)
              if (_showPhoneInput) ...[
                Text(
                  _selectedLanguage == 'ur'
                      ? 'اپنا فون نمبر درج کریں'
                      : 'Enter your phone number',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixText: '+92 ',
                    hintText: _selectedLanguage == 'ur'
                        ? '300 1234567'
                        : '300 1234567',
                    labelText: _selectedLanguage == 'ur'
                        ? 'فون نمبر'
                        : 'Phone Number',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _onContinue,
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
                  label: Text(
                    _selectedLanguage == 'ur'
                        ? 'جاری رکھیں'
                        : 'Continue',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showPhoneInput = false;
                    });
                  },
                  child: Text(
                    _selectedLanguage == 'ur' ? 'واپس جائیں' : 'Go back',
                  ),
                ),
              ],
              const Spacer(flex: 2),
              // Footer
              Text(
                _selectedLanguage == 'ur'
                    ? 'جاری رکھنے سے، آپ ہماری شرائط و ضوابط سے اتفاق کرتے ہیں'
                    : 'By continuing, you agree to our Terms & Conditions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textDisabled,
                    ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: 2,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? Colors.white : AppTheme.textDisabled,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
