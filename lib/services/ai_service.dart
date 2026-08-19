import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class AIService {
  final String _baseUrl = "https://api.featherless.ai/v1/chat/completions";

  // 1. 🛣️ Smart Route Explanation (Tells WHY this route is best)
  Future<String> explainRoute({
    required String destination,
    required String distance,
    required String duration,
    required String transportMode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${Config.featherlessApiKey}",
        },
        body: jsonEncode({
          "model": Config.featherlessModel,
          "messages": [
            {
              "role": "system",
              "content": "You are SmartRoute AI, an intelligent navigation and driving assistant. Keep answers concise (under 3 sentences), highly actionable, and safety-focused."
            },
            {
              "role": "user",
              "content": "I am traveling to $destination by $transportMode. Distance: $distance, Time: $duration. Give me a 2-sentence summary explaining why this route is optimal (mention traffic, eco-savings, and a quick safety tip)."
            }
          ],
          "max_tokens": 120,
          "temperature": 0.6,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        return "Optimal route selected with low traffic congestion and optimal fuel efficiency.";
      }
    } catch (e) {
      return "Optimal route selected with low traffic congestion and optimal fuel efficiency.";
    }
  }

  // 2. 🧳 AI Trip Planner & Travel Guide
  Future<String> generateTripPlan({
    required String from,
    required String to,
    required String days,
    required String budget,
    required String vehicle,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${Config.featherlessApiKey}",
        },
        body: jsonEncode({
          "model": Config.featherlessModel,
          "messages": [
            {
              "role": "system",
              "content": "You are a professional travel planner and road trip safety guide. Output structured, easy-to-read travel plans with scenic stops, food recommendations, and rest stop advice."
            },
            {
              "role": "user",
              "content": "Plan a road trip from $from to $to for $days days by $vehicle on a $budget budget. Include safe rest stops, must-visit places, and driving precautions."
            }
          ],
          "max_tokens": 500,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        return "Unable to generate plan right now. Please check your network connection.";
      }
    } catch (e) {
      return "Error connecting to AI Travel Planner: $e";
    }
  }
}