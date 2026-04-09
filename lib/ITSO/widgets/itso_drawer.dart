import 'package:flutter/material.dart';
import '../app_state.dart';
import '../pages/login/screens/login_screen.dart';
import '../pages/reportLog.dart';
import '../pages/qr_management.dart';
import '../pages/pcManagement.dart';
import '../pages/ai_analytic.dart';
import '../landingITso.dart';

const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);

class ItsoDrawer extends StatelessWidget {
  const ItsoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final name = app.user?.name ?? '—';
    final email = app.user?.email ?? '—';

    void go(Widget page, {bool replaceAll = false}) {
      Navigator.of(context).pop();

      Future.microtask(() {
        if (!context.mounted) return;
        final route = MaterialPageRoute(builder: (_) => page);
        if (replaceAll) {
          Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
        } else {
          Navigator.of(context).push(route);
        }
      });
    }

    return Drawer(
      width: 300,
      backgroundColor: _nuDarkBlue,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ITSO VIEW',
                        style: TextStyle(
                          color: _nuWhite,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'NU CLARK',
                        style: TextStyle(
                          color: _nuGold.withOpacity(0.8),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      onTap: () => go(const LandingITSO(), replaceAll: true),
                    ),
                    _MenuTile(
                      icon: Icons.table_chart_outlined,
                      label: 'Report Log',
                      onTap: () => go(const ReportLogPage()),
                    ),
                    _MenuTile(
                      icon: Icons.qr_code_2,
                      label: 'QR Management',
                      onTap: () => go(const QrManagementPage()),
                    ),
                    _MenuTile(
                      icon: Icons.computer,
                      label: 'PC Management',
                      onTap: () => go(const PcManagementPage()),
                    ),
                    _MenuTile(
                      icon: Icons.auto_graph,
                      label: 'AI Analytics',
                      onTap: () => go(const AiAnalyticsPage()),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await app.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white70),
                    ),
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

class _MenuTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? _nuGold : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: _hovered ? _nuGold : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}