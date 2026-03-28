import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

class Webstudent extends StatelessWidget {
  const Webstudent({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Capstone Front Door",
      home: SplashScreen(),
    );
  }
}