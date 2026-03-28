import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('No user returned');
      }

      print("LOGIN SUCCESS UID: ${user.uid}");

      return {
        'uid': user.uid,
        'email': user.email,
        'role': 'debug',
        'name': 'debug',
      };
    } on FirebaseAuthException catch (e) {
      print("AUTH ERROR CODE: ${e.code}");
      print("AUTH ERROR MESSAGE: ${e.message}");
      throw Exception("AUTH ERROR: ${e.code}");
    } catch (e) {
      print("UNKNOWN ERROR: $e");
      throw Exception("UNKNOWN ERROR: $e");
    }
  }
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      await _auth.signOut();
      return null;
    }

    final data = doc.data();
    if (data == null) {
      await _auth.signOut();
      return null;
    }

    final role = (data['role'] ?? '').toString().toLowerCase();

    if (role != 'admin' && role != 'itso') {
      await _auth.signOut();
      return null;
    }

    return {
      'uid': user.uid,
      'email': user.email,
      'role': role,
      'name': data['name'] ?? '',
    };
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Authentication.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Login failed.';
    }
  }
}