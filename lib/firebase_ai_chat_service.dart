import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config/env.dart';

class FirebaseAIChatService {
  static const String _apiKey = Env.geminiApiKey;
  static const String _model = 'gemini-2.5-flash';
  static final List<Map<String, dynamic>> _history = [];

  static const String _systemPrompt = '''
Tu es un assistant virtuel spécialisé dans l'accompagnement des aidants de patients atteints de la maladie d'Alzheimer.
Réponds en français, sois concis (2-3 paragraphes maximum), positif et rassurant.
Ne fais JAMAIS de diagnostic médical.
''';

  static void initialize() {
    print("[Gemini HTTP] Initialisé ");
  }

  static void startNewChat() {
    _history.clear();
  }

  static Future<String> sendMessage(String userMessage) async {
    try {
      _history.add({
        "role": "user",
        "parts": [{"text": userMessage}]
      });

      final url = Uri.parse(

          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey'
      );

      final contents = [
        {
          "role": "user",
          "parts": [{"text": _systemPrompt}]
        },
        {
          "role": "model",
          "parts": [{"text": "Compris ! Je suis prêt à aider les aidants AlzheCare."}]
        },
        ..._history
      ];

      final body = jsonEncode({
        "contents": contents,
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 1000,
        }
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'];
        _history.add({
          "role": "model",
          "parts": [{"text": reply}]
        });
        return reply;
      } else {
        final error = jsonDecode(response.body);
        final errorMsg = error['error']['message'] ?? 'Erreur inconnue';
        return "Désolé, une erreur s'est produite.\n\n(Erreur: $errorMsg)";
      }
    } catch (e) {
      return "Désolé, une erreur de connexion s'est produite.";
    }
  }

  static List<String> getSuggestions() {
    return [
      "Comment gérer l'agitation le soir ?",
      "Quelles activités proposer ?",
      "Comment réagir aux oublis ?",
      "Conseils pour moi en tant qu'aidant",
      "Mon proche refuse de manger",
      "Il ne me reconnaît plus, que faire ?",
    ];
  }

  static void resetChat() {
    _history.clear();
  }

  static List<Map<String, dynamic>> getHistory() {
    return _history;
  }
}