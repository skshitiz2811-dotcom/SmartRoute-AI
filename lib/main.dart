import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Yeh naya import add karna zaroori hai
import 'screens/splash_screen.dart'; // Apna premium splash screen yahan bulaya

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase initialization ko update kar diya gaya hai web support ke liye
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartRoute AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(), // Sabse pehle splash khulega
    );
  }
}