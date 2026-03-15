import 'package:flutter/material.dart';
import '../app_state.dart';

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Students Program (TODO)')),
      body: Center(child: Text('Welcome, ${app.user?.name ?? ''} (Student)')),
    );
  }
}