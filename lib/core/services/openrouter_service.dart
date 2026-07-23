import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/utils/budget_parser.dart';

/// Service for calling OpenRouter AI models (replaces Claude).
/// Supports JSON extraction and text generation using free models.
class OpenRouterService {
  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;

  OpenRouterService({String? apiKey, String? baseUrl})
    : _apiKey = apiKey ?? AppConstants.openRouterApiKey,
      _baseUrl = baseUrl ?? AppConstants.openRouterBaseUrl,
      _httpClient = http.Client();

  /// Generate text response with retry logic for transient failures.
  Future<String> generateText({
    required String prompt,
    String? systemPrompt,
    String model = AppConstants.openRouterTextModel,
    double temperature = 0.7,
    int maxTokens = 500,
    int retries = 1,
  }) async {
    if (AppConstants.useMockAi || !AppConstants.isOpenRouterConfigured) {
      return _mockTextResponse(prompt);
    }

    try {
      return await _callWithRetry(() => _doGenerateText(
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
      ), retries);
    } catch (e) {
      debugPrint('[OpenRouter] Text generation failed after retries: $e');
      return _mockTextResponse(prompt);
    }
  }

  Future<String> _doGenerateText({
    required String prompt,
    String? systemPrompt,
    required String model,
    required double temperature,
    required int maxTokens,
  }) async {
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

    final response = await _postRequest('/chat/completions', body)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(response) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    if (choices.isEmpty) throw Exception('No response from AI');
    return choices[0]['message']['content'] as String;
  }

  /// Generate structured JSON response with retry logic for transient failures.
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    String? systemPrompt,
    String model = AppConstants.openRouterJsonModel,
    double temperature = 0.1,
    int maxTokens = 500,
    int retries = 1,
  }) async {
    if (AppConstants.useMockAi || !AppConstants.isOpenRouterConfigured) {
      return _mockJsonResponse(prompt);
    }

    try {
      return await _callWithRetry(() => _doGenerateJson(
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
      ), retries);
    } catch (e) {
      debugPrint('[OpenRouter] JSON generation failed after retries: $e');
      return _mockJsonResponse(prompt);
    }
  }

  Future<Map<String, dynamic>> _doGenerateJson({
    required String prompt,
    String? systemPrompt,
    required String model,
    required double temperature,
    required int maxTokens,
  }) async {
    final messages = <Map<String, String>>[];
    if (systemPrompt != null) {
      messages.add({
        'role': 'system',
        'content':
            '$systemPrompt\n\nIMPORTANT: Return ONLY valid JSON. No markdown, no code fences.',
      });
    }
    messages.add({
      'role': 'user',
      'content':
          '$prompt\n\nReturn ONLY valid JSON. No markdown, no code fences.',
    });

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await _postRequest('/chat/completions', body)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(response) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    if (choices.isEmpty) throw Exception('No response from AI');

    final content = choices[0]['message']['content'] as String;
    final cleaned = content
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  /// Retry helper for API calls — retries on 429 and 5xx transient errors.
  Future<T> _callWithRetry<T>(Future<T> Function() call, int retries) async {
    try {
      return await call();
    } catch (e) {
      if (retries > 0 && e is Exception) {
        final msg = e.toString();
        final isRetryable = msg.contains('HTTP 429') ||
            msg.contains('HTTP 502') ||
            msg.contains('HTTP 503') ||
            msg.contains('HTTP 504');
        if (isRetryable) {
          await Future.delayed(const Duration(seconds: 2));
          return _callWithRetry(call, retries - 1);
        }
      }
      rethrow;
    }
  }

  /// Make HTTP POST request to OpenRouter API
  Future<String> _postRequest(String path, String body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'HTTP-Referer': 'https://localservices.app',
        'X-Title': 'Local Services Marketplace',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenRouter API error ${response.statusCode}: ${response.body}',
      );
    }
    return response.body;
  }

  /// Dispose the HTTP client
  void dispose() {
    _httpClient.close();
  }

  // ─── Mock fallbacks (used when API key not set or in test mode) ──────

  String _mockTextResponse(String input) {
    return 'Professional with $input. Dedicated to providing high-quality '
        'service with attention to detail and customer satisfaction. '
        'Available for projects of all sizes.';
  }

  Map<String, dynamic> _mockJsonResponse(String input) {
    final lower = input.toLowerCase();
    final category = guessCategory(input);

    return {
      'category': category,
      'urgency': guessUrgency(input),
      'suggested_budget_pkr': estimateBudget(lower, category),
      'estimated_duration_hours': estimateDuration(lower),
      'required_skills': [category],
    };
  }
}
