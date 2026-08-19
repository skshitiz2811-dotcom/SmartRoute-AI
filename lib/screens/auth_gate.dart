import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        // Ye stream Firebase se lagatar check karti hai ki user ka status kya hai
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          
          // Agar Firebase check kar raha hai, toh loading dikhao
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          // Agar snapshot mein user ka data hai (matlab logged in hai), toh Dashboard dikhao
          if (snapshot.hasData) {
            return const DashboardScreen();
          }

          // Agar data nahi hai (logged out hai), toh Login Screen dikhao
          return const LoginScreen();
        },
      ),
    );
  }
}