import 'package:flutter/material.dart';
import 'app_state.dart';
import 'services/auth_repository.dart';
import 'services/rooms_repository_web.dart';

import 'pages/login.dart';
import 'pages/pcManagement.dart';
import 'pages/reportLog.dart';
import 'pages/qr_management.dart';
import 'pages/teacher_home.dart';
import 'pages/student_home.dart';

import 'widgets/itso_drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState(
    auth: MockAuthRepository(),
    roomsRepo: WebLocalRoomsRepository(),
  );

  await appState.bootstrap();

  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  final AppState appState;

  const MyApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: appState,
      child: MaterialApp(
        title: 'ITSO View',
        debugShowCheckedModeBanner: false,

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),

        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {

    final app = AppStateScope.of(context);
    final user = app.user;

    if (user == null) {
      return const LoginPage();
    }

    if (user.isItso) {
      return const LandingITSO();
    }

    if (user.isTeacher) {
      return const TeacherHomePage();
    }

    if (user.isStudent) {
      return const StudentHomePage();
    }

    return const LoginPage();
  }
}

class LandingITSO extends StatelessWidget {
  const LandingITSO({super.key});

  @override
  Widget build(BuildContext context) {

    final key = GlobalKey<ScaffoldState>();
    final color = Theme.of(context).colorScheme;
    final app = AppStateScope.of(context);

    return Scaffold(
      key: key,
      drawer: const ItsoDrawer(),

      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => key.currentState?.openDrawer(),
        ),

        backgroundColor: color.primary,
        title: const Text("ITSO View", style: TextStyle(color: Colors.white)),

        actions: [

          TextButton(
            onPressed: () async {

              await app.signOut();

              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
            child: const Text(
              "Sign out",
              style: TextStyle(color: Colors.white),
            ),
          )

        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            _FeatureCard(
              title: "Report Log",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportLogPage(),
                  ),
                );
              },
            ),

            _FeatureCard(
              title: "QR Management",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QrManagementPage(),
                  ),
                );
              },
            ),

            _FeatureCard(
              title: "PC Management",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PcManagementPage(),
                  ),
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {

  final String title;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap,

      child: Container(
        width: 260,
        height: 120,
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade200),
          borderRadius: BorderRadius.circular(10),
        ),

        child: Row(
          children: [

            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.computer),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

          ],
        ),
      ),
    );
  }
}