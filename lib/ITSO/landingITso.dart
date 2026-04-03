import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'services/auth_repository.dart';
import 'services/rooms_repository_web.dart';

import 'pages/login/screens/splash_screen.dart';
import 'pages/pcManagement.dart';
import 'pages/reportLog.dart';
import 'pages/qr_management.dart';
import 'widgets/itso_drawer.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

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
        title: 'NU Clark ITSO System',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003087)),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

// ── LandingITSO ───────────────────────────────────────────────────────────────
class LandingITSO extends StatelessWidget {
  const LandingITSO({super.key});

  Map<String, bool> _normalizePeripherals(dynamic raw) {
    final defaults = <String, bool>{
      'keyboard': true, 'mouse': true, 'monitor': true,
      'cables': true, 'system_unit': true,
    };
    if (raw is! Map) return defaults;
    bool parseBool(dynamic v) {
      if (v is bool)   return v;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }
    final mapped = <String, bool>{};
    raw.forEach((k, v) => mapped[k.toString().toLowerCase().trim()] = parseBool(v));
    return {...defaults, ...mapped};
  }

  int _problemCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int count = 0;
    for (final doc in docs) {
      final p = _normalizePeripherals(doc.data()['peripherals']);
      if (p.values.any((e) => e == false)) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: const ItsoDrawer(),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 68,
        leading: IconButton(
          icon: ImageIcon(
            const AssetImage('assets/Icons/ic_menu.png'),
            color: _nuGold,
            size: 32,
          ),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _nuGold, width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/Images/NUSchoolLogo.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ITSO VIEW',
                  style: TextStyle(
                    color: _nuWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  'NATIONAL UNIVERSITY CLARK',
                  style: TextStyle(
                    color: _nuGold.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _WelcomeBar(),
            const SizedBox(height: 24),

            // ── Stat Cards ────────────────────────────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
              builder: (context, pcSnap) {
                final pcDocs     = pcSnap.data?.docs ?? [];
                final totalPcs   = pcDocs.length;
                final problemPcs = _problemCount(pcDocs);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('reports').snapshots(),
                  builder: (context, repSnap) {
                    final repDocs         = repSnap.data?.docs ?? [];
                    final pendingReports  = repDocs.where((d) => (d.data()['status'] ?? '') == 'pending').length;
                    final resolvedReports = repDocs.where((d) => (d.data()['status'] ?? '') == 'resolved').length;
                    return _StatsGrid(
                      totalPcs: totalPcs,
                      problemPcs: problemPcs,
                      pendingReports: pendingReports,
                      resolvedReports: resolvedReports,
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Problem Notifications (full width) ────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                final problemDocs = docs.where((doc) {
                  final p = _normalizePeripherals(doc.data()['peripherals']);
                  return p.values.any((v) => v == false);
                }).toList();
                return _ProblemPanel(problemDocs: problemDocs);
              },
            ),

            const SizedBox(height: 24),

            // ── Feature Cards ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _FeatureCard(
                  title: 'Report Log',
                  subtitle: 'View and manage incident reports',
                  iconPath: 'assets/Icons/ic_report.png',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReportLogPage())),
                )),
                const SizedBox(width: 20),
                Expanded(child: _FeatureCard(
                  title: 'QR Management',
                  subtitle: 'Generate and track QR codes',
                  iconPath: 'assets/Icons/ic_qr.png',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const QrManagementPage())),
                )),
                const SizedBox(width: 20),
                Expanded(child: _FeatureCard(
                  title: 'PC Management',
                  subtitle: 'Monitor lab computer inventory',
                  iconPath: 'assets/Icons/ic_pc.png',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PcManagementPage())),
                )),
              ],
            ),

            const SizedBox(height: 24),

            _AuditLogPanel(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Welcome Bar ───────────────────────────────────────────────────────────────
class _WelcomeBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IT Service Office Dashboard',
                style: TextStyle(color: _nuDarkBlue, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 5),
              Text(
                'REAL-TIME SYSTEM MONITORING',
                style: TextStyle(
                  color: Colors.black45, fontSize: 12,
                  fontWeight: FontWeight.w500, letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                _PulseDot(),
                const SizedBox(width: 8),
                const Text('Live Sync Active', style: TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 9, height: 9,
        decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final int totalPcs, problemPcs, pendingReports, resolvedReports;
  const _StatsGrid({
    required this.totalPcs, required this.problemPcs,
    required this.pendingReports, required this.resolvedReports,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Total PCs',
          value: '$totalPcs',
          iconPath: 'assets/Icons/ic_monitor.png',
          accentColor: _nuDarkBlue,
          iconBgColor: const Color(0xFFE8EEF8),
          valueColor: _nuDarkBlue,
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(
          label: 'PCs w/ Problems',
          value: '$problemPcs',
          iconPath: 'assets/Icons/ic_warning.png',
          accentColor: const Color(0xFFEF4444),
          iconBgColor: const Color(0xFFFEE2E2),
          valueColor: const Color(0xFFDC2626),
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(
          label: 'Pending Reports',
          value: '$pendingReports',
          iconPath: 'assets/Icons/ic_clock.png',
          accentColor: const Color(0xFFFFD700),
          iconBgColor: const Color(0xFFFEF9C3),
          valueColor: const Color(0xFFD97706),
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(
          label: 'Resolved Today',
          value: '$resolvedReports',
          iconPath: 'assets/Icons/ic_check.png',
          accentColor: const Color(0xFF22C55E),
          iconBgColor: const Color(0xFFDCFCE7),
          valueColor: const Color(0xFF16A34A),
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, iconPath;
  final Color accentColor, iconBgColor, valueColor;

  const _StatCard({
    required this.label, required this.value, required this.iconPath,
    required this.accentColor, required this.iconBgColor, required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: valueColor, height: 1.1),
              ),
            ],
          ),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
            child: Center(
              child: ImageIcon(AssetImage(iconPath), size: 32, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Problem Panel ─────────────────────────────────────────────────────────────
class _ProblemPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> problemDocs;
  const _ProblemPanel({required this.problemDocs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 20, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Text(
                  problemDocs.isEmpty ? 'No Active Problems' : 'Problem Notifications',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _nuDarkBlue),
                ),
                if (problemDocs.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${problemDocs.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (problemDocs.isEmpty)
            _AlertRow(text: 'All systems running normally.', severity: 'ok')
          else
            ...problemDocs.map((doc) {
              final data = doc.data();
              final lab  = (data['lab'] ?? 'Unknown').toString();
              final pc   = (data['pc']  ?? 'Unknown').toString();
              return _AlertRow(text: 'Problem detected on $pc in room $lab', severity: 'high');
            }),
        ],
      ),
    );
  }
}

// ── Alert Row ─────────────────────────────────────────────────────────────────
class _AlertRow extends StatelessWidget {
  final String text;
  final String severity;
  const _AlertRow({required this.text, required this.severity});

  Color get _dotColor {
    switch (severity) {
      case 'high':   return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      case 'low':    return const Color(0xFF60A5FA);
      default:       return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: severity == 'ok' ? const Color(0xFF166534) : const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature Card ──────────────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final String title, subtitle, iconPath;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title, required this.subtitle,
    required this.iconPath, required this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? _nuDarkBlue : Colors.black.withOpacity(0.07),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hovered ? 0.08 : 0.03),
                blurRadius: _hovered ? 16 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _hovered ? _nuDarkBlue : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ImageIcon(
                    AssetImage(widget.iconPath),
                    size: 32,
                    color: _hovered ? _nuGold : _nuDarkBlue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: _hovered ? _nuDarkBlue : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Audit Log Panel ───────────────────────────────────────────────────────────
class _AuditLogPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              'RECENT AUDIT LOG',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45, letterSpacing: 1.2),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('audit_logs')
                .orderBy('timestamp', descending: true)
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(padding: EdgeInsets.all(20), child: Text('Unable to load audit logs.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(padding: EdgeInsets.all(20), child: Text('No audit logs yet.'));
              }

              return Column(
                children: docs.map((doc) {
                  final data      = doc.data();
                  final action    = (data['action']    ?? '').toString();
                  final pc        = (data['pc']        ?? '').toString();
                  final lab       = (data['lab']       ?? '').toString();
                  final user      = (data['user']      ?? 'Unknown').toString();
                  final timestamp = data['timestamp'];
                  String timeStr  = '';
                  if (timestamp != null && timestamp is Timestamp) {
                    final dt = timestamp.toDate().toLocal();
                    final h  = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                    final m  = dt.minute.toString().padLeft(2, '0');
                    final p  = dt.hour >= 12 ? 'PM' : 'AM';
                    timeStr  = '$h:$m $p';
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.black38)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            action,
                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'PC: $pc  ·  Room: $lab',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                          ),
                        ),
                        const Text('by ', style: TextStyle(fontSize: 12, color: Colors.black38)),
                        Text(
                          user,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}