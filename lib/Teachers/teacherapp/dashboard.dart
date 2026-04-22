
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attendance.dart';
import 'lab_map.dart';
import 'report_form.dart';
import 'schedule.dart';
import 'login/screens/login_screen.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("teacher_token");

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: _TeacherDrawer(onLogout: () => _signOut(context)),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              color: _nuDarkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.menu, color: _nuGold, size: 26),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
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
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'TEACHER VIEW',
                              style: TextStyle(
                                color: _nuWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              'NATIONAL UNIVERSITY CLARK · FACULTY',
                              style: TextStyle(
                                color: _nuGold.withOpacity(0.85),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Container(height: 3, color: _nuGold),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeBanner(),
                    const SizedBox(height: 24),
                    _ActionsGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome Banner ────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatefulWidget {
  @override
  State<_WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<_WelcomeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003087), Color(0xFF001A52)],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: const Border(left: BorderSide(color: _nuGold, width: 5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Faculty Dashboard',
                style: TextStyle(
                  color: _nuWhite,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'NATIONAL UNIVERSITY CLARK · ITSO SYSTEM',
                style: TextStyle(
                  color: _nuGold.withOpacity(0.8),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _nuGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _nuGold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: _nuGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions Grid ──────────────────────────────────────────────────────────────
class _ActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            label: 'Schedule',
            subtitle: 'View your class timetable',
            icon: Icons.calendar_month_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SchedulePage()),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionCard(
            label: 'Lab Map',
            subtitle: 'Browse available lab rooms',
            icon: Icons.map_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LabMapPage()),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionCard(
            label: 'Attendance',
            subtitle: 'Track student attendance',
            icon: Icons.people_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendancePage()),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String label, subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? _nuGold : Colors.black.withOpacity(0.07),
              width: _hovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hovered ? 0.07 : 0.03),
                blurRadius: _hovered ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _hovered ? _nuDarkBlue : const Color(0xFFE8EEF8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: _hovered ? _nuGold : _nuDarkBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: _hovered ? _nuDarkBlue : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Teacher Drawer ────────────────────────────────────────────────────────────
class _TeacherDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  const _TeacherDrawer({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 295,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF003087), Color(0xFF001A52)],
              ),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _nuGold, width: 2.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/Images/NUSchoolLogo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'National University',
                  style: TextStyle(
                    color: _nuWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Clark',
                  style: TextStyle(
                    color: _nuGold.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _nuGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _nuGold.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Faculty',
                    style: TextStyle(
                      color: _nuGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 3, color: _nuGold),
          const SizedBox(height: 10),
          _DrawerItem(
            icon: Icons.calendar_month_outlined,
            label: 'Schedule',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchedulePage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.map_outlined,
            label: 'Lab Map',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LabMapPage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.people_outline,
            label: 'Attendance',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendancePage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.report_problem_outlined,
            label: 'Report to ITSO',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherReportFormPage(),
                ),
              );
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          _DrawerItem(
            icon: Icons.logout,
            label: 'Logout',
            isDestructive: true,
            onTap: onLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFE24B4A) : _nuDarkBlue;

    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFCEBEB)
              : const Color(0xFFE8EEF8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
