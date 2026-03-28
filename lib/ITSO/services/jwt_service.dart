import 'package:flutter/material.dart';
import '../landingITso.dart';
import '../services/auth_service.dart';
import '../pages/login/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      final userData = await _auth.getCurrentUserData();

      if (!mounted) return;

      final role = (userData?['role'] ?? '').toString().toLowerCase();

      if (role == 'admin' || role == 'itso') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingITSO()),
        );
      } else {
        await _auth.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}