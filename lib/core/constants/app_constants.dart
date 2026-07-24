import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // ─── Secrets (override via .env; see .env.example) ─────────────
  // The anon key is designed to be public (RLS protects data). The OpenRouter
  // key is a real secret and should always come from .env, never be committed.

  /// Reads an env var without throwing. `dotenv.env` throws
  /// [NotInitializedError] if `dotenv.load()` was never called (e.g. in tests,
  /// or when no `.env` file exists and the app falls back to defaults). This
  /// helper returns null in that case so the `??` fallbacks below actually
  /// apply — otherwise the app would crash at startup instead of using
  /// source-controlled defaults.
  /// Reads an env var from: (1) dotenv (runtime `assets/.env`), or (2)
  /// `--dart-define` (compile-time, preferred for web builds).
  ///
  /// The `--dart-define` fallback ensures web builds work even when the
  /// Flutter service-worker hasn't updated the asset manifest for `.env`.
  static String? _env(String key) {
    if (dotenv.isInitialized) {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) return value;
    }
    // Fallback: compile-time --dart-define (always available in web release builds)
    final fromDefine = String.fromEnvironment(key, defaultValue: '');
    return fromDefine.isNotEmpty ? fromDefine : null;
  }

  static String get supabaseUrl {
    // Return an empty string when .env is not loaded (e.g. widget tests).
    // Callers that need a real connection (main.dart, integration tests)
    // should check [isSupabaseConfigured] and handle the missing config case.
    return _env('SUPABASE_URL') ?? '';
  }

  static String get supabaseAnonKey {
    return _env('SUPABASE_ANON_KEY') ?? '';
  }

  /// True when both Supabase URL and anon key are configured.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get openRouterApiKey {
    final value = _env('OPENROUTER_API_KEY');
    return value != null && value.isNotEmpty
        ? value
        : _openRouterApiKeyPlaceholder;
  }

  /// True only when a real OpenRouter key (not the placeholder) is configured.
  /// Used to short-circuit the client-side AI tier instead of firing a
  /// doomed request that would always 401.
  static bool get isOpenRouterConfigured =>
      openRouterApiKey.trim().isNotEmpty &&
      openRouterApiKey != _openRouterApiKeyPlaceholder;

  static const String _openRouterApiKeyPlaceholder = 'YOUR_OPENROUTER_API_KEY';

  // App metadata
  static const String appName = 'Local Services Marketplace';
  static const String appNameUrdu = 'مقامی خدمات مارکیٹ پلیس';
  static const String defaultCity = 'Lahore';
  static const String defaultCurrency = 'PKR';
  static const double defaultLatitude = 31.5204;
  static const double defaultLongitude = 74.3587;

  // Limits & constraints
  static const int maxServiceRadiusKm = 50;
  static const int defaultServiceRadiusKm = 10;
  static const int maxPortfolioImages = 10;
  static const int maxJobDescriptionLength = 2000;
  static const int minJobTitleLength = 5;
  static const int maxJobTitleLength = 100;

  // OpenRouter AI (replaces Claude — free models via OpenRouter)
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  // Free auto-router — picks the best available free model automatically
  static const String openRouterFreeModel = 'openrouter/free';
  // Google Gemma 4 — modern free model, reliable for JSON and text tasks
  static const String openRouterJsonModel = 'google/gemma-4-26b-a4b-it:free';
  static const String openRouterTextModel = 'google/gemma-4-26b-a4b-it:free';

  // Feature flags
  static const bool enableAiJobParsing = true;
  static const bool enableAiProfileGeneration = true;
  static const bool useMockAi = false; // Set true to skip API calls for testing
}
