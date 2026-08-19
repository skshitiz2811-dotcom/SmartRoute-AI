import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/tomtom_service.dart';
import '../config.dart';

class AITripPlannerScreen extends StatefulWidget {
  const AITripPlannerScreen({super.key});

  @override
  State<AITripPlannerScreen> createState() => _AITripPlannerScreenState();
}

class _AITripPlannerScreenState extends State<AITripPlannerScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final TomTomService _tomTomService = TomTomService();

  LatLng _currentPosition = const LatLng(22.7196, 75.8577); 
  LatLng? _destinationPosition;
  List<LatLng> _routePoints = [];

  List<LatLng> _petrolStops = [];
  List<LatLng> _foodStops = [];
  List<LatLng> _hotelStops = [];
  List<LatLng> _tollStops = [];
  
  List<String> _suggestions = [];
  Timer? _debounce;

  bool _isInitializing = true;
  bool _isAnalyzing = false;
  bool _showOverview = false;
  bool _isTripActive = false;

  String _destinationName = "";
  String _travelTime = "";
  String _travelDistance = "";
  int _tollCount = 0;
  double _rawDistance = 0.0;
  
  String _breakTimeStr = "";
  String _lunchTimeStr = "";
  String _stayTimeStr = "";
  String _arrivalTimeStr = "";
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _portalController; 
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _determinePosition();

    // Box Glow Animation
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 2.0, end: 12.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    // Radar Scanning Animation
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    // 🌀 NEW: PREMIUM PORTAL ENTRY ANIMATION
    _portalController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));

    Future.delayed(const Duration(milliseconds: 500), () {
      _flutterTts.speak("System Online. Opening AI Trip Portal.");
      _portalController.forward().then((_) {
        if (mounted) {
          setState(() => _isInitializing = false);
          _flutterTts.speak("Welcome to your intelligent planner. Where are we heading?");
        }
      });
    });
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("en-US"); 
    await _flutterTts.setPitch(1.2); 
    await _flutterTts.setSpeechRate(0.5); 
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
        _mapController.move(_currentPosition, 13.0);
      }
    }
  }

  void _reCenterMap() {
    _mapController.move(_currentPosition, _isTripActive ? 18.0 : 13.0);
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

  LatLng _getPointAtProgress(double progress) {
    if (_routePoints.isEmpty) return _currentPosition;
    int index = (_routePoints.length * progress).floor();
    if (index >= _routePoints.length) index = _routePoints.length - 1;
    if (index < 0) index = 0;
    return _routePoints[index];
  }

  void _calculateCheckpointTimes(int totalMins) {
    DateTime now = DateTime.now();
    _breakTimeStr = "Expected at ${now.add(Duration(minutes: (totalMins * 0.25).round())).formatTime()}";
    _lunchTimeStr = "Phase 2: Expected at ${now.add(Duration(minutes: (totalMins * 0.5).round())).formatTime()}";
    _stayTimeStr = "Phase 3: Evening rest at ${now.add(Duration(minutes: (totalMins * 0.75).round())).formatTime()}";
    _arrivalTimeStr = "Safe arrival around ${now.add(Duration(minutes: totalMins)).formatTime()}";
  }

  void _analyzeTrip(String destination) async {
    if (destination.isEmpty) return;
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isAnalyzing = true;
      _suggestions = []; 
      _destinationName = destination;
      _destinationController.text = destination;
      _petrolStops.clear();
      _foodStops.clear();
      _hotelStops.clear();
      _tollStops.clear();
    });
    
    _flutterTts.speak("Analyzing route, traffic, and checkpoints for $destination.");

    LatLng? dest = await _tomTomService.getCoordinates(destination, _currentPosition);
    if (dest != null) {
      var routeData = await _tomTomService.getRoute(_currentPosition, dest, 'Car');
      if (routeData.isNotEmpty) {
        _destinationPosition = dest;
        _routePoints = routeData['points'];
        _travelDistance = "${routeData['distance']} km";
        int totalMins = routeData['time'] ?? 60;
        _travelTime = "$totalMins mins";
        _rawDistance = routeData['rawDistanceKm'] ?? 0.0;
        _tollCount = (_rawDistance / 55).floor();

        _calculateCheckpointTimes(totalMins);

        if (_rawDistance > 50) {
          _tollStops.add(_getPointAtProgress(0.2));
          _tollStops.add(_getPointAtProgress(0.7));
          _petrolStops.add(_getPointAtProgress(0.3));
        }
        if (_rawDistance > 100) {
          _foodStops.add(_getPointAtProgress(0.45)); 
          _petrolStops.add(_getPointAtProgress(0.8));
        }
        if (_rawDistance > 300) {
          _hotelStops.add(_getPointAtProgress(0.6)); 
        }
      }
    }

    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isAnalyzing = false;
      _showOverview = true;
    });
    
    if (dest != null) {
      double midLat = (_currentPosition.latitude + dest.latitude) / 2;
      double midLng = (_currentPosition.longitude + dest.longitude) / 2;
      LatLng midPoint = LatLng(midLat, midLng);

      double zoomLevel = 11.0;
      if (_rawDistance > 800) zoomLevel = 5.0;
      else if (_rawDistance > 400) zoomLevel = 6.0;
      else if (_rawDistance > 150) zoomLevel = 7.5;
      else if (_rawDistance > 50) zoomLevel = 9.0;

      _mapController.move(midPoint, zoomLevel);
    }

    _flutterTts.speak("Route generated successfully. Ready for departure.");
  }

  void _startJourney() {
    setState(() {
      _showOverview = false;
      _isTripActive = true;
    });
    _mapController.move(_currentPosition, 16.0);
    _flutterTts.speak("Journey active. AI is monitoring your path. Drive safely.");
  }

  void _editDestination() {
    setState(() {
      _showOverview = false;
      _isTripActive = false;
      _routePoints.clear();
      _petrolStops.clear();
      _foodStops.clear();
      _hotelStops.clear();
      _tollStops.clear();
      _destinationPosition = null;
      _destinationController.clear();
    });
    _mapController.move(_currentPosition, 13.0);
    _flutterTts.speak("Please enter your new destination.");
  }

  @override
  void dispose() {
    _glowController.dispose();
    _portalController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14), // Deep dark premium bg
      body: Stack(
        children: [
          // 1. MAIN MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentPosition, initialZoom: 13.0),
            children: [
              TileLayer(urlTemplate: "https://{s}.api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=${Config.tomtomApiKey}", subdomains: const ['a', 'b', 'c', 'd']),
              PolylineLayer(polylines: [
                if (_routePoints.isNotEmpty) 
                  Polyline(points: _routePoints, strokeWidth: 5.0, color: Colors.cyanAccent.withOpacity(0.8)) // Sleeker line
              ]),
              MarkerLayer(
                markers: [
                  Marker(point: _currentPosition, width: 40, height: 40, child: const Icon(Icons.navigation, color: Colors.cyanAccent, size: 35)),
                  if (_destinationPosition != null) Marker(point: _destinationPosition!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40)),
                  for (var stop in _tollStops) Marker(point: stop, width: 30, height: 30, child: _buildMapIcon(Icons.toll, Colors.grey)),
                  for (var stop in _petrolStops) Marker(point: stop, width: 30, height: 30, child: _buildMapIcon(Icons.local_gas_station, Colors.orangeAccent)),
                  for (var stop in _foodStops) Marker(point: stop, width: 30, height: 30, child: _buildMapIcon(Icons.restaurant, Colors.yellowAccent)),
                  for (var stop in _hotelStops) Marker(point: stop, width: 30, height: 30, child: _buildMapIcon(Icons.hotel, Colors.purpleAccent)),
                ],
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🎯 RE-CENTER BUTTON (Visible when Trip is Active)
          if (_isTripActive || _showOverview)
            Positioned(
              bottom: _isTripActive ? 40 : 380,
              right: 20,
              child: FloatingActionButton(
                onPressed: _reCenterMap,
                backgroundColor: const Color(0xFF15222E),
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.cyanAccent, width: 1.5)
                ),
                child: const Icon(Icons.my_location, color: Colors.cyanAccent),
              ),
            ),

          // 💎 PREMIUM GLASSMORPHISM SEARCH BAR
          if (!_isInitializing && !_isAnalyzing && !_showOverview && !_isTripActive)
            Positioned(
              top: 100, left: 20, right: 20,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: _glowAnimation.value, spreadRadius: 1)],
                            ),
                            child: TextField(
                              controller: _destinationController,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(
                                hintText: "Enter Destination...",
                                hintStyle: TextStyle(color: Colors.white54),
                                prefixIcon: Icon(Icons.blur_on, color: Colors.cyanAccent),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              ),
                              onSubmitted: _analyzeTrip,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15222E).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.cyanAccent, size: 18),
                            title: Text(_suggestions[index], style: const TextStyle(color: Colors.white)),
                            onTap: () => _analyzeTrip(_suggestions[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // 🤖 PREMIUM RADAR SCANNING EFFECT
          if (_isAnalyzing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RotationTransition(
                          turns: _radarController,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [Colors.transparent, Colors.cyanAccent.withOpacity(0.8)],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text("ANALYZING ROUTE & PROTOCOLS...", style: TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 📊 SLEEK TIMELINE BOTTOM SHEET
          if (_showOverview)
            DraggableScrollableSheet(
              initialChildSize: 0.45, 
              minChildSize: 0.20,    
              maxChildSize: 0.85,    
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(25, 10, 25, 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2634), Color(0xFF0F1722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.2), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 60, height: 5,
                            margin: const EdgeInsets.only(bottom: 25),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(_destinationName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                            InkWell(
                              onTap: _editDestination,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.15), shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _topStatTile(Icons.route_outlined, _travelDistance, Colors.cyanAccent),
                              _topStatTile(Icons.access_time, _travelTime, Colors.greenAccent),
                              _topStatTile(Icons.toll, "$_tollCount Tolls", Colors.amberAccent),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text("TRIP TIMELINE", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 20),

                        _buildTimelineStep(Icons.my_location, Colors.greenAccent, "Departure Point", "Weather: Optimal, Systems checked", isFirst: true),
                        _buildTimelineStep(Icons.local_gas_station, Colors.orangeAccent, "Fuel & Refresh", _breakTimeStr.isNotEmpty ? _breakTimeStr : "Phase 1"),
                        if (_rawDistance > 100)
                          _buildTimelineStep(Icons.restaurant, Colors.amber, "Food / Break", _lunchTimeStr.isNotEmpty ? _lunchTimeStr : "Phase 2"),
                        _buildTimelineStep(Icons.toll, Colors.blueGrey, "Toll Checkpoints", "Prepare approx ₹${_tollCount * 120}"),
                        if (_rawDistance > 300)
                          _buildTimelineStep(Icons.hotel, Colors.purpleAccent, "Overnight Stay", _stayTimeStr.isNotEmpty ? _stayTimeStr : "Phase 3"),
                        _buildTimelineStep(Icons.flag, Colors.cyanAccent, "Destination", _arrivalTimeStr.isNotEmpty ? _arrivalTimeStr : "Arrival guaranteed", isLast: true),

                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity, height: 60,
                          child: ElevatedButton(
                            onPressed: _startJourney,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent.withOpacity(0.9),
                              shadowColor: Colors.cyanAccent.withOpacity(0.5),
                              elevation: 15,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch, color: Colors.black87),
                                SizedBox(width: 10),
                                Text("INITIATE JOURNEY", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),

          // 🌀 ULTIMATE ELECTRIC GLOWING PORTAL ENTRY (Reference image style)
          if (_isInitializing)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _portalController,
                builder: (context, child) {
                  double progress = _portalController.value;
                  
                  // Custom Sequence: Pop in -> Spin -> Massive Zoom In
                  double scale = 0.0;
                  if (progress < 0.2) {
                    scale = progress * 5; // Pop from 0 to 1
                  } else if (progress < 0.7) {
                    scale = 1.0 + math.sin((progress - 0.2) * math.pi * 2) * 0.1; // Gentle pulse
                  } else {
                    scale = 1.0 + ((progress - 0.7) * 50); // Massive zoom inside the hole
                  }

                  return Container(
                    color: Colors.black.withOpacity((1.0 - progress).clamp(0.0, 1.0)),
                    child: Center(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scale(scale)
                          ..rotateZ(progress * math.pi * 8), // Fast spin
                        child: Opacity(
                          opacity: progress > 0.9 ? (1.0 - (progress - 0.9) * 10).clamp(0.0, 1.0) : 1.0, // Fade out at the very end
                          child: Container(
                            width: 200, height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // The "Magic Circle" glowing layers
                              boxShadow: const [
                                BoxShadow(color: Colors.white, blurRadius: 20, spreadRadius: 2),
                                BoxShadow(color: Colors.cyanAccent, blurRadius: 50, spreadRadius: 15),
                                BoxShadow(color: Colors.blueAccent, blurRadius: 100, spreadRadius: 30),
                              ],
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white, 
                                  Colors.cyanAccent.withOpacity(0.8), 
                                  Colors.transparent
                                ],
                                stops: const [0.2, 0.6, 1.0],
                              )
                            ),
                            // Black hole core inside the glowing ring
                            child: Center(
                              child: Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white, // Blinding white core
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.8), blurRadius: 20)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _topStatTile(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildTimelineStep(IconData icon, Color color, String title, String subtitle, {bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15), 
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5))
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.white12, margin: const EdgeInsets.symmetric(vertical: 5))),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28.0, top: 5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMapIcon(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15222E),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
      ),
      child: Center(child: Icon(icon, color: color, size: 16)),
    );
  }
}

extension TimeFormatting on DateTime {
  String formatTime() {
    int h = hour;
    String m = minute.toString().padLeft(2, '0');
    String period = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    h = h == 0 ? 12 : h;
    return "$h:$m $period";
  }
}