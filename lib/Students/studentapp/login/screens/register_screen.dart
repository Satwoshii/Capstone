import 'package:flutter/material.dart'; // Import Flutter material design package
import '../services/auth_service.dart'; // Import the authentication service

// Define a StatefulWidget for the Register Screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// Define the state for RegisterScreen
class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers to capture user input from the TextFields
  final email = TextEditingController();
  final password = TextEditingController();
  
  // Instance of AuthService to handle registration logic
  final auth = AuthService();

  // Function to handle the user registration process
  Future<void> registerUser() async {
    // Basic validation: Check if email or password fields are empty
    if (email.text.isEmpty || password.text.isEmpty) {
      // Show a snackbar if fields are missing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    try {
      // Call the register method from AuthService with provided credentials
      await auth.register(email.text, password.text);

      // Check if the widget is still in the tree before updating UI
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration Successful")),
        );
        // Navigate back to the previous screen (usually the Login screen)
        Navigator.pop(context);
      }
    } catch (e) {
      // If an error occurs during registration, catch it and show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the UI for the registration screen
    return Scaffold(
      appBar: AppBar(title: const Text("Register")), // Header title
      body: Padding(
        padding: const EdgeInsets.all(20), // Add padding around the content
        child: Column(
          children: [
            // TextField for entering the Email
            TextField(
              controller: email, // Connect to the email controller
              decoration: const InputDecoration(labelText: "Email"),
            ),
            // TextField for entering the Password
            TextField(
              controller: password, // Connect to the password controller
              obscureText: true, // Hide the text for security
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20), // Add vertical spacing
            // Button to trigger the registration process
            ElevatedButton(
              onPressed: registerUser, // Call the registerUser function on tap
              child: const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
