import 'package:flutter/material.dart';



// ITSO

import 'ITSO/landingITso.dart';

// Mobile
import 'Students/studentapp/mainapp.dart';


// Web
import 'Students/studentvw_pages/login/main2.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Default page
      initialRoute: '/itso',

      // ===== ROUTES =====
      routes: {
        // LOGIN / HOME
        '/': (context) => LandingITSO(),

        // ===== ITSO =====
        '/itso': (context) => LandingITSO(),

        // ===== MOBILE APP =====
        '/studentapp': (context) => Appstudent(),


        // ===== WEB (FIREBASE HOSTING) =====
        '/webstudents': (context) => Webstudent(),

      },
    );
  }
}