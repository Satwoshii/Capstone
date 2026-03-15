import 'package:flutter/material.dart';
import '../app_state.dart';

class TeacherHomePage extends StatelessWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Teachers Program (TODO)')),
      body: Center(child: Text('Welcome, ${app.user?.name ?? ''} (Teacher)')),
    );
  }
}
