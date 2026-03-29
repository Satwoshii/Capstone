import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/jwt_service.dart';
import 'login_screen.dart';
import '../../dashboardweb.dart';

// NU Clark Brand Colors
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuLightGold = Color(0xFFFFF0A0);
const Color _nuWhite = Color(0xFFF8F9FF);

class SplashScreen extends StatefulWidget {
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

  checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    Timer(const Duration(seconds: 2), () {
      if (token != null) {
        var payload = JWTService.verifyToken(token);
        if (payload != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
          return;
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    w = size.width;
    h = size.height;

    // Responsive scaling (safe clamp)
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
      width: 130 * scale,
      height: 130 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF0044BB), Color(0xFF003087), Color(0xFF001A52)],
        ),
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
            width: 110 * scale,
            height: 110 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _nuGold.withOpacity(0.25),
                width: 1 * scale,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_nuGold, _nuLightGold, Color(0xFFE6B800)],
                ).createShader(bounds),
                child: Text(
                  'NU',
                  style: TextStyle(
                    fontSize: 48 * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(height: 4 * scale),
              Container(
                width: 46 * scale,
                height: 1.5 * scale,
                color: _nuGold.withOpacity(0.75),
              ),
              SizedBox(height: 4 * scale),
              Text(
                'CLARK',
                style: TextStyle(
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w700,
                  color: _nuGold.withOpacity(0.9),
                  letterSpacing: 4,
                ),
              ),
            ],
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
            'C L A R K',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 56 * scale, height: 1, color: _nuGold),
        SizedBox(width: 6 * scale),
        Container(width: 5 * scale, height: 5 * scale, color: _nuGold),
        SizedBox(width: 6 * scale),
        Container(width: 22 * scale, height: 1.5 * scale, color: _nuGold),
      ],
    );
  }

  Widget _buildSystemBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 9 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: _nuGold.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(3 * scale),
        color: _nuGold.withOpacity(0.07),
      ),
      child: Text(
        'IT SERVICE OFFICE SYSTEM',
        style: TextStyle(
          fontSize: 11 * scale,
          fontWeight: FontWeight.w700,
          color: _nuGold,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        SizedBox(
          width: 140 * scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2 * scale),
            child: LinearProgressIndicator(
              backgroundColor: _nuWhite.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_nuGold),
              minHeight: 2 * scale,
            ),
          ),
        ),
        SizedBox(height: 10 * scale),
        Text(
          'L O A D I N G',
          style: TextStyle(
            fontSize: 9 * scale,
            color: _nuWhite.withOpacity(0.3),
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

// Corner painter (unchanged)
class _CornerPainter extends CustomPainter {
  final bool isLeft;
  const _CornerPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (isLeft) {
      canvas.drawLine(Offset(0, size.height), const Offset(0, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
    } else {
      canvas.drawLine(
          Offset(size.width, size.height), Offset(size.width, 0), paint);
      canvas.drawLine(Offset(size.width, 0), const Offset(0, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}