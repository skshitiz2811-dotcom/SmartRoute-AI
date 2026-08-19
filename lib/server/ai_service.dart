import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Laptop ka Wi-Fi IPv4 address
  static const String baseUrl = 'http://10.114.204.1:8000';

  static Future<String> askAI(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask-ai'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data['answer'] ?? 'No answer received.';
      } else {
        return 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}