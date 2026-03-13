import 'package:flutter/material.dart';
// Import the dashboard screen to navigate after successful login
import 'dashboard.dart';

// --- FRONTEND DESIGN NOTE ---
// LoginScreen handles user authentication. 
// This screen uses a simple Column inside a centered Container to keep the form compact.
class LoginScreen extends StatelessWidget {
  // Controllers to retrieve text entered by the user
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  // Function to handle the login logic
  void login(BuildContext context) {
    // --- DESIGN: VERIFICATION DIALOG ---
    // This dialog simulates face recognition. Modify title and content styles here.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Face Verification"),
        content: const Text("Face recognized successfully"),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate to the Dashboard and remove the login screen from the stack
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => Dashboard()),
              );
            },
            child: const Text("Continue"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- DESIGN: SCREEN BACKGROUND ---
      // The body of the screen is centered.
      body: Center(
        child: Container(
          // --- DESIGN: FORM WIDTH ---
          // Restrict the width of the form for better appearance on larger screens.
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- DESIGN: SCREEN TITLE ---
              // Modify 'TextStyle' to change the font size, weight, or color.
              const Text(
                "Login",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              // --- DESIGN: EMAIL INPUT ---
              // Modify 'InputDecoration' to change labels, icons, or borders.
              TextField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                ),
              ),

              const SizedBox(height: 10),

              // --- DESIGN: PASSWORD INPUT ---
              TextField(
                controller: password,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),

              // --- DESIGN: SPACING ---
              const SizedBox(height: 30),

              // --- DESIGN: LOGIN BUTTON ---
              // This is the primary action button. Style it using ElevatedButton.styleFrom.
              SizedBox(
                width: double.infinity, // Makes the button full-width of the container
                child: ElevatedButton(
                  onPressed: () => login(context),
                  child: const Text("Login"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
