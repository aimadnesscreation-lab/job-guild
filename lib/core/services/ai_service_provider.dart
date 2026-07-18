import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/services/openrouter_service.dart';

/// Provides the OpenRouter AI service as a singleton.
/// Can be overridden in tests with a mock service.
final aiServiceProvider = Provider<OpenRouterService>((ref) {
  final service = OpenRouterService();
  ref.onDispose(() => service.dispose());
  return service;
});
