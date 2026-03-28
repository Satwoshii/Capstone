import 'package:flutter/material.dart'; // Import Flutter's material design library
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core to initialize the connection

import 'screens/splash_screen.dart'; // Import the initial splash screen

// The main entry point for the Web Student application
void main() async {
  // Ensure that Flutter widget binding is initialized before calling asynchronous code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Firebase connection with the project's unique configuration
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCR9Te0R8AsLlbmoeHNpMt-V50avM2EHe4", // Firebase API Key
      appId: "1:340469481850:web:449bdbdf2c9f49f82216c3", // Unique Application ID
      messagingSenderId: "340469481850", // ID for Firebase Cloud Messaging
      projectId: "test-1fc5d", // Firebase Project ID
      storageBucket: "test-1fc5d.firebasestorage.app", // Cloud storage path
    ),
  );

  // Run the root widget of the application
  runApp(Webstudent());
}

// The root widget of the Web Student application
class Webstudent extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    // Return the MaterialApp wrapper which configures the overall theme and routing
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide the "Debug" banner in the corner
      title: "Capstone Front Door", // Title shown in the browser tab or task switcher
      home: SplashScreen(), // Set the splash screen as the starting page
    );
  }
}
