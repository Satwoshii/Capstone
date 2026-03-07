import 'package:flutter/material.dart';
// Import the dashboard screen to navigate after successful login
import 'dashboard.dart';

// LoginScreen provides the user interface for authentication
class LoginScreen extends StatelessWidget {

  // Controllers to retrieve text entered by the user
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  // Function to handle the login logic
  void login(BuildContext context) {
    // Show a dialog to simulate face verification
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Face Verification"),
        content: Text("Face recognized successfully"),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate to the Dashboard and remove the login screen from the stack
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => Dashboard()),
              );
            },
            child: Text("Continue"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body of the screen is centered
      body: Center(
        child: Container(
          // Restrict the width of the form for better appearance
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Screen Title
              Text("Login", style: TextStyle(fontSize: 28)),

              // Email input field
              TextField(
                controller: email,
                decoration: InputDecoration(labelText: "Email"),
              ),

              // Password input field with hidden text
              TextField(
                controller: password,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
              ),

              // Add vertical spacing before the button
              SizedBox(height: 20),

              // Login button triggers the face verification simulation
              ElevatedButton(
                onPressed: () => login(context),
                child: Text("Login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
