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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
      'keyboard': true,
      'mouse': true,
      'monitor': true,
      'cables': true,
      'system_unit': true,
    };

    if (raw is! Map) return defaults;

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    final mapped = <String, bool>{};
    raw.forEach((key, value) {
      mapped[key.toString().toLowerCase().trim()] = parseBool(value);
    });

    return {...defaults, ...mapped};
  }

  int _problemCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int count = 0;
    for (final doc in docs) {
      final peripherals = _normalizePeripherals(doc.data()['peripherals']);
      if (peripherals.values.any((e) => e == false)) {
        count++;
      }
    }
    return count;
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
          child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
              builder: (context, pcSnapshot) {
                final docs = pcSnapshot.data?.docs ?? [];
                final totalPcs = docs.length;
                final problemPcs = _problemCount(docs);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('reports').snapshots(),
                  builder: (context, reportSnapshot) {
                    final reportDocs = reportSnapshot.data?.docs ?? [];
                    final pendingReports = reportDocs
                        .where((d) => (d.data()['status'] ?? '') == 'pending')
                        .length;
                    final resolvedReports = reportDocs
                        .where((d) => (d.data()['status'] ?? '') == 'resolved')
                        .length;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _StatCard(
                          title: 'Total PCs',
                          value: '$totalPcs',
                          icon: Icons.desktop_windows,
                        ),
                        _StatCard(
                          title: 'Problem PCs',
                          value: '$problemPcs',
                          icon: Icons.warning_amber_rounded,
                        ),
                        _StatCard(
                          title: 'Pending Reports',
                          value: '$pendingReports',
                          icon: Icons.pending_actions,
                        ),
                        _StatCard(
                          title: 'Resolved Reports',
                          value: '$resolvedReports',
                          icon: Icons.task_alt,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final problemDocs = docs.where((doc) {
                  final peripherals = _normalizePeripherals(doc.data()['peripherals']);
                  return peripherals.values.any((v) => v == false);
                }).toList();

                if (problemDocs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 10),
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
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.red),
                          SizedBox(width: 10),
                          Text(
                            'PC Problem Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...problemDocs.map((doc) {
                        final data = doc.data();
                        final lab = (data['lab'] ?? 'Unknown').toString();
                        final pc = (data['pc'] ?? 'Unknown').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• Problem detected on $pc in room $lab',
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
              spacing: 20,
              runSpacing: 20,
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

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Audit Logs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('audit_logs')
                        .orderBy('timestamp', descending: true)
                        .limit(8)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Unable to load audit logs.');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Text('No audit logs yet.');
                      }

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final action = (data['action'] ?? '').toString();
                          final pc = (data['pc'] ?? '').toString();
                          final lab = (data['lab'] ?? '').toString();
                          final user = (data['user'] ?? 'Unknown').toString();

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history),
                            title: Text(action),
                            subtitle: Text('PC: $pc | Room: $lab | By: $user'),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          )
        ],
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
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}