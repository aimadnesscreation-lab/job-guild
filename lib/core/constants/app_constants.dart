class AppConstants {
  AppConstants._();

  // Supabase configuration — replace with your actual project values
  static const String supabaseUrl = 'https://izjfugswuwyinaeauhvz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6amZ1Z3N3dXd5aW5hZWF1aHZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzOTE5MjQsImV4cCI6MjA5OTk2NzkyNH0.BJMENZ9Q8IvUIegjXmaDMVK9NYZHUkJ3-8ovHLJShP0';

  // Google Maps
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

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
  static const String openRouterApiKey = 'YOUR_OPENROUTER_API_KEY';
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  // Free models — routes to any available free model
  static const String openRouterFreeModel = 'openrouter/free';
  // Preferred models for specific tasks
  static const String openRouterJsonModel = 'mistralai/mistral-7b-instruct:free';
  static const String openRouterTextModel = 'meta-llama/llama-3.1-8b-instruct:free';

  // Feature flags
  static const bool enableAiJobParsing = true;
  static const bool enableAiProfileGeneration = true;
  static const bool useMockAi = false; // Set true to skip API calls for testing
}
