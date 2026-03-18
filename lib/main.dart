import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// ITSO
import 'ITSO/landingITso.dart';

// Mobile
import 'Students/studentapp/mainapp.dart';

// Web
import 'Students/studentvw_pages/login/main2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase here so it's available for the whole app
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCR9Te0R8AsLlbmoeHNpMt-V50avM2EHe4",
      appId: "1:340469481850:web:449bdbdf2c9f49f82216c3",
      messagingSenderId: "340469481850",
      projectId: "test-1fc5d",
      storageBucket: "test-1fc5d.firebasestorage.app",
    ),
  );

  runApp(Main());
}

class Main extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Capstone Front Door",

      initialRoute: Uri.base.path == '/' ? '/' : Uri.base.path,

      onGenerateRoute: (settings) {
        // Automatically redirect mobile vs web routes
        switch (settings.name) {
        // ===== DEFAULT =====
          case '/':
            return MaterialPageRoute(
              builder: (_) => Webstudent(),
            );

        // ===== MOBILE =====
          case '/studentapp':
            return MaterialPageRoute(
              builder: (_) => Appstudent(),
            );

        // ===== WEB =====
          case '/itsoadmin':
            return MaterialPageRoute(
              builder: (_) => LandingITSO(),
            );

        // ===== FALLBACK =====
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(
                  child: Text(
                    'Page not found: ${settings.name}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}
