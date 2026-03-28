import 'package:flutter/material.dart'; // Import Flutter UI components
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences for local data persistence

import '../services/auth_service.dart'; // Import the authentication service logic
import '../services/jwt_service.dart'; // Import the JWT service for token generation
import '../../dashboardweb.dart'; // Import the dashboard page for navigation after login
import 'register_screen.dart'; // Import the registration screen for navigation

// Define a StatefulWidget for the login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState(); // Initialize state for the login screen
}

// State management class for LoginScreen
class _LoginScreenState extends State<LoginScreen> {
  // Controllers to capture user input from text fields
  final email = TextEditingController();
  final password = TextEditingController();
  
  // Instance of AuthService to handle login logic
  final auth = AuthService();

  // Asynchronous function to handle user login process
  Future<void> loginUser() async {
    // Call the login method from AuthService and explicitly define the expected user map return type
    final Map<String, dynamic>? user = await auth.login(email.text, password.text);

    if (user != null) {
      // If login is successful, generate a JWT containing the user's identity (UID, email, role)
      final String token = JWTService.generateToken(user);

      // Save the generated token to local storage using SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token);

      // Check if the widget is still mounted before navigating
      if (mounted) {
        // Navigate to the DashboardPage and remove the login screen from navigation history
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } else {
      // If login fails (user is null), show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Credentials")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the visual layout of the login screen
    return Scaffold(
      appBar: AppBar(title: const Text("Login")), // Header title
      body: Padding(
        padding: const EdgeInsets.all(20), // Internal padding for form layout
        child: Column(
          children: [
            // Text field for entering the email
            TextField(
              controller: email, // Connect to email controller
              decoration: const InputDecoration(labelText: "Email"), // Label for the field
            ),
            // Text field for entering the password
            TextField(
              controller: password, // Connect to password controller
              obscureText: true, // Obscure text for password security
              decoration: const InputDecoration(labelText: "Password"), // Label for the field
            ),
            const SizedBox(height: 20), // Vertical spacing
            // Button to trigger the login process
            ElevatedButton(
              onPressed: loginUser, // Execute loginUser function on press
              child: const Text("Login"), // Button label
            ),
            // Button to navigate to the registration screen
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text("Create Account"), // Label for the button
            )
          ],
        ),
      ),
    );
  }
}
