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
  bool isSubmitting = false;
  String? confirmPasswordError;

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      suffixIcon: suffixIcon,
    );
  }

  Future<void> registerUser() async {
    final normalizedName = fullName.text.trim();
    final normalizedEmail = email.text.trim().toLowerCase();
    final normalizedPassword = password.text;
    final normalizedConfirm = confirmPassword.text;

    if (normalizedName.isEmpty ||
        normalizedEmail.isEmpty ||
        normalizedPassword.isEmpty ||
        normalizedConfirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (normalizedPassword != normalizedConfirm) {
      setState(() => confirmPasswordError = "Passwords do not match");
      return;
    }

    setState(() {
      confirmPasswordError = null;
      isSubmitting = true;
    });

    try {
      await auth.register(normalizedName, normalizedEmail, normalizedPassword);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/Images/NUBackdrop.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 25,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/Images/NUSchoolLogo.png", width: 80),
                const SizedBox(height: 10),
                const Text(
                  "Register",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: fullName,
                  decoration: _inputDecoration(hint: "Full Name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: _inputDecoration(hint: "Email"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: !showPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: _inputDecoration(
                    hint: "Password",
                    suffixIcon: InkWell(
                      onTap: () => setState(() => showPassword = !showPassword),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          showPassword ? "assets/Icons/eye.png" : "assets/Icons/hidden.png",
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassword,
                  obscureText: !showConfirmPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  onChanged: (_) {
                    if (confirmPasswordError != null) {
                      setState(() => confirmPasswordError = null);
                    }
                  },
                  decoration: _inputDecoration(
                    hint: "Confirm Password",
                    suffixIcon: InkWell(
                      onTap: () => setState(() => showConfirmPassword = !showConfirmPassword),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          showConfirmPassword ? "assets/Icons/eye.png" : "assets/Icons/hidden.png",
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ).copyWith(errorText: confirmPasswordError),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 140,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2C300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: isSubmitting ? null : registerUser,
                    child: Text(
                      isSubmitting ? "Saving..." : "Register",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}