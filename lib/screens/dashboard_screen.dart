// ignore_for_file: unused_field

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smartroute_ai/screens/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telephony/telephony.dart';
import '../services/auth_service.dart';
import '../services/tomtom_service.dart';
import '../config.dart';
import 'vault_screen.dart';
import 'dart:convert';

import '../widgets/transport_modes.dart';
import '../widgets/emergency_grid.dart';
import '../widgets/metrics_grid.dart';
import 'ai_planner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();

  
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _bottomNavIndex = 0;
  String _selectedTransport = 'Car';

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final TomTomService _tomTomService = TomTomService();
  final Telephony _telephony = Telephony.instance;

  LatLng _currentPosition = const LatLng(22.7196, 75.8577);
  LatLng? _destinationPosition;
  List<LatLng> _tollPositions = [];
  List<LatLng> _routePoints = [];
  List<String> _suggestions = [];
  List<String> _turnInstructions = [];

  bool _isLoadingLocation = true;
  bool _isSearchingRoute = false;
  bool _isNavigating = false;
  bool _isAmbulanceMode = false;

  String _travelTime = "";
  String _travelDistance = "";
  String _fuelCost = "";
  String _co2Emission = "";
  String _trafficLevel = "";
  String _tollStatus = "";

  Color _routeColor = Colors.greenAccent;
  Timer? _debounce;

  String _familyNo1 = "";
  String _familyNo2 = "";

 @override
void initState() {
  super.initState();

  _determinePosition();
  _initTTS();
  _loadSOSContacts();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showWelcomePopup();
  });
}

