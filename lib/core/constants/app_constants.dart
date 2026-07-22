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
  static String? _env(String key) =>
      dotenv.isInitialized ? dotenv.env[key] : null;

  static String get supabaseUrl => _env('SUPABASE_URL') ?? _supabaseUrl;

  static String get supabaseAnonKey =>
      _env('SUPABASE_ANON_KEY') ?? _supabaseAnonKey;

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

  // Source-controlled fallbacks (safe defaults so the app still runs without a .env)
  static const String _supabaseUrl = 'https://izjfugswuwyinaeauhvz.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6amZ1Z3N3dXd5aW5hZWF1aHZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzOTE5MjQsImV4cCI6MjA5OTk2NzkyNH0.BJMENZ9Q8IvUIegjXmaDMVK9NYZHUkJ3-8ovHLJShP0';
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
  static const String openRouterJsonModel =
      'google/gemma-4-26b-a4b-it:free';
  static const String openRouterTextModel =
      'google/gemma-4-26b-a4b-it:free';

  // Feature flags
  static const bool enableAiJobParsing = true;
  static const bool enableAiProfileGeneration = true;
  static const bool useMockAi = false; // Set true to skip API calls for testing
}
