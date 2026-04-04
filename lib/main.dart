import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// Teacher
import 'Teachers/teacherapp/login/screens/login_screen.dart';
import 'Teachers/teacherapp/login/screens/splash_screen.dart';

// ITSO
import 'ITSO/landingITso.dart';
import 'ITSO/app_state.dart';
import 'ITSO/services/auth_repository.dart';
import 'ITSO/services/rooms_repository_web.dart';

// Mobile
import 'Students/studentapp/mainapp.dart';

// Web
import 'Students/studentvw_pages/login/main2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCR9Te0R8AsllbmoeHNpMt-V5OavM2EHe4",
      authDomain: "test-1fc5d.firebaseapp.com",
      projectId: "test-1fc5d",
      storageBucket: "test-1fc5d.firebasestorage.app",
      messagingSenderId: "340469481850",
      appId: "1:340469481850:web:449bdbdf2c9f49f82216c3",
    ),
  );

  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  AppState? _itsoState;
  bool _initialized = false;
  late String _url;

  @override
  void initState() {
    super.initState();
    _url = Uri.base.toString().toLowerCase();
    _initApp();
  }

  Future<void> _initApp() async {
    if (_url.contains('itsoadmin')) {
      _itsoState = AppState(
        auth: MockAuthRepository(),
        roomsRepo: WebLocalRoomsRepository(),
      );
      await _itsoState!.bootstrap();
    }

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_url.contains('studentapp')) {
      return const MainApp();
    } else if (_url.contains('teacherweb')) {
      return const TeacherApp();
    } else if (_url.contains('itsoadmin')) {
      return MyApp(appState: _itsoState!);
    } else {
      return const Webstudent();
    }
  }
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Teacher App',
      home: const SplashScreen(),
    );
  }
}