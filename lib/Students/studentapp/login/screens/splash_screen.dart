import 'dart:async'; // Import Timer and other asynchronous utilities
import 'package:flutter/material.dart'; // Import Flutter UI components
import 'package:shared_preferences/shared_preferences.dart'; // Import for persistent local storage access
import '../services/jwt_service.dart'; // Import the JWT service for token validation
import 'login_screen.dart'; // Import the login screen for redirection
import 'package:test1/Students/studentapp/dashboard.dart';
import 'dart:async'; // Import for asynchronous operations



// Define a StatefulWidget for the Splash Screen (initial loading screen)
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState(); // Initialize state
}

// State management class for SplashScreen
class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    // Start the login status check as soon as the splash screen is initialized
    checkLoginStatus();
  }

  // Asynchronous function to determine if a user is already logged in
  checkLoginStatus() async {
    // Open the local shared preferences storage
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Retrieve the stored JWT token, if it exists
    String? token = prefs.getString("token");

    // Introduce a 2-second delay to show the splash branding
    Timer(const Duration(seconds: 2), () {
      if (token != null) {
        // If a token exists, verify its validity and expiration
        var payload = JWTService.verifyToken(token);
        if (payload != null) {
          // If the token is valid, skip login and go straight to the Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => Dashboard()),
          );
          return; // Exit the function
        }
      }
      
      // If no token exists or if it's invalid/expired, redirect to the Login Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build the visual layout of the splash screen
    return const Scaffold(
      body: Center(
        // Display a welcome message in the center of the screen
        child: Text(
          "Welcome to NU Clark System",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
