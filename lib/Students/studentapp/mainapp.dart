import 'package:flutter/material.dart';
// Import local screens for navigation
import 'login.dart';
import 'dashboard.dart';

// The main entry point of the Flutter application
void main() {
  runApp(Appstudent());
}

// MyApp is the root widget of the application
class Appstudent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Peripheral Monitoring',
      // Disable the 'Debug' banner in the top right corner
      debugShowCheckedModeBanner: false,
      // Define the global theme for the application
      theme: ThemeData(primarySwatch: Colors.blue),
      // Set the initial screen to the LoginScreen
      home: LoginScreen(),
    );
  }
}
