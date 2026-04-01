import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class TeacherRegisterScreen extends StatefulWidget {
  const TeacherRegisterScreen({super.key});

  @override
  State<TeacherRegisterScreen> createState() => _TeacherRegisterScreenState();
}

class _TeacherRegisterScreenState extends State<TeacherRegisterScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  final auth = TeacherAuthService();

  bool showPassword = false;
  bool showConfirmPassword = false;

  String? confirmPasswordError;

  Future<void> registerUser() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 🔥 SAME BACKGROUND AS LOGIN
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/Images/NUBackdrop.png"),
            fit: BoxFit.cover,
          ),
        ),

        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 25,
                  offset: Offset(0, 10),
                )
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO
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

                // EMAIL
                TextField(
                  controller: email,
                  decoration: InputDecoration(
                    labelText: "Email",
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
                  ),
                ),

                const SizedBox(height: 12),

                // 🔥 CREATE PASSWORD (WITH PNG TOGGLE)
                TextField(
                  controller: password,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: "Create Password",
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

                const SizedBox(height: 12),

                // 🔥 CONFIRM PASSWORD (WITH PNG TOGGLE)
                TextField(
                  controller: confirmPassword,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    errorText: confirmPasswordError,
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
                    suffixIcon: InkWell(
                      onTap: () {
                        setState(() {
                          showConfirmPassword =
                          !showConfirmPassword;
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

                // REGISTER BUTTON
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

                // BACK TO LOGIN
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