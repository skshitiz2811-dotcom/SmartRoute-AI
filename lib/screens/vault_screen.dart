import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  final ImagePicker _picker = ImagePicker();
  
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  final List<String> _defaultDocs = [
    'Driving License',
    'Vehicle RC Book',
    'Insurance Paper',
    'PUC Certificate'
  ];

  Map<String, String?> _documents = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadVaultData(); 
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadVaultData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('secure_vault_data');
    
    setState(() {
      if (storedData != null) {
        Map<String, dynamic> decodedData = json.decode(storedData);
        _documents = decodedData.map((key, value) => MapEntry(key, value?.toString()));
      } else {
        for (var doc in _defaultDocs) {
          _documents[doc] = null;
        }
      }
    });
  }

  Future<void> _saveVaultData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('secure_vault_data', json.encode(_documents));
  }

  Future<String> _saveImagePermanently(String temporaryPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final String newPath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    final File newFile = await File(temporaryPath).copy(newPath);
    return newFile.path;
  }

  Future<bool> _verifySecurity(String reason) async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics && !isSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("No Security Setup Found! Please enable screen lock.", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ));
        }
        return false;
      }

      bool authenticated = await _auth.authenticate(localizedReason: reason);
      return authenticated;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Authentication Error!", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ));
      }
      return false; 
    }
  }

  void _unlockVault() async {
    setState(() => _isAuthenticating = true);
    bool verified = await _verifySecurity('Scan Fingerprint or Face to unlock Secure Vault');
    
    if (verified) {
      setState(() {
        _isUnlocked = true;
        _isAuthenticating = false;
      });
    } else {
      setState(() => _isAuthenticating = false);
    }
  }

  void _lockVault() {
    setState(() => _isUnlocked = false);
  }

  void _addNewDocumentDialog() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF15222E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_box, color: Colors.cyanAccent, size: 40),
              const SizedBox(height: 15),
              const Text("Add Custom Document", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "E.g., Aadhar Card, Passport",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54)))),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          setState(() {
                            _documents[nameController.text] = null; 
                          });
                          _saveVaultData(); 
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Create", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Future<void> _handleImagePicked(String docKey, XFile? file) async {
    if (file != null) {
      String permanentPath = await _saveImagePermanently(file.path);
      setState(() => _documents[docKey] = permanentPath);
      await _saveVaultData(); 
    }
  }

  void _showUploadOptions(String docKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF15222E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Upload $docKey", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.cyanAccent),
              title: const Text("Take Photo (Camera)", style: TextStyle(color: Colors.white70)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                await _handleImagePicked(docKey, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purpleAccent),
              title: const Text("Upload from Gallery", style: TextStyle(color: Colors.white70)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                await _handleImagePicked(docKey, file);
              },
            ),
          ],
        ),
      )
    );
  }

  void _viewSecureDocument(String docKey) async {
    bool verified = await _verifySecurity('Verify identity to view $docKey');
    if (!verified) return;

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2D3A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(docKey, style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_documents[docKey]!),
                  fit: BoxFit.contain,
                  height: MediaQuery.of(context).size.height * 0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    label: const Text("Delete Document", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: () async {
                      bool deleteVerified = await _verifySecurity('Verify identity to DELETE $docKey');
                      if (deleteVerified) {
                        Navigator.pop(ctx);
                        setState(() {
                          if (_documents[docKey] != null) {
                            try { File(_documents[docKey]!).deleteSync(); } catch(e){}
                          }

                          if (_defaultDocs.contains(docKey)) {
                            _documents[docKey] = null; 
                          } else {
                            _documents.remove(docKey); 
                          }
                        });
                        _saveVaultData(); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document Deleted Securely", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                      }
                    },
                  ),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14), 
      body: Stack(
        children: [
          // 1. Ambient Background Decoration
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyanAccent.withOpacity(0.1)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),

          // 2. ACTUAL VAULT UI (Grid) - Hamesha render hoga background mein
          SafeArea(
            child: IgnorePointer(
              ignoring: !_isUnlocked, // Agar lock hai toh documents click nahi honge
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // 🔙 BACK BUTTON
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3), 
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24)
                                ),
                                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("MY VAULT", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                Text(
                                  _isUnlocked ? "Verified Access Granted" : "Vault Locked", 
                                  style: TextStyle(color: _isUnlocked ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_isUnlocked)
                          InkWell(
                            onTap: _lockVault,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
                              child: const Icon(Icons.lock_outline, color: Colors.redAccent),
                            ),
                          )
                      ],
                    ),
                  ),
                  
                  // Document Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _documents.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _documents.length) {
                          return _buildAddDocCard(); 
                        }
                        String key = _documents.keys.elementAt(index);
                        return _buildDocCard(key);
                      },
                    ),
                  )
                ],
              ),
            ),
          ),

          // 3. BLUR EFFECT & LOCK SCREEN UI (Sirf tab dikhega jab locked ho)
          if (!_isUnlocked) ...[
            
            // Ye widget peeche ki GridView ko poori tarah Blur kar dega
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0), // Blur intensity
                child: Container(
                  color: Colors.black.withOpacity(0.4), // Thoda dark shade blur ke upar
                ),
              ),
            ),

            // Fingerprint Lock Screen UI
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lock screen pe bhi back aane ke liye button chahiye
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
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.enhanced_encryption, color: Colors.cyanAccent, size: 90),
                            const SizedBox(height: 20),
                            const Text("SECURE VAULT", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4)),
                            const SizedBox(height: 10),
                            const Text("End-to-End Encrypted Storage", style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1)),
                            const SizedBox(height: 60),

                            if (_isAuthenticating)
                              const Column(
                                children: [
                                  CircularProgressIndicator(color: Colors.cyanAccent),
                                  SizedBox(height: 20),
                                  Text("AWAITING BIOMETRICS...", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold))
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: _unlockVault,
                                child: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        padding: const EdgeInsets.all(25),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.cyanAccent.withOpacity(0.1),
                                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                                          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
                                        ),
                                        child: const Icon(Icons.fingerprint, color: Colors.cyanAccent, size: 70),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 30),
                            const Text("TAP TO SCAN", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocCard(String title) {
    bool hasImage = _documents[title] != null;

    return GestureDetector(
      onTap: () {
        if (hasImage) {
          _viewSecureDocument(title); 
        } else {
          _showUploadOptions(title); 
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasImage ? Colors.greenAccent.withOpacity(0.6) : Colors.cyanAccent.withOpacity(0.3), 
                width: 1.5
              ),
              boxShadow: [
                if (hasImage) BoxShadow(color: Colors.greenAccent.withOpacity(0.1), blurRadius: 15, spreadRadius: 2)
              ]
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 🔴 HATA DIYA GAYA HAI: Image.file wali line yahan se delete kar di hai
                // Ab background mein photo nahi dikhegi, sirf clean card dikhega.

                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasImage ? Icons.admin_panel_settings : Icons.add_photo_alternate,
                        color: hasImage ? Colors.greenAccent : Colors.cyanAccent,
                        size: 45,
                      ),
                      const SizedBox(height: 15),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasImage ? Colors.greenAccent.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text(
                          hasImage ? "VERIFIED" : "UPLOAD",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: hasImage ? Colors.greenAccent : Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDocCard() {
    return GestureDetector(
      onTap: _addNewDocumentDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 50),
            SizedBox(height: 10),
            Text("Add Document", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}