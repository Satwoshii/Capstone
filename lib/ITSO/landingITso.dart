import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'services/auth_repository.dart';
import 'services/rooms_repository_web.dart';
import 'services/auth_service.dart';

import 'pages/login/screens/splash_screen.dart';
import 'pages/login/screens/login_screen.dart';
import 'pages/pcManagement.dart';
import 'pages/reportLog.dart';
import 'pages/qr_management.dart';
import 'widgets/itso_drawer.dart';

void main() async {
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
        debugShowCheckedModeBanner: false,
        title: 'Capstone System',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class LandingITSO extends StatelessWidget {
  const LandingITSO({super.key});

  Map<String, bool> _normalizePeripherals(dynamic raw) {
    final defaults = <String, bool>{
      'Keyboard': true,
      'Mouse': true,
      'Monitor': true,
      'Cables': true,
      'System Unit': true,
    };

    if (raw is! Map) return defaults;

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    final mapped = <String, bool>{};
    raw.forEach((key, value) {
      final k = key.toString().toLowerCase().trim();
      if (k == 'keyboard') mapped['Keyboard'] = parseBool(value);
      if (k == 'mouse') mapped['Mouse'] = parseBool(value);
      if (k == 'monitor') mapped['Monitor'] = parseBool(value);
      if (k == 'cables' || k == 'cable') mapped['Cables'] = parseBool(value);
      if (k == 'system_unit' || k == 'system unit') {
        mapped['System Unit'] = parseBool(value);
      }
    });

    return {...defaults, ...mapped};
  }

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<ScaffoldState>();
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      key: key,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => key.currentState?.openDrawer(),
        ),
        backgroundColor: color.primary,
        title: const Text(
          'ITSO View',
          style: TextStyle(color: Colors.white),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: ColoredBox(color: Colors.amber),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService().logout();

              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final problemDocs = snapshot.data!.docs.where((doc) {
                  final peripherals = _normalizePeripherals(doc.data()['peripherals']);
                  return peripherals.values.any((value) => value == false);
                }).toList();

                if (problemDocs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No active PC problems right now.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.red),
                          const SizedBox(width: 10),
                          Text(
                            'PC Problem Notifications (${problemDocs.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...problemDocs.map((doc) {
                        final data = doc.data();
                        final lab = (data['lab'] ?? 'Unknown Room').toString();
                        final pc = (data['pc'] ?? 'Unknown PC').toString();
                        final issues = _normalizePeripherals(data['peripherals'])
                            .entries
                            .where((entry) => entry.value == false)
                            .map((entry) => entry.key)
                            .join(', ');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• Problem detected on $pc in room $lab${issues.isEmpty ? '' : ' — $issues'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _FeatureCard(
                  title: 'Report Log',
                  icon: Icons.table_chart_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportLogPage()),
                    );
                  },
                ),
                _FeatureCard(
                  title: 'QR Management',
                  icon: Icons.qr_code_2,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QrManagementPage()),
                    );
                  },
                ),
                _FeatureCard(
                  title: 'PC Management',
                  icon: Icons.computer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PcManagementPage()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.icon,
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
              child: Icon(icon),
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