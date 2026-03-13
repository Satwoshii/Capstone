import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCR9Te0R8AsLlbmoeHNpMt-V50avM2EHe4",
      appId: "1:340469481850:web:449bdbdf2c9f49f82216c3",
      messagingSenderId: "340469481850",
      projectId: "test-1fc5d",
      storageBucket: "test-1fc5d.firebasestorage.app",
    ),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Capstone Front Door",
      home: SplashScreen(),
    );
  }
}