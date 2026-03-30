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
  final confirmPassword = TextEditingController();

  // Instance of AuthService to handle registration logic
  final auth = AuthService();

  bool showPassword = false;
  bool showConfirmPassword = false;

  String? confirmPasswordError;
  String passwordStrengthText = "";
  Color passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();

    password.addListener(_validateInputs);
    confirmPassword.addListener(_validateInputs);
  }

  void _validateInputs() {
    final pass = password.text;
    final confirmPass = confirmPassword.text;

    setState(() {
      passwordStrengthText = _getPasswordStrengthText(pass);
      passwordStrengthColor = _getPasswordStrengthColor(pass);

      if (confirmPass.isEmpty) {
        confirmPasswordError = null;
      } else if (pass != confirmPass) {
        confirmPasswordError = "Passwords do not match";
      } else {
        confirmPasswordError = null;
      }
    });
  }

  String _getPasswordStrengthText(String value) {
    if (value.isEmpty) return "";

    int score = 0;

    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) score++;

    if (score <= 2) return "Weak password";
    if (score <= 4) return "Medium password";
    return "Strong password";
  }

  Color _getPasswordStrengthColor(String value) {
    if (value.isEmpty) return Colors.grey;

    int score = 0;

    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) score++;

    if (score <= 2) return Colors.red;
    if (score <= 4) return Colors.orange;
    return Colors.green;
  }

  bool _isPasswordStrongEnough(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value);
  }

  // Function to handle the user registration process
  Future<void> registerUser() async {
    // Basic validation: Check if fields are empty
    if (email.text.isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (password.text != confirmPassword.text) {
      setState(() {
        confirmPasswordError = "Passwords do not match";
      });
      return;
    }

    if (!_isPasswordStrongEnough(password.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password must be at least 8 characters and include uppercase, lowercase, and number",
          ),
        ),
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
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
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

            const SizedBox(height: 12),

            // TextField for entering the Password
            TextField(
              controller: password, // Connect to the password controller
              obscureText: !showPassword, // Hide/show password
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                ),
              ),
            ),

            if (passwordStrengthText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  passwordStrengthText,
                  style: TextStyle(
                    color: passwordStrengthColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // TextField for confirm password
            TextField(
              controller: confirmPassword,
              obscureText: !showConfirmPassword,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                errorText: confirmPasswordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showConfirmPassword = !showConfirmPassword;
                    });
                  },
                ),
              ),
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