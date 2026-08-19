import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config.dart';

class TomTomService {
  Future<List<String>> getSearchSuggestions(String query, LatLng currentPos) async {
    if (query.length < 3) return []; 
    // Lat/Lon rakha hai for nearby POIs, par radius bada diya hai
    final url = Uri.parse("https://api.tomtom.com/search/2/search/${Uri.encodeComponent(query)}.json?key=${Config.tomtomApiKey}&limit=8&lat=${currentPos.latitude}&lon=${currentPos.longitude}&radius=5000000&countrySet=IN&typeahead=true");
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> suggestions = [];
        if (data['results'] != null) {
          for (var result in data['results']) {
            suggestions.add(result['address']['freeformAddress']);
          }
        }
        return suggestions;
      }
    } catch (e) {
      print("Suggestion Error: $e");
    }
    return [];
  }

  Future<LatLng?> getCoordinates(String address, LatLng currentPos) async {
    // 🔴 BUG FIX: Removed lat & lon bias so it searches PAN-India accurately instead of finding nearby streets named "Haryana"
    final url = Uri.parse("https://api.tomtom.com/search/2/search/${Uri.encodeComponent(address)}.json?key=${Config.tomtomApiKey}&limit=1&countrySet=IN");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final position = data['results'][0]['position'];
          return LatLng(position['lat'], position['lon']);
        }
      }
    } catch (e) {
      print("Geocoding Error: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> getRoute(LatLng start, LatLng end, String mode) async {
    String travelMode = 'car';
    if (mode == 'Bike') travelMode = 'motorcycle';
    if (mode == 'Walk') travelMode = 'pedestrian';
    if (mode == 'Truck') travelMode = 'truck'; 

    final url = Uri.parse("https://api.tomtom.com/routing/1/calculateRoute/${start.latitude},${start.longitude}:${end.latitude},${end.longitude}/json?key=${Config.tomtomApiKey}&travelMode=$travelMode&traffic=true&routeType=fastest&instructionsType=text");
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final points = data['routes'][0]['legs'][0]['points'];
        List<LatLng> routePoints = points.map<LatLng>((p) => LatLng(p['latitude'], p['longitude'])).toList();
        
        final summary = data['routes'][0]['summary'];
        int travelTimeInSeconds = summary['travelTimeInSeconds'];
        int lengthInMeters = summary['lengthInMeters'];
        int trafficDelayInSeconds = summary['trafficDelayInSeconds'] ?? 0;

        List<String> instructions = [];
        if (data['routes'][0]['guidance'] != null && data['routes'][0]['guidance']['instructions'] != null) {
          for (var inst in data['routes'][0]['guidance']['instructions']) {
            instructions.add(inst['message']);
          }
        }

        return {
          'points': routePoints,
          'time': (travelTimeInSeconds / 60).round(),
          'distance': (lengthInMeters / 1000).toStringAsFixed(1),
          'rawDistanceKm': (lengthInMeters / 1000), 
          'trafficDelay': trafficDelayInSeconds, 
          'instructions': instructions, 
        };
      }
    } catch (e) {
      print("Routing Error: $e");
    }
    return {};
  }
}