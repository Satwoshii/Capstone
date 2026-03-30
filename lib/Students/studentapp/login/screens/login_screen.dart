import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import 'package:test1/Students/studentapp/dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  final auth = AuthService();

  bool showPassword = false;

  // 🔥 LOGIN FUNCTION (from your 2nd code)
  Future<void> loginUser() async {
    final Map<String, dynamic>? user =
    await auth.login(email.text, password.text);

    if (user != null) {
      final String token = JWTService.generateToken(user);

      final SharedPreferences prefs =
      await SharedPreferences.getInstance();
      await prefs.setString("token", token);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Dashboard()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Credentials")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(

        // 🔥 BACKGROUND IMAGE
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/Images/NUBackdroptest.png"),
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
                  "assets/Images/NUSchoolLogotest.png",
                  width: 80,
                ),

                const SizedBox(height: 10),

                const Text(
                  "Log In",
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
                    hintText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),

                const SizedBox(height: 12),

                // PASSWORD
                TextField(
                  controller: password,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),

                const SizedBox(height: 10),

                // SHOW PASSWORD
                Row(
                  children: [
                    Checkbox(
                      value: showPassword,
                      onChanged: (value) {
                        setState(() {
                          showPassword = value!;
                        });
                      },
                    ),
                    const Text(
                      "Show Password",
                      style: TextStyle(fontSize: 12),
                    )
                  ],
                ),

                const SizedBox(height: 10),

                // LOGIN BUTTON
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2C300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: loginUser, // 🔥 CONNECTED TO AUTH
                    child: const Text(
                      "Log In",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // REGISTER BUTTON
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text("Create Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}