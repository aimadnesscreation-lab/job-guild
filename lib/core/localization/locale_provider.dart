import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/strings.dart';

/// Notifier for managing the current app locale ('en' or 'ur')
class LocaleNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  void setLocale(String code) => state = code;
}

/// Current locale code ('en' or 'ur')
final localeProvider = NotifierProvider<LocaleNotifier, String>(
  () => LocaleNotifier(),
);

/// Provides [AppStrings] for the current locale — the single source of
/// translatable text across the app. Views that need localized strings
/// should watch this provider: `ref.watch(appStringsProvider).someString`.
final appStringsProvider = Provider<AppStrings>((ref) {
  final code = ref.watch(localeProvider);
  return AppStrings(code);
});
