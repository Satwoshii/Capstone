import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

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
    if (score == 3 || score == 4) return "Medium password";
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
    if (score == 3 || score == 4) return Colors.orange;
    return Colors.green;
  }

  bool _isPasswordStrongEnough(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value);
  }

  Future<void> registerUser() async {
    if (email.text.isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in all fields")),
        );
      }
      return;
    }

    if (password.text != confirmPassword.text) {
      setState(() {
        confirmPasswordError = "Passwords do not match";
      });
      return;
    }

    if (!_isPasswordStrongEnough(password.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Password must be at least 8 characters and include uppercase, lowercase, and number",
            ),
          ),
        );
      }
      return;
    }

    try {
      await auth.register(email.text, password.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration Successful")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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

  InputDecoration _inputDecoration({
    required String label,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFF2C300),
          width: 2,
        ),
      ),
    );
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
                Image.asset(
                  "assets/Images/NUSchoolLogo.png",
                  width: 80,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Register",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: email,
                  decoration: _inputDecoration(label: "Email"),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: password,
                  obscureText: !showPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: _inputDecoration(
                    label: "Password",
                    suffixIcon: InkWell(
                      onTap: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          showPassword
                              ? "assets/Icons/eye.png"
                              : "assets/Icons/hidden.png",
                          width: 24,
                          height: 24,
                        ),
                      ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                TextField(
                  controller: confirmPassword,
                  obscureText: !showConfirmPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: _inputDecoration(
                    label: "Confirm Password",
                    errorText: confirmPasswordError,
                    suffixIcon: InkWell(
                      onTap: () {
                        setState(() {
                          showConfirmPassword = !showConfirmPassword;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          showConfirmPassword
                              ? "assets/Icons/eye.png"
                              : "assets/Icons/hidden.png",
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
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
                    onPressed: registerUser,
                    child: const Text(
                      "Register",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Already have an account? Log In"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}