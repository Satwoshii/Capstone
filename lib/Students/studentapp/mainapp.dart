import 'package:flutter/material.dart';

import 'login/screens/splash_screen.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Capstone Front Door",
      home: SplashScreen(),
    );
  }
}