import '../services/supabase_service.dart';

class OpenAIService {
  static Future<String> generateResponse({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'openai-chat',
        body: {
          'systemPrompt': systemPrompt,
          'userMessage': userMessage,
          'history': history,
        },
      );

      if (response.status == 200) {
        return response.data['content'] as String;
      } else {
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      return _getFallbackResponse(userMessage);
    }
  }

  static String _getFallbackResponse(String input) {
    return "I apologize, but I'm having trouble connecting right now. I'm here to listen though - please continue sharing or contact the guidance office directly if it's urgent.";
  }
}
