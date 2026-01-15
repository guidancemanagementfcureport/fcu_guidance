import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_config.dart';

class OpenAIService {
  static const String _apiKey =
      ApiConfig
          .openaiApiKey; // Moved to api_config.dart and .gitignore for security
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<String> generateResponse({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        ...history,
        {'role': 'user', 'content': userMessage},
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint(
          'OpenAI API Error: ${response.statusCode} - ${response.body}',
        );
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      debugPrint('OpenAI Service Error: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  static String _getFallbackResponse(String input) {
    // Basic fallback if API fails
    return "I apologize, but I'm having trouble connecting right now. I'm here to listen though - please continue sharing or contact the guidance office directly if it's urgent.";
  }
}
