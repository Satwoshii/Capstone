import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// ITSO
import 'ITSO/landingITso.dart';

// Mobile
import 'Students/studentapp/mainapp.dart';

// Web
import 'Students/studentvw_pages/login/main2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable path-based URLs (removes the # from the URL)
  usePathUrlStrategy();

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

  runApp(const Main());
}

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine which app to load by checking the full URL string
    final String url = Uri.base.toString().toLowerCase();

    if (url.contains('studentapp')) {
      return MainApp();
    } else if (url.contains('itsoadmin')) {
      // Wrap in MaterialApp because LandingITSO is just a Scaffold
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "ITSO Admin",
        home: LandingITSO(),
      );
    } else {
      return Webstudent();
    }
  }
}
