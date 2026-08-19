import 'package:flutter/foundation.dart' show kIsWeb; // Web aur Mobile ko alag pehchanne ke liye
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Standard constructor (Yeh ab main tarike se Phone ke liye use hoga)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1093488601267-i5o8g8g4ec6qang7hmhuk0vmmahs1rns.apps.googleusercontent.com', 
  );

  // Google Sign-In Method
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // ✅ WEB KE LIYE LOGIC (Chrome/Edge par direct Firebase Popup chalega)
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      } 
      // ✅ ANDROID KE LIYE LOGIC (Jo pehle se sahi chal raha tha)
      else {
        // Step 1: User ko Google accounts ki list dikhao
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          return null; // User ne login cancel kar diya
        }

        // Step 2: Auth details nikalo
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Step 3: Firebase credential banao (accessToken aur idToken dono zaroori hain)
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Step 4: Firebase me login ho jao
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  // Sign Out Method
  Future<void> signOut() async {
    // Agar mobile hai, tabhi GoogleSignIn instance se sign out call karein
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    // Firebase se signout web aur mobile dono ke liye zaroori hai
    await _auth.signOut();
  }
}