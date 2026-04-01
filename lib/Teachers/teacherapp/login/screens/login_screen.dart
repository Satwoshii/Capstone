import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../../dashboard.dart';
import 'register_screen.dart';

class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final auth = TeacherAuthService();

  Future<void> loginUser() async {
    final user = await auth.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (user != null) {
      final token = JWTService.generateToken(user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("teacher_token", token);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TeacherDashboard(),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid teacher credentials"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Login"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: loginUser,
              child: const Text("Login"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherRegisterScreen(),
                  ),
                );
              },
              child: const Text("Register"),
            )
          ],
        ),
      ),
    );
  }
}