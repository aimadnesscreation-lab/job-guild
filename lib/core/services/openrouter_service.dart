import 'dart:convert';
import 'dart:io';
import 'package:local_services_marketplace/core/constants/app_constants.dart';

/// Service for calling OpenRouter AI models (replaces Claude).
/// Supports JSON extraction and text generation using free models.
class OpenRouterService {
  final String _apiKey;
  final String _baseUrl;
  final HttpClient _httpClient;

  OpenRouterService({
    String? apiKey,
    String? baseUrl,
  })  : _apiKey = apiKey ?? AppConstants.openRouterApiKey,
        _baseUrl = baseUrl ?? AppConstants.openRouterBaseUrl,
        _httpClient = HttpClient();

  /// Generate text response (e.g., bio writing).
  /// Uses the text model by default.
  Future<String> generateText({
    required String prompt,
    String? systemPrompt,
    String model = AppConstants.openRouterTextModel,
    double temperature = 0.7,
    int maxTokens = 500,
  }) async {
    if (AppConstants.useMockAi || !AppConstants.isOpenRouterConfigured) {
      return _mockTextResponse(prompt);
    }

    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      });

      final response = await _postRequest('/chat/completions', body);
      final data = jsonDecode(response) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isEmpty) throw Exception('No response from AI');
      return choices[0]['message']['content'] as String;
    } catch (e) {
      // Fallback to mock on error
      return _mockTextResponse(prompt);
    }
  }

  /// Generate structured JSON response (e.g., job parsing).
  /// Uses the JSON-capable model.
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    String? systemPrompt,
    String model = AppConstants.openRouterJsonModel,
    double temperature = 0.1, // Low temp for deterministic JSON
    int maxTokens = 500,
  }) async {
    if (AppConstants.useMockAi || !AppConstants.isOpenRouterConfigured) {
      return _mockJsonResponse(prompt);
    }

    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt != null) {
        messages.add({
          'role': 'system',
          'content':
              '$systemPrompt\n\nIMPORTANT: Return ONLY valid JSON. No markdown, no code fences, no additional text.',
        });
      }
      messages.add({
        'role': 'user',
        'content':
            '$prompt\n\nReturn ONLY valid JSON. No markdown fences (no \`\`\`). No explanation. Just the JSON object.',
      });

      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      });

      final response = await _postRequest('/chat/completions', body);
      final data = jsonDecode(response) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isEmpty) throw Exception('No response from AI');

      final content = choices[0]['message']['content'] as String;
      // Strip any markdown fences if the model ignored instructions
      final cleaned = content
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
          .trim();

      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      // Fallback to mock on error
      return _mockJsonResponse(prompt);
    }
  }

  /// Make HTTP POST request to OpenRouter API
  Future<String> _postRequest(String path, String body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = await _httpClient.postUrl(uri);

    // OpenRouter required headers
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer $_apiKey');
    request.headers.set('HTTP-Referer', 'https://localservices.app');
    request.headers.set('X-Title', 'Local Services Marketplace');

    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw HttpException(
        'OpenRouter API error ${response.statusCode}: $responseBody',
      );
    }
    return responseBody;
  }

  /// Dispose the HTTP client
  void dispose() {
    _httpClient.close(force: true);
  }

  // ─── Mock fallbacks (used when API key not set or in test mode) ──────

  String _mockTextResponse(String input) {
    return 'Professional with $input. Dedicated to providing high-quality '
        'service with attention to detail and customer satisfaction. '
        'Available for projects of all sizes.';
  }

  Map<String, dynamic> _mockJsonResponse(String input) {
    final lower = input.toLowerCase();
    String category = 'General Labor';
    if (lower.contains('plumb')) category = 'Plumbing';
    else if (lower.contains('electr')) category = 'Electrical';
    else if (lower.contains('paint')) category = 'Painting';
    else if (lower.contains('carpent')) category = 'Carpentry';
    else if (lower.contains('clean')) category = 'Cleaning';
    else if (lower.contains('tutor') || lower.contains('teach')) category = 'Tutor';
    else if (lower.contains('mechanic')) category = 'Mechanic';
    else if (lower.contains('cook')) category = 'Cook';
    else if (lower.contains('move')) category = 'Moving';

    return {
      'category': category,
      'urgency': lower.contains('urgent') || lower.contains('emergency')
          ? 'instant'
          : lower.contains('tomorrow') || lower.contains('next week')
              ? 'scheduled'
              : 'today',
      'suggested_budget_pkr': _estimateBudget(lower, category),
      'estimated_duration_hours': _estimateDuration(lower),
      'required_skills': [category],
    };
  }

  int _estimateBudget(String input, String category) {
    final match = RegExp(r'(\d+)\s*[kK]?').firstMatch(input);
    if (match != null) {
      final num = int.parse(match.group(1)!);
      return input.contains('k') || input.contains('K') ? num * 1000 : num;
    }
    // Default estimates by category
    const budgets = {
      'Plumbing': 3000, 'Electrical': 3500, 'Painting': 4000,
      'Carpentry': 3500, 'Cleaning': 1500, 'Tutor': 500,
      'Mechanic': 3000, 'Moving': 5000, 'Cook': 2000,
    };
    return budgets[category] ?? 2000;
  }

  int _estimateDuration(String input) {
    if (input.contains('hour') || input.contains('hr')) return 1;
    if (input.contains('day')) return 8;
    if (input.contains('week')) return 40;
    return 2; // default 2 hours
  }
}
