import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/jwt_service.dart';
import 'login_screen.dart';
import '../../dashboard.dart';

// NU Clark Brand Colors
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuLightGold = Color(0xFFFFF0A0);
const Color _nuWhite = Color(0xFFF8F9FF);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  late double w;
  late double h;
  late double scale;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // FIXED: use teacher_token
    final token = prefs.getString("teacher_token");

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (token != null) {
      try {
        final payload = JWTService.verifyToken(token);

        if (payload != null) {
          final role = (payload["role"] ?? "").toString().trim();

          // only Teacher can enter teacher dashboard
          if (role.toLowerCase() == "teacher") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TeacherDashboard()),
            );
            return;
          } else {
            await prefs.remove("teacher_token");
          }
        } else {
          await prefs.remove("teacher_token");
        }
      } catch (e) {
        debugPrint("Token verification failed: $e");
        await prefs.remove("teacher_token");
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    w = size.width;
    h = size.height;

    scale = (w / 375).clamp(0.8, 1.4);

    return Scaffold(
      backgroundColor: _nuDarkBlue,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001A52),
              Color(0xFF003087),
              Color(0xFF001A52),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildCornerAccents(),
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: _scaleAnim,
                  child: _buildLogoEmblem(),
                ),
                SizedBox(height: 32 * scale),
                _buildUniversityName(),
                SizedBox(height: 16 * scale),
                _buildDivider(),
                SizedBox(height: 18 * scale),
                _buildSystemBadge(),
                SizedBox(height: 10 * scale),
                Text(
                  'Empowering Excellence in Education',
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: _nuWhite.withOpacity(0.45),
                    letterSpacing: 1.2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(flex: 3),
                _buildLoader(),
                SizedBox(height: 40 * scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCornerAccents() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _cornerLines(isLeft: true),
          _cornerLines(isLeft: false),
        ],
      ),
    );
  }

  Widget _cornerLines({required bool isLeft}) {
    return SizedBox(
      width: 40 * scale,
      height: 40 * scale,
      child: CustomPaint(painter: _CornerPainter(isLeft: isLeft)),
    );
  }

  Widget _buildLogoEmblem() {
    return Container(
      width: 140 * scale,
      height: 140 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _nuGold, width: 2.5 * scale),
        boxShadow: [
          BoxShadow(
            color: _nuGold.withOpacity(0.3),
            blurRadius: 28 * scale,
            spreadRadius: 4 * scale,
          ),
          BoxShadow(
            color: _nuBlue.withOpacity(0.5),
            blurRadius: 16 * scale,
            spreadRadius: 2 * scale,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120 * scale,
            height: 120 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _nuGold.withOpacity(0.25),
                width: 1,
              ),
            ),
          ),
          ClipOval(
            child: Image.asset(
              'assets/Images/NUSchoolLogo.png',
              width: 115 * scale,
              height: 115 * scale,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversityName() {
    return Column(
      children: [
        Text(
          'NATIONAL UNIVERSITY',
          style: TextStyle(
            fontSize: 20 * scale,
            fontWeight: FontWeight.w900,
            color: _nuWhite,
            letterSpacing: 4,
          ),
        ),
        SizedBox(height: 4 * scale),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE6B800), _nuLightGold, _nuGold],
          ).createShader(bounds),
          child: Text(
            'CLARK',
            style: TextStyle(
              fontSize: 32 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 140 * scale,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _nuGold.withOpacity(0.4),
            _nuGold,
            _nuGold.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _nuGold.withOpacity(0.25)),
      ),
      child: Text(
        'FACULTY PORTAL',
        style: TextStyle(
          color: _nuGold,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        SizedBox(
          width: 26 * scale,
          height: 26 * scale,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(_nuGold),
            backgroundColor: Colors.white.withOpacity(0.12),
          ),
        ),
        SizedBox(height: 14 * scale),
        Text(
          'Loading secure access...',
          style: TextStyle(
            color: _nuWhite.withOpacity(0.65),
            fontSize: 11.5 * scale,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isLeft;
  _CornerPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _nuGold.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    if (isLeft) {
      path
        ..moveTo(0, size.height * 0.45)
        ..lineTo(0, 0)
        ..lineTo(size.width * 0.45, 0);
    } else {
      path
        ..moveTo(size.width * 0.55, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.45);
    }

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}