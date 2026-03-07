import 'package:flutter/material.dart';
import 'dashboard.dart';

class LoginScreen extends StatelessWidget {

  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  void login(BuildContext context) {

    // simulate face verification
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Face Verification"),
        content: Text("Face recognized successfully"),
        actions: [
          TextButton(
            onPressed: () {
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
      body: Center(
        child: Container(
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Text("Login", style: TextStyle(fontSize: 28)),

              TextField(
                controller: email,
                decoration: InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: password,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
              ),

              SizedBox(height: 20),

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