import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';

/// State for all user settings backed by the `users` table.
class UserSettings {
  final String preferredLanguage;
  final bool notificationsEnabled;
  final bool jobAlertsEnabled;
  final bool messageAlertsEnabled;
  final int serviceRadiusKm;

  const UserSettings({
    this.preferredLanguage = 'en',
    this.notificationsEnabled = true,
    this.jobAlertsEnabled = true,
    this.messageAlertsEnabled = true,
    this.serviceRadiusKm = 10,
  });

  UserSettings copyWith({
    String? preferredLanguage,
    bool? notificationsEnabled,
    bool? jobAlertsEnabled,
    bool? messageAlertsEnabled,
    int? serviceRadiusKm,
  }) {
    return UserSettings(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      jobAlertsEnabled: jobAlertsEnabled ?? this.jobAlertsEnabled,
      messageAlertsEnabled: messageAlertsEnabled ?? this.messageAlertsEnabled,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
    );
  }

  Map<String, dynamic> toJson() => {
    'preferred_language': preferredLanguage,
    'notifications_enabled': notificationsEnabled,
    'job_alerts_enabled': jobAlertsEnabled,
    'message_alerts_enabled': messageAlertsEnabled,
    'service_radius_km': serviceRadiusKm,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      jobAlertsEnabled: json['job_alerts_enabled'] as bool? ?? true,
      messageAlertsEnabled: json['message_alerts_enabled'] as bool? ?? true,
      serviceRadiusKm: json['service_radius_km'] as int? ?? 10,
    );
  }
}

/// State for the settings provider
class SettingsState {
  final UserSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const SettingsState({
    required this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  SettingsState copyWith({
    UserSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState(settings: const UserSettings(), isLoading: true);
  }

  Future<void> _loadSettings() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      state = SettingsState(settings: const UserSettings(), isLoading: false);
      return;
    }

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final raw = await repo.getUserSettings(userId);
      final settings = UserSettings.fromJson(raw);
      // Sync the locale to match persisted language preference.
      // Schedule as a microtask to avoid modifying another provider's
      // state during the current build() phase.
      Future.microtask(() {
        ref.read(localeProvider.notifier).setLocale(settings.preferredLanguage);
      });
      state = SettingsState(settings: settings, isLoading: false);
    } catch (_) {
      state = SettingsState(settings: const UserSettings(), isLoading: false);
    }
  }

  Future<void> updateLanguage(String languageCode) async {
    final updated = state.settings.copyWith(preferredLanguage: languageCode);
    state = state.copyWith(settings: updated, isSaving: true);
    // Immediately update the locale so the UI reflects the change.
    ref.read(localeProvider.notifier).setLocale(languageCode);
    await _persist();
  }

  Future<void> updateNotificationsEnabled(bool value) async {
    final updated = state.settings.copyWith(notificationsEnabled: value);
    state = state.copyWith(settings: updated, isSaving: true);
    await _persist();
  }

  Future<void> updateJobAlertsEnabled(bool value) async {
    final updated = state.settings.copyWith(jobAlertsEnabled: value);
    state = state.copyWith(settings: updated, isSaving: true);
    await _persist();
  }

  Future<void> updateMessageAlertsEnabled(bool value) async {
    final updated = state.settings.copyWith(messageAlertsEnabled: value);
    state = state.copyWith(settings: updated, isSaving: true);
    await _persist();
  }

  Future<void> updateServiceRadius(int km) async {
    final updated = state.settings.copyWith(serviceRadiusKm: km);
    state = state.copyWith(settings: updated, isSaving: true);
    await _persist();
  }

  Future<void> _persist() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      state = state.copyWith(isSaving: false);
      return;
    }
    try {
      final repo = ref.read(supabaseRepositoryProvider);
      await repo.saveUserSettings(userId, state.settings.toJson());
      state = state.copyWith(isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save: $e',
      );
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  () => SettingsNotifier(),
);
