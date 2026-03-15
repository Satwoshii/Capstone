import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import '../../dashboardweb.dart';

class LoginScreen extends StatefulWidget {

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final email = TextEditingController();
  final password = TextEditingController();

  final auth = AuthService();

  loginUser() async {

    bool success =
    await auth.login(email.text, password.text);

    if (success) {

      String token =
      JWTService.generateToken(email.text);

      SharedPreferences prefs =
      await SharedPreferences.getInstance();

      await prefs.setString("token", token);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => DashboardPage()),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invalid Credentials")));
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("Login")),

      body: Padding(
        padding: EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller: email,
              decoration: InputDecoration(labelText: "Email"),
            ),

            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: loginUser,
              child: Text("Login"),
            ),

            TextButton(
              onPressed: () {

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RegisterScreen()));
              },
              child: Text("Create Account"),
            )
          ],
        ),
      ),
    );
  }
}