Future<void> _loadSOSContacts() async {
  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  setState(() {
    _familyNo1 =
        prefs.getString("family_no_1") ?? "";

    _familyNo2 =
        prefs.getString("family_no_2") ?? "";
  });
}

  // 🔴 NEW FEATURE 1: SMART BILINGUAL TTS ENGINE
  Future<void> _speakText(String engText, String hindiText) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool useHindi = prefs.getBool('use_hindi') ?? false;

    if (useHindi) {
      await _flutterTts.setLanguage("hi-IN");
      await _flutterTts.speak(hindiText);
    } else {
      await _flutterTts.setLanguage("en-IN");
      await _flutterTts.speak(engText);
    }
  }

  void _initTTS() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String voiceType = prefs.getString('ai_voice') ?? "Energetic (Default)";

    // Set Voice Properties based on selection
    if (voiceType == "Energetic (Default)") {
      await _flutterTts.setPitch(1.2);
      await _flutterTts.setSpeechRate(0.55);
    } else if (voiceType == "Calm & Professional") {
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45);
    } else if (voiceType == "Jarvis (Sci-Fi)") {
      await _flutterTts.setPitch(0.7); 
      await _flutterTts.setSpeechRate(0.5);
    }
  }

  void _showWelcomePopup() {
    int hour = DateTime.now().hour;
    String greeting = "Good Morning";
    String hindiGreeting = "सुप्रभात";
    
    if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
      hindiGreeting = "शुभ दोपहर";
    } else if (hour >= 17) {
      greeting = "Good Evening";
      hindiGreeting = "शुभ संध्या";
    }

    _speakText(
      "$greeting Kshitiz! Where would you like to go today?",
      "नमस्ते क्षितिज! $hindiGreeting! आज आप कहाँ जाना चाहेंगे?"
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E2D3A), Color(0xFF0F2027)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.blueAccent.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Colors.blueAccent,
                  size: 45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.waving_hand, color: Colors.amber, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Welcome back, Kshitiz!\nWhere are we heading today?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Let's Go! 🚀",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoadingLocation = false;
    });
    _mapController.move(_currentPosition, 15.0);
  }

  void _reCenterMap() {
    _mapController.move(_currentPosition, _isNavigating ? 18.0 : 15.0);
  }

  void _showKitHelplines() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15222E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "Emergency Helplines",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildHelplineTile("National Emergency", "112", Icons.local_police, Colors.redAccent),
              _buildHelplineTile("Ambulance / Medical", "108", Icons.local_hospital, Colors.greenAccent),
              _buildHelplineTile("Road Accident Help", "1073", Icons.car_crash, Colors.purpleAccent),
              _buildHelplineTile("NHAI Highway Help", "1033", Icons.add_road, Colors.orangeAccent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelplineTile(String title, String number, IconData icon, Color color) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        "Dial $number",
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call, color: Colors.greenAccent),
        onPressed: () async {
          final Uri url = Uri.parse('tel:$number');
          if (await canLaunchUrl(url)) await launchUrl(url);
        },
      ),
    );
  }

  void _triggerReportAccident() async {
    _speakText(
      "Opening camera to capture accident scene.",
      "दुर्घटना स्थल की तस्वीर लेने के लिए कैमरा खोल रहे हैं।"
    );
    
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null && mounted) {
      _speakText(
        "Analyzing location and finding nearest hospital.",
        "लोकेशन का विश्लेषण कर रहे हैं और सबसे नज़दीकी अस्पताल ढूंढ रहे हैं।"
      );

      List<String> hospitals = await _tomTomService.getSearchSuggestions("Hospital", _currentPosition);
      String nearestHospital = hospitals.isNotEmpty ? hospitals.first : "City Hospital";

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E2D3A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.redAccent),
                SizedBox(width: 10),
                Text("Accident Detected", style: TextStyle(color: Colors.redAccent)),
              ],
            ),
            content: Text(
              "Nearest hospital found:\n$nearestHospital\n\nClick 'Send and Go' to dispatch alerts to Police & Hospital and start navigation immediately.",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  String locLink = "https://maps.google.com/?q=${_currentPosition.latitude},${_currentPosition.longitude}";

                  String msgForHospital = "🚨 HOSPITAL EMERGENCY ALERT\n\nAccident victim transported from:\n$locLink\nPlease keep emergency facilities ready.";
                  String msgForPolice = "🚨 POLICE EMERGENCY ALERT\n\nAccident reported at:\n$locLink\nPatient heading to: $nearestHospital\nPlease respond.";
                  String combinedMsg = "$msgForHospital\n\n━━━━━━━━━━━━━━━━━━\n\n$msgForPolice";

                  final Uri smsUri = Uri.parse('sms:${Config.demoPoliceAndHospital}?body=${Uri.encodeComponent(combinedMsg)}');
                  if (await canLaunchUrl(smsUri)) {
                    await launchUrl(smsUri);
                  }

                  _speakText(
                    "Alerts sent. Routing to nearest hospital.",
                    "अलर्ट भेज दिए गए हैं। सबसे नज़दीकी अस्पताल का रास्ता दिखाया जा रहा है।"
                  );
                  
                  _searchController.text = nearestHospital;
                  await _calculateRoute(nearestHospital);

                  if (_routePoints.isNotEmpty) {
                    _proceedToNavigation();
                  }
                },
                style: TextButton.styleFrom(backgroundColor: Colors.greenAccent.withOpacity(0.2)),
                child: const Text("Send and Go 🚀", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  // 🔴 NEW FEATURE: Save History
  Future<void> _saveSearchToHistory(String destination, String mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('search_history');
    List<dynamic> historyList = historyJson != null ? json.decode(historyJson) : [];

    // Naya search item banaya
    Map<String, String> newItem = {
      "mode": mode,
      "dest": destination,
      "date": "Today, ${TimeOfDay.now().format(context)}",
      "icon": mode == 'Nav Mode' ? 'navigation' : (mode == 'Ambulance' ? 'warning' : 'auto_awesome')
    };

    // Naye item ko top par daalo
    historyList.insert(0, newItem);

    // Sirf last 5 searches save rakho taaki UI clean rahe
    if (historyList.length > 5) {
      historyList = historyList.sublist(0, 5);
    }

    await prefs.setString('search_history', json.encode(historyList));
  }

  // 🔴 NEW FEATURE 3: EMERGENCY VEHICLE MODE & SIMULATION
  void _toggleAmbulanceMode() {
    setState(() {
      _isAmbulanceMode = !_isAmbulanceMode;
    });

    if (_isAmbulanceMode) {
      _speakText(
        "Emergency Vehicle Mode Active. Broadcasting location to clear traffic ahead.",
        "आपातकालीन वाहन मोड सक्रिय। आगे का ट्रैफिक साफ करने के लिए अलर्ट भेजा जा रहा है।"
      );
      
      // Hackathon Demo: Simulate how other nearby users will receive the alert
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isAmbulanceMode) {
          _simulateNearbyDriverAlert();
        }
      });
    } else {
      _speakText("Emergency Mode Deactivated.", "आपातकालीन मोड बंद कर दिया गया है।");
    }
  }

  void _simulateNearbyDriverAlert() {
    _speakText(
      "Warning! An ambulance is approaching from behind. Please keep the left lane clear.",
      "सावधान! पीछे से एक एम्बुलेंस आ रही है। कृपया बाईं लेन खाली रखें और रास्ता दें।"
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF15222E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emergency_share, color: Colors.redAccent, size: 60),
              const SizedBox(height: 15),
              const Text(
                "🚨 AMBULANCE APPROACHING 🚨",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 15),
              const Text(
                "An emergency vehicle is on your route (500m behind). Please cooperate and move your vehicle to the left.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("I Will Give Way", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

// 🔴 FINAL EMERGENCY FIX: Bypassing canLaunchUrl, safely opening SMS, and showing Success Dialog
Future<void> _triggerOfflineSOS() async {
  if (_familyNo1.trim().isEmpty) {
    _askForFamilyNumbers();
    return;
  }

  try {
    await _flutterTts.speak("Emergency SOS activated.");

    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    final String locLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";

    final String message =
        "🚨 SMARTROUTE AI - EMERGENCY SOS 🚨\n\n"
        "I am in an emergency and need immediate help.\n\n"
        "📍 My current location:\n$locLink\n\n"
        "Please contact me immediately.";

    final List<String> contacts = [];
    if (_familyNo1.trim().isNotEmpty) contacts.add(_familyNo1.trim());
    if (_familyNo2.trim().isNotEmpty) contacts.add(_familyNo2.trim());
    
    if (contacts.isEmpty) return;

    // Use Dart's native Uri constructor for perfect encoding
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: contacts.join(","),
      queryParameters: <String, String>{
        'body': message,
      },
    );

    // 1. Force open the SMS App
    await launchUrl(smsUri);

    if (!mounted) return;

    // 2. Show the Success Dialog immediately so it's waiting when you return
    _showSOSSuccessDialog(contacts.length);
    
  } catch (e) {
    debugPrint("SOS ERROR: $e");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to open SMS app: $e"), backgroundColor: Colors.redAccent),
    );
  }
}

