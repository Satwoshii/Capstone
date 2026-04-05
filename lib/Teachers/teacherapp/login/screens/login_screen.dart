import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../../dashboard.dart';
import 'register_screen.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen>
    with SingleTickerProviderStateMixin {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final auth = TeacherAuthService();

  bool _obscurePassword = true;
  bool _busy            = false;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  late Animation<Offset>    _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  Future<void> loginUser() async {
    setState(() => _busy = true);
    try {
      final user = await auth.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        final token = JWTService.generateToken(user);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("teacher_token", token);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherDashboard()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Invalid teacher credentials'),
            backgroundColor: _nuDarkBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset('assets/Images/NUBackdrop.png', fit: BoxFit.cover),
          // Navy overlay
          Container(color: _nuDarkBlue.withOpacity(0.72)),
          // Corner accents
          CustomPaint(painter: _CornerAccentPainter()),

          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // ── Header ──────────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                          decoration: const BoxDecoration(
                            color: _nuDarkBlue,
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18)),
                            border: Border(
                                bottom: BorderSide(color: _nuGold, width: 3)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 76, height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: _nuGold, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _nuGold.withOpacity(0.3),
                                      blurRadius: 18, spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/Images/NUSchoolLogo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text('NATIONAL UNIVERSITY',
                                  style: TextStyle(
                                      color: _nuWhite, fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2)),
                              const SizedBox(height: 3),
                              Text('CLARK · FACULTY PORTAL',
                                  style: TextStyle(
                                      color: _nuGold.withOpacity(0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 3)),
                            ],
                          ),
                        ),

                        // ── Form ────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text('Sign in to your account',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54)),
                              ),
                              const SizedBox(height: 22),

                              // Email field
                              _FieldLabel('EMAIL'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                enableSuggestions: false,
                                onSubmitted: (_) => _busy ? null : loginUser(),
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDeco(
                                  hint: 'Enter your email',
                                  prefix: const Icon(Icons.email_outlined,
                                      size: 18, color: _nuDarkBlue),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Password field
                              _FieldLabel('PASSWORD'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                onSubmitted: (_) => _busy ? null : loginUser(),
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDeco(
                                  hint: 'Enter your password',
                                  prefix: const Icon(Icons.lock_outline,
                                      size: 18, color: _nuDarkBlue),
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20, color: Colors.black45,
                                    ),
                                    onPressed: () => setState(
                                            () => _obscurePassword =
                                        !_obscurePassword),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Login button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _busy ? null : loginUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _nuDarkBlue,
                                    foregroundColor: _nuGold,
                                    disabledBackgroundColor:
                                    Colors.black.withOpacity(0.08),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                    textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color: _nuGold,
                                        strokeWidth: 2.5),
                                  )
                                      : Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.login_outlined,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('LOGIN'),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Register button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const TeacherRegisterScreen()),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _nuDarkBlue,
                                    side: BorderSide(
                                        color:
                                        Colors.black.withOpacity(0.15)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                    textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  child: const Text('Create Account'),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Info notice
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F5F8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.black.withOpacity(0.07)),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline,
                                        size: 14, color: Colors.black38),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'This portal is for faculty members only.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                            height: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required Widget prefix,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F5F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _nuGold, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      );
}

// ── Shared widgets ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: Colors.black45, letterSpacing: 0.8),
  );
}

class _CornerAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(24, 0), const Offset(24, 56), p);
    canvas.drawLine(const Offset(0, 24), const Offset(56, 24), p);
    canvas.drawLine(Offset(size.width - 24, 0), Offset(size.width - 24, 56), p);
    canvas.drawLine(Offset(size.width - 56, 24), Offset(size.width, 24), p);
    canvas.drawLine(Offset(24, size.height), Offset(24, size.height - 56), p);
    canvas.drawLine(Offset(0, size.height - 24), Offset(56, size.height - 24), p);
    canvas.drawLine(Offset(size.width - 24, size.height), Offset(size.width - 24, size.height - 56), p);
    canvas.drawLine(Offset(size.width - 56, size.height - 24), Offset(size.width, size.height - 24), p);

    final sp = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.05)
      ..strokeWidth = 36
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-40, size.height * 0.3), Offset(size.width * 0.25, size.height * 0.75), sp);
    canvas.drawLine(Offset(size.width + 40, size.height * 0.25), Offset(size.width * 0.75, size.height * 0.7), sp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}