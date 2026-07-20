import 'dart:ui' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/strings.dart';

/// Notifier for managing the current app locale ('en' or 'ur')
class LocaleNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  void setLocale(String code) => state = code;
}

/// Current locale code ('en' or 'ur')
final localeProvider =
    NotifierProvider<LocaleNotifier, String>(() => LocaleNotifier());

