import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/auth/views/role_selection_view.dart';

/// Onboarding screen for language selection (Urdu / English).
/// After selecting a language, the user proceeds to role selection.
class LanguageSelectionView extends ConsumerStatefulWidget {
  const LanguageSelectionView({super.key});

  @override
  ConsumerState<LanguageSelectionView> createState() =>
      _LanguageSelectionViewState();
}

class _LanguageSelectionViewState extends ConsumerState<LanguageSelectionView> {
  String _selectedLanguage = 'en';
  bool _showContinue = false;

  void _onLanguageSelected(String lang) {
    setState(() {
      _selectedLanguage = lang;
      _showContinue = true;
    });
    ref.read(localeProvider.notifier).setLocale(lang);
  }

  void _onContinue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionView()),
    );
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
                    : ref.watch(appStringsProvider).appName,
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
                    : ref.watch(appStringsProvider).appTagline,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ),
              const Spacer(flex: 1),
              // Language selection (shown before continue)
              if (!_showContinue) ...[
                _LanguageCard(
                  emoji: '🇬🇧',
                  title: 'English',
                  subtitle: ref.watch(appStringsProvider).continueInEnglish,
                  isSelected: _selectedLanguage == 'en',
                  onTap: () => _onLanguageSelected('en'),
                ),
                const SizedBox(height: 12),
                _LanguageCard(
                  emoji: '🇵🇰',
                  title: 'اردو',
                  subtitle: ref.watch(appStringsProvider).continueInUrdu,
                  isSelected: _selectedLanguage == 'ur',
                  onTap: () => _onLanguageSelected('ur'),
                ),
              ],
              // Continue button (shown after language selection)
              if (_showContinue) ...[
                Text(
                  _selectedLanguage == 'ur'
                      ? 'اپنا اکاؤنٹ بنائیں'
                      : 'Create your account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _selectedLanguage == 'ur'
                        ? 'جاری رکھیں'
                        : ref.watch(appStringsProvider).continueEnglish,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showContinue = false;
                    });
                  },
                  child: Text(ref.watch(appStringsProvider).goBack),
                ),
              ],
              const Spacer(flex: 2),
              // Footer
              Text(
                ref.watch(appStringsProvider).termsFooter,
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
