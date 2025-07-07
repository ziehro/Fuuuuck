// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // For showing SnackBar messages (optional)

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser; // Get current authenticated user

  Stream<User?> get authStateChanges => _auth.authStateChanges(); // Stream to listen for auth state changes

  // --- Sign In Method ---
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners(); // Notify listeners (e.g., UI) about change in auth state
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
      } else {
        errorMessage = e.message ?? 'An unknown error occurred during sign-in.';
      }
      debugPrint('Sign-in error: $errorMessage (Code: ${e.code})'); // For debugging
      rethrow; // Re-throw the exception so UI can catch and display specific error
    } catch (e) {
      debugPrint('Unexpected sign-in error: $e');
      rethrow;
    }
  }

  // --- Sign Up Method ---
  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Optional: Store additional user data in Firestore immediately after sign-up
      // await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
      //   'email': email,
      //   'createdAt': FieldValue.serverTimestamp(),
      // });
      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      } else {
        errorMessage = e.message ?? 'An unknown error occurred during sign-up.';
      }
      debugPrint('Sign-up error: $errorMessage (Code: ${e.code})');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected sign-up error: $e');
      rethrow;
    }
  }

  // --- Sign Out Method ---
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}