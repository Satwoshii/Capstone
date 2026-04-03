import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  final auth = AuthService();

  bool showPassword = false;
  bool showConfirmPassword = false;

  String? confirmPasswordError;

  Future<void> registerUser() async {
    if (fullName.text.isEmpty ||
        email.text.isEmpty ||
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

    try {
      await auth.register(
        fullName.text,
        email.text,
        password.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(blurRadius: 10, color: Colors.black26)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Register",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ✅ FULL NAME
              TextField(
                controller: fullName,
                decoration: _input("Full Name"),
              ),
              const SizedBox(height: 12),

              // EMAIL
              TextField(
                controller: email,
                decoration: _input("Email"),
              ),
              const SizedBox(height: 12),

              // PASSWORD
              TextField(
                controller: password,
                obscureText: !showPassword,
                decoration: _input("Password").copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(showPassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        showPassword = !showPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // CONFIRM PASSWORD
              TextField(
                controller: confirmPassword,
                obscureText: !showConfirmPassword,
                decoration: _input("Confirm Password").copyWith(
                  errorText: confirmPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        showConfirmPassword = !showConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: registerUser,
                child: const Text("Register"),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Already have an account? Log in"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}