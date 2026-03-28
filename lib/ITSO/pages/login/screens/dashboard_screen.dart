import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {

  logout(BuildContext context) async {

    SharedPreferences prefs =
    await SharedPreferences.getInstance();

    await prefs.remove("token");

    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),

        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => logout(context),
          )
        ],
      ),

      body: Center(
        child: Text(
          "Welcome to the System!",
          style: TextStyle(fontSize: 26),
        ),
      ),
    );
  }
}