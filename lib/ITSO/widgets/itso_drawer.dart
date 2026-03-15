import 'package:flutter/material.dart';
import '../app_state.dart';
import '../pages/login.dart';
import '../pages/reportLog.dart';
import '../pages/qr_management.dart'; // <- ensure this filename & casing
import '../pages/pcManagement.dart';
import '../landingITso.dart';

class ItsoDrawer extends StatelessWidget {
  const ItsoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final darkBlue = Color.lerp(color.primary, Colors.black, 0.25)!;
    final app = AppStateScope.of(context);
    final name = app.user?.name ?? '—';
    final email = app.user?.email ?? '—';

    /// Close the Drawer once, then defer the route push to the next microtask.
    /// This avoids mutating routes in the same pointer frame (fixes mouse_tracker assertion).
    void go(Widget page, {bool replaceAll = false}) {
      // 1) Close the Drawer route
      Navigator.of(context).pop();

      // 2) Defer navigation to the next microtask
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
      backgroundColor: darkBlue,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.school, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'National University\nClark',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dynamic user block
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
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
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                ],
              ),
            ),

            const Spacer(),

            // Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await app.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                            (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings, color: Colors.white70),
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

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}