import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class AIService {
  Future<String> chat(
    AIProviderConfig provider,
    List<Message> messages,
  ) async {
    final url = '${provider.baseUrl}/chat/completions';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${provider.apiKey}',
    };
    final body = jsonEncode({
      'model': provider.model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': 0.7,
    });

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('API error: ${response.statusCode} - ${response.body}');
    }
  }
}