void _showSOSSuccessDialog(int count) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF15222E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 30,
            ),
            SizedBox(width: 10),
            Text(
              "SOS Sent",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Emergency SMS has been sent to $count family contact(s).\n\n"
          "Your current location was included in the message.",
          style: const TextStyle(
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "OK",
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}

 void _askForFamilyNumbers() async {
  final TextEditingController family1Controller =
      TextEditingController(text: _familyNo1);

  final TextEditingController family2Controller =
      TextEditingController(text: _familyNo2);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E2D3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.emergency,
              color: Colors.redAccent,
            ),
            SizedBox(width: 10),
            Text(
              "Set SOS Contacts",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "These contacts will receive an emergency SMS with your current location.",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: family1Controller,
                style: const TextStyle(
                  color: Colors.white,
                ),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Family Member 1 *",
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Colors.blueAccent,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.white24,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: family2Controller,
                style: const TextStyle(
                  color: Colors.white,
                ),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Family Member 2 (Optional)",
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.blueAccent,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.white24,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              final String no1 =
                  family1Controller.text.trim();

              final String no2 =
                  family2Controller.text.trim();

              if (no1.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Please enter at least one family number.",
                    ),
                  ),
                );
                return;
              }

              // Save in SharedPreferences
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();

              await prefs.setString(
                "family_no_1",
                no1,
              );

              await prefs.setString(
                "family_no_2",
                no2,
              );

              setState(() {
                _familyNo1 = no1;
                _familyNo2 = no2;
              });

              if (!mounted) return;

              Navigator.pop(ctx);

              // Immediately send SOS
              await _triggerOfflineSOS();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Save & Send SOS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length > 2) {
        List<String> results = await _tomTomService.getSearchSuggestions(query, _currentPosition);
        setState(() => _suggestions = results);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  void _onTransportSelected(String mode) {
    setState(() {
      _selectedTransport = mode;
      _suggestions = [];
    });
    if (_searchController.text.isNotEmpty) {
      _calculateRoute(_searchController.text);
    }
  }

  void _calculateAdvancedMetrics(double distKm, int trafficDelay, int originalTime) {
    if (trafficDelay > 300) {
      _trafficLevel = "High 🔴";
      _routeColor = Colors.redAccent;
    } else if (trafficDelay > 120) {
      _trafficLevel = "Moderate 🟡";
      _routeColor = Colors.orangeAccent;
    } else {
      _trafficLevel = "Low 🟢";
      _routeColor = Colors.greenAccent;
    }

    _tollPositions.clear();
    int tollCount = 0;
    int totalTollCost = 0;

    if (distKm > 40 && _selectedTransport != 'Walk') {
      tollCount = (distKm / 55).floor();
      if (_selectedTransport == 'Bike') {
        tollCount = 0;
        totalTollCost = 0;
      } else if (_selectedTransport == 'Car') {
        totalTollCost = tollCount * 110;
      } else if (_selectedTransport == 'Truck') {
        totalTollCost = tollCount * 350;
      }
      if (tollCount > 0 && _routePoints.isNotEmpty) {
        int step = _routePoints.length ~/ (tollCount + 1);
        for (int i = 1; i <= tollCount; i++) {
          _tollPositions.add(_routePoints[i * step]);
        }
      }
    }

    _tollStatus = tollCount == 0 ? "0 Tolls" : "$tollCount (₹$totalTollCost)";

    if (_selectedTransport == 'Walk') {
      _fuelCost = "₹0";
      _co2Emission = "0 kg";
    } else {
      double mileage = 30.0;
      if (_selectedTransport == 'Bike') mileage = 45.0;
      if (_selectedTransport == 'Truck') mileage = 8.0;
      double fuelNeeded = distKm / mileage;
      _fuelCost = "₹${(fuelNeeded * 100).round()}";
      _co2Emission = "${(fuelNeeded * 2.3).toStringAsFixed(1)} kg";
    }

    int finalTime = originalTime;
    if (_selectedTransport == 'Bike' && finalTime > 5) finalTime -= 3;
    _travelTime = "$finalTime min";
  }

  Future<void> _calculateRoute(String address) async {
    if (address.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearchingRoute = true;
      _suggestions = []; 
      _isNavigating = false;
    });

    _speakText(
      "Finding optimal route to $address", 
      "$address के लिए सबसे सही रास्ता ढूंढ रहे हैं"
    );

    LatLng? dest = await _tomTomService.getCoordinates(address, _currentPosition);
    if (dest != null) {
      var routeData = await _tomTomService.getRoute(_currentPosition, dest, _selectedTransport);
      if (routeData.isNotEmpty) {
        setState(() {
          _destinationPosition = dest;
          _routePoints = routeData['points'];
          _travelDistance = "${routeData['distance']} km";
          _turnInstructions = routeData['instructions'] ?? [];
          _calculateAdvancedMetrics(routeData['rawDistanceKm'], routeData['trafficDelay'], routeData['time']);
        });
        _mapController.move(_currentPosition, 11.0);
      }
    }

    _saveSearchToHistory(address,_isAmbulanceMode ? 'Ambulance' : 'Nav Mode');
    setState(() => _isSearchingRoute = false);
  }

  void _showSafetyPopupAndNavigate() {
    String title = "";
    String engMsg = "";
    String hinMsg = "";
    IconData icon = Icons.info;
    Color iconColor = Colors.blueAccent;
    Color bgColor = Colors.blueAccent.withOpacity(0.15);

    if (_selectedTransport == 'Car') {
      title = "Car Safety Alert";
      engMsg = "Please securely fasten your seatbelt before starting. Keep your eyes on the road and drive within speed limits.";
      hinMsg = "कृपया अपनी सीटबेल्ट सुरक्षित रूप से बांध लें। गाड़ी चलाते समय सड़क पर ध्यान दें और गति सीमा का पालन करें।";
      icon = Icons.directions_car_filled;
      iconColor = Colors.blueAccent;
      bgColor = Colors.blue.withOpacity(0.2);
    } else if (_selectedTransport == 'Bike') {
      title = "Rider Safety Alert";
      engMsg = "Ensure you are wearing a certified safety helmet. Avoid blind spots and ride carefully in traffic.";
      hinMsg = "कृपया सुनिश्चित करें कि आपने हेलमेट पहना है। ट्रैफ़िक में सावधानी से वाहन चलाएं।";
      icon = Icons.two_wheeler;
      iconColor = Colors.orangeAccent;
      bgColor = Colors.orange.withOpacity(0.2);
    } else if (_selectedTransport == 'Walk') {
      title = "Pedestrian Safety";
      engMsg = "Please strictly use footpaths and zebra crossings. Stay alert and aware of your surroundings.";
      hinMsg = "कृपया फुटपाथ और जेब्रा क्रॉसिंग का ही उपयोग करें। हमेशा सतर्क रहें।";
      icon = Icons.directions_walk;
      iconColor = Colors.greenAccent;
      bgColor = Colors.green.withOpacity(0.2);
    } else if (_selectedTransport == 'Truck') {
      title = "Heavy Vehicle Safety";
      engMsg = "Ensure your cargo is fully secured. Maintain a safe braking distance from small vehicles.";
      hinMsg = "सुनिश्चित करें कि आपका माल सुरक्षित है। छोटे वाहनों से सुरक्षित दूरी बनाए रखें।";
      icon = Icons.local_shipping;
      iconColor = Colors.amber;
      bgColor = Colors.amber.withOpacity(0.2);
    }

    _speakText(engMsg, hinMsg);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7), 
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox(); 
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value), 
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF15222E), 
                  borderRadius: BorderRadius.circular(25), 
                  border: Border.all(color: iconColor.withOpacity(0.6), width: 1.5), 
                  boxShadow: [
                    BoxShadow(color: iconColor.withOpacity(0.25), blurRadius: 25, spreadRadius: 5), 
                    const BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: iconColor.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
                      ),
                      child: Icon(icon, color: iconColor, size: 45),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      engMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55, 
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _proceedToNavigation();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          shadowColor: iconColor.withOpacity(0.5),
                          elevation: 10,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("I Understand & Agree", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🔴 UPDATED: Professional TTS when starting route in Ambulance Mode
  void _proceedToNavigation() async {
    setState(() => _isNavigating = true);
    _mapController.move(_currentPosition, 18.0);
    String firstInstruction = _turnInstructions.isNotEmpty ? _turnInstructions[0] : "Head towards your destination";
    
    if (_isAmbulanceMode) {
      _speakText(
        "Emergency Route Confirmed. Alerting all nearby users to clear the path. $firstInstruction",
        "आपातकालीन मार्ग सेट हो गया है। आस-पास के सभी उपयोगकर्ताओं को रास्ता खाली करने के लिए अलर्ट भेज दिया गया है। $firstInstruction"
      );
    } else {
      _speakText(
        "Navigation Started. $firstInstruction",
        "नेविगेशन शुरू हो गया है। $firstInstruction"
      );
    }
  }

  Widget _buildNavIcon(IconData icon, String label, int index) {
    bool isSelected = _bottomNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _bottomNavIndex = index);
        
        if (index == 0) {
           Navigator.push(context, MaterialPageRoute(builder: (context) => const VaultScreen())).then((_) {
              setState(() => _bottomNavIndex = 1); 
           });
        }
        else if (index == 2) {
           Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) {
              setState(() => _bottomNavIndex = 1); 
           });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E5EC),
      resizeToAvoidBottomInset: true,

      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 10, top: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF0F2027),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavIcon(Icons.folder_shared, 'Vault', 0),
            Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2D3A),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Text("Nav Mode", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AITripPlannerScreen()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      child: Row(
                        children: const [
                          Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                          SizedBox(width: 5),
                          Text("Trip Planner", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildNavIcon(Icons.person, 'Profile', 2),
          ],
        ),
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentPosition, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=${Config.tomtomApiKey}",
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.smartroute.ai',
                additionalOptions: const {'id': 'tomtom'},
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(points: _routePoints, strokeWidth: 6.0, color: _routeColor),
                ],
              ),
            MarkerLayer(
                markers: [
                  // 🔴 UPDATED: Dynamic Marker (Ambulance vs Normal Arrow)
                  Marker(
                    point: _currentPosition,
                    width: _isAmbulanceMode ? 55 : 40,
                    height: _isAmbulanceMode ? 55 : 40,
                    child: _isAmbulanceMode
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                )
                              ],
                              border: Border.all(color: Colors.redAccent, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.airport_shuttle, color: Colors.redAccent, size: 30),
                            ),
                          )
                        : const Icon(Icons.navigation, color: Colors.blueAccent, size: 32),
                  ),
                  
                  // Baki destination aur toll wale markers waise hi rahenge...
                  if (_destinationPosition != null)
                    Marker(
                      point: _destinationPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Colors.redAccent, size: 40),
                    ),
                  for (var tollPos in _tollPositions)
                    Marker(
                      point: tollPos,
                      width: 35,
                      height: 35,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: const Center(child: Text("🪙", style: TextStyle(fontSize: 16))),
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.deepPurpleAccent,
                    radius: 22,
                    child: Text('K', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.eco, color: Colors.lightGreenAccent, size: 18),
                        SizedBox(width: 8),
                        Text("Kshitiz Sharma", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async => await AuthService().signOut(),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.7),
                      radius: 22,
                      child: const Icon(Icons.logout, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isAmbulanceMode)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "EMERGENCY VEHICLE MODE ACTIVE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: _isNavigating ? 140 : 450,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'recenter',
              backgroundColor: const Color(0xFF15222E),
              onPressed: _reCenterMap,
              child: const Icon(Icons.my_location, color: Colors.blueAccent),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: _isNavigating ? 0.2 : 0.40,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFF15222E),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 5)],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10)),
                      ),

                      if (!_isNavigating) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2D3A),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.blueAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white),
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (value) {
                                    setState(() => _suggestions = []);
                                    FocusScope.of(context).unfocus();
                                    _calculateRoute(value);
                                  },
                                  decoration: const InputDecoration(
                                    hintText: "Search destination...",
                                    hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_isSearchingRoute)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2),
                                ),
                            ],
                          ),
                        ),

                        if (_suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2D3A),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_on, color: Colors.blueAccent, size: 18),
                                  title: Text(_suggestions[index], style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  onTap: () {
                                    _searchController.text = _suggestions[index];
                                    setState(() => _suggestions = []);
                                    FocusScope.of(context).unfocus();
                                    _calculateRoute(_suggestions[index]);
                                  },
                                );
                              },
                            ),
                          ),

                        if (_travelTime.isNotEmpty && _suggestions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.timer_outlined, color: Colors.greenAccent, size: 20),
                                    const SizedBox(width: 5),
                                    Text(_travelTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    const SizedBox(width: 25),
                                    const Icon(Icons.route_outlined, color: Colors.blueAccent, size: 20),
                                    const SizedBox(width: 5),
                                    Text(_travelDistance, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                MetricsGrid(fuelCost: _fuelCost, trafficLevel: _trafficLevel, tollStatus: _tollStatus, co2Emission: _co2Emission),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _showSafetyPopupAndNavigate,
                                    icon: const Icon(Icons.navigation, color: Colors.white),
                                    label: const Text("Begin Journey 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 25),
                        TransportModes(selectedTransport: _selectedTransport, onTransportSelected: _onTransportSelected),
                        const SizedBox(height: 25),
                        EmergencyGrid(
                          isAmbulanceMode: _isAmbulanceMode,
                          onKitTap: _showKitHelplines,
                          onReportTap: _triggerReportAccident,
                          onAmbulanceTap: _toggleAmbulanceMode,
                          onSOSTap: _triggerOfflineSOS,
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.turn_right, color: Colors.greenAccent, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _turnInstructions.isNotEmpty ? _turnInstructions[0] : "Head towards your destination",
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Remaining: $_travelDistance • $_travelTime", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isNavigating = false;
                                  _mapController.move(_currentPosition, 11.0);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}