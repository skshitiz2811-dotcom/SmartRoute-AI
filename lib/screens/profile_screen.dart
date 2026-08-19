import 'dart:ui';
import 'dart:convert'; // Added for JSON encoding/decoding
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:share_plus/share_plus.dart'; 
import '../services/auth_service.dart'; 
import 'login_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isHindiSelected = false;
  String _selectedVoice = "Energetic (Default)";
  bool _isFetchingLocation = false; 
  
  String _familyNo1 = "";
  String _familyNo2 = "";

  List<Map<String, dynamic>> _recentHistory = [];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadRealPreferences(); 
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadRealPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('search_history');

    setState(() {
      _isHindiSelected = prefs.getBool('use_hindi') ?? false;
      _selectedVoice = prefs.getString('ai_voice') ?? "Energetic (Default)";
      _familyNo1 = prefs.getString('family_no_1') ?? "Not Set";
      _familyNo2 = prefs.getString('family_no_2') ?? "Not Set";

      if (historyJson != null) {
        List<dynamic> decoded = json.decode(historyJson);
        _recentHistory = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  Future<void> _saveLanguagePreference(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_hindi', value);
    setState(() => _isHindiSelected = value);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value ? "हिंदी भाषा सक्रिय हो गई है (Language set to Hindi)" : "Language set to English", style: const TextStyle(fontWeight: FontWeight.bold)), 
      backgroundColor: Colors.cyanAccent.shade700,
    ));
  }

  Future<void> _saveVoicePreference(String voice) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_voice', voice);
    setState(() => _selectedVoice = voice);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Voice successfully changed to $voice", style: const TextStyle(fontWeight: FontWeight.bold)), 
      backgroundColor: Colors.purpleAccent,
    ));
  }

  // 🔴 EDIT EMERGENCY CONTACTS LOGIC
  void _editEmergencyContacts() {
    TextEditingController phone1Controller = TextEditingController(text: _familyNo1 == "Not Set" ? "" : _familyNo1);
    TextEditingController phone2Controller = TextEditingController(text: _familyNo2 == "Not Set" ? "" : _familyNo2);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF15222E),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emergency, color: Colors.redAccent, size: 40),
              const SizedBox(height: 15),
              const Text("Update SOS Contacts", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("These numbers will receive your live location during an emergency.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 20),
              
              TextField(
                controller: phone1Controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Primary Contact *",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.phone, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: phone2Controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Secondary Contact",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.phone, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54)))),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        String n1 = phone1Controller.text.trim();
                        String n2 = phone2Controller.text.trim();
                        
                        await prefs.setString('family_no_1', n1);
                        await prefs.setString('family_no_2', n2);
                        
                        setState(() {
                          _familyNo1 = n1.isEmpty ? "Not Set" : n1;
                          _familyNo2 = n2.isEmpty ? "Not Set" : n2;
                        });
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS Contacts Updated!"), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              )
            ],
          ),
        )
      )
    );
  }

  Future<void> _shareLiveLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isFetchingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission denied!"), backgroundColor: Colors.redAccent));
          return;
        }
      }

      double lat = 22.7196; 
      double lng = 75.8577; 

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 3) 
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (e) {
        print("Using Fallback Location due to timeout/emulator issue");
      }

      String mapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      String message = "🚨 My Live Route Alert: I am currently here. You can track my location using this link: \n$mapsUrl";

      setState(() => _isFetchingLocation = false);
      await Share.share(message);

    } catch (e) {
      setState(() => _isFetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to open share options!"), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14), 
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 30, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF15222E), Colors.cyanAccent.withOpacity(0.05)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.cyanAccent, width: 2),
                          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 15)],
                        ),
                        child: const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.deepPurpleAccent,
                          child: Text("K", style: TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Kshitiz Sharma", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 5),
                            const Text("kshitiz.sharma@gmail.com", style: TextStyle(color: Colors.white60, fontSize: 13)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTag("TechForge Leader", Colors.cyanAccent),
                                _buildTag("CSE Student @ Acropolis", Colors.purpleAccent),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(_pulseController.value * 0.3), blurRadius: 20, spreadRadius: 2)],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isFetchingLocation ? null : _shareLiveLocation,
                          icon: _isFetchingLocation 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                              : const Icon(Icons.share_location, color: Colors.black87),
                          label: Text(_isFetchingLocation ? "Fetching GPS..." : "Share Live Location", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            disabledBackgroundColor: Colors.greenAccent.withOpacity(0.5),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DRIVING STATS", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15222E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.eco, "Carbon Saved", "12.4 kg", Colors.greenAccent),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _buildStatItem(Icons.local_gas_station, "Fuel Saved", "8.5 L", Colors.orangeAccent),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _buildStatItem(Icons.savings, "Money Saved", "₹450", Colors.amberAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🔴 NEW SECTION: EMERGENCY CONTACTS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("EMERGENCY CONTACTS", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      InkWell(
                        onTap: _editEmergencyContacts,
                        child: const Text("EDIT", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF15222E), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.contact_phone, color: Colors.redAccent),
                          title: const Text("Primary Contact", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          subtitle: Text(_familyNo1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        ListTile(
                          leading: const Icon(Icons.contact_phone_outlined, color: Colors.orangeAccent),
                          title: const Text("Secondary Contact", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          subtitle: Text(_familyNo2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text("PREFERENCES", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF15222E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeColor: Colors.cyanAccent,
                          secondary: const Icon(Icons.language, color: Colors.cyanAccent),
                          title: const Text("Hindi Interface & Voice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text("Switch app language to Hindi", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          value: _isHindiSelected,
                          onChanged: _saveLanguagePreference, 
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        ListTile(
                          leading: const Icon(Icons.record_voice_over, color: Colors.purpleAccent),
                          title: const Text("AI Voice Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("Current: $_selectedVoice", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                          onTap: _showVoiceSelector,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🔴 UPDATED SECTION: DYNAMIC RECENT SEARCHES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("RECENT SEARCHES", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      if (_recentHistory.isNotEmpty)
                        InkWell(
                          onTap: () async {
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            await prefs.remove('search_history');
                            setState(() => _recentHistory.clear());
                          },
                          child: const Text("CLEAR", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  _recentHistory.isEmpty 
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                        child: const Text("No recent searches found.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentHistory.length,
                        itemBuilder: (context, index) {
                          final item = _recentHistory[index];
                          IconData icon = Icons.history;
                          Color iconColor = Colors.white;
                          
                          if (item["icon"] == "auto_awesome") { icon = Icons.auto_awesome; iconColor = Colors.amber; }
                          else if (item["icon"] == "navigation") { icon = Icons.navigation; iconColor = Colors.cyanAccent; }
                          else if (item["icon"] == "warning") { icon = Icons.warning_amber; iconColor = Colors.redAccent; }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                                child: Icon(icon, color: iconColor, size: 20),
                              ),
                              title: Text(item["dest"] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text("${item['mode']} • ${item['date']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ),
                          );
                        },
                      ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService().signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()), 
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text("Secure Sign Out", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  const Center(
                    child: Text("SmartRoute AI v1.0\nDeveloped by Team TechForge", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 12)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  void _showVoiceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15222E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("Select AI Voice", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildVoiceOption("Energetic (Default)", Icons.electric_bolt, Colors.amber),
              _buildVoiceOption("Calm & Professional", Icons.spa, Colors.cyanAccent),
              _buildVoiceOption("Jarvis (Sci-Fi)", Icons.memory, Colors.purpleAccent),
            ],
          ),
        );
      }
    );
  }

  Widget _buildVoiceOption(String name, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      trailing: _selectedVoice == name ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
      onTap: () => _saveVoicePreference(name), 
    );
  }
}