import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'enter_code.dart';
import 'login/screens/login_screen.dart';
import 'login/services/jwt_service.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  String userName = 'Student';
  String userEmail = 'Loading...';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();

    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    final savedFullName = prefs.getString("full_name");
    final savedName = prefs.getString("name");
    final savedUsername = prefs.getString("username");
    final savedStudentName = prefs.getString("student_name");
    final savedEmail = prefs.getString("email");

    String resolvedName = '';
    String resolvedEmail = '';

    if (token != null) {
      final payload = JWTService.verifyToken(token);

      if (payload != null) {
        resolvedName = (payload['full_name'] ??
            payload['name'] ??
            payload['username'] ??
            payload['student_name'] ??
            savedFullName ??
            savedName ??
            savedUsername ??
            savedStudentName ??
            '')
            .toString()
            .trim();

        resolvedEmail = (payload['email'] ?? savedEmail ?? '')
            .toString()
            .trim();
      }
    }

    if (resolvedName.isEmpty) {
      resolvedName = (savedFullName ??
          savedName ??
          savedUsername ??
          savedStudentName ??
          '')
          .trim();
    }

    if (resolvedEmail.isEmpty) {
      resolvedEmail = (savedEmail ?? '').trim();
    }

    // If name is still empty but email exists, fetch from Firestore users
    if (resolvedName.isEmpty && resolvedEmail.isNotEmpty) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: resolvedEmail)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();

          resolvedName = (data['full_name'] ??
              data['name'] ??
              data['username'] ??
              data['student_name'] ??
              '')
              .toString()
              .trim();

          final firestoreEmail =
          (data['email'] ?? resolvedEmail).toString().trim();

          if (resolvedName.isNotEmpty) {
            await prefs.setString('full_name', resolvedName);
          }

          if (firestoreEmail.isNotEmpty) {
            resolvedEmail = firestoreEmail;
            await prefs.setString('email', resolvedEmail);
          }
        }
      } catch (e) {
        debugPrint('Error loading user from Firestore: $e');
      }
    }

    if (resolvedName.isEmpty && resolvedEmail.isNotEmpty) {
      resolvedName = resolvedEmail.split('@').first;
    }

    if (!mounted) return;

    setState(() {
      userName = resolvedName.isEmpty ? 'Student' : resolvedName;
      userEmail = resolvedEmail.isEmpty ? 'No email' : resolvedEmail;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = userName.trim().isNotEmpty
        ? userName
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase()
        : 'ST';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: Drawer(
        backgroundColor: Colors.white,
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
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
                  Text(
                    userName,
                    style: const TextStyle(
                      color: _nuWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: _nuGold.withOpacity(0.8),
                      fontSize: 13,
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
                      border: Border.all(color: _nuGold.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Student',
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
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.qr_code_scanner,
              label: 'Enter QR Code',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EnterCodePage()),
                );
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Logout',
              isDestructive: true,
              onTap: _logout,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: _nuGold, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'NATIONAL UNIVERSITY',
                  style: TextStyle(
                    color: _nuWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'CLARK · STUDENT PORTAL',
                  style: TextStyle(
                    color: _nuGold.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
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
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF003087), Color(0xFF001A52)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        border: const Border(
                          left: BorderSide(color: _nuGold, width: 5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _nuGold.withOpacity(0.15),
                              border: Border.all(color: _nuGold, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: _nuGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: _nuGold.withOpacity(0.75),
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: _nuWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    color: _nuWhite.withOpacity(0.55),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUICK ACTIONS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black45,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ActionCard(
                                icon: Icons.qr_code_scanner,
                                title: 'Enter QR Code',
                                subtitle:
                                'Enter a unique code manually to submit a report',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EnterCodePage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOUR ACCOUNT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black45,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.07),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _InfoRow(
                                      icon: Icons.person_outline,
                                      label: 'Full Name',
                                      value: userName,
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    _InfoRow(
                                      icon: Icons.email_outlined,
                                      label: 'Email Address',
                                      value: userEmail,
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    _InfoRow(
                                      icon: Icons.school_outlined,
                                      label: 'Role',
                                      value: 'Student',
                                      valueColor: const Color(0xFF27500A),
                                      valueBg: const Color(0xFFEAF3DE),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _hovered ? _nuDarkBlue : const Color(0xFFE8EEF8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: _hovered ? _nuGold : _nuDarkBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: _hovered ? _nuDarkBlue : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? valueBg;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _nuDarkBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                valueBg != null
                    ? Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: valueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? _nuDarkBlue,
                    ),
                  ),
                )
                    : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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