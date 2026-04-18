import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../studentvw_pages/report_form.dart';
import 'login/screens/login_screen.dart';
import 'login/services/jwt_service.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  bool scanLocked = false;
  final TextEditingController uniqueCodeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  // true = red glow, false = normal
  bool _codeError = false;

  String userName  = 'Student';
  String userEmail = 'No email';

  // Scan frame pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _loadUserInfo();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    uniqueCodeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ── ORIGINAL logic — ALL UNTOUCHED ──────────────────────────────────────────
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) { await _logout(context); return; }
    final payload = JWTService.verifyToken(token);
    if (payload == null) { await _logout(context); return; }
    if (!mounted) return;
    setState(() {
      userName  = (payload['full_name'] ?? payload['name'] ?? 'Student').toString();
      userEmail = (payload['email'] ?? 'No email').toString();
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  String? parsePC(String qrData) {
    try {
      final uri  = Uri.parse(qrData);
      final code = uri.queryParameters['code'];
      if (code == null && !qrData.contains('://')) return qrData.trim();
      if (code != null && code.isNotEmpty)          return code.trim();
    } catch (_) {
      if (qrData.trim().isNotEmpty) return qrData.trim();
    }
    return null;
  }

  void navigateToReport(String scannedPC) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentReportFormPage(
          pcCode:              scannedPC,
          initialStudentName:  userName,
          initialStudentEmail: userEmail,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => scanLocked = false);
    });
  }

  // Submits the inline code field — no dialog, error glows red instead
  void _submitCode() {
    String code = uniqueCodeController.text.trim();

    if (code.isEmpty) {
      setState(() => _codeError = true);
      return;
    }

    // Extract code from a pasted URL if needed (original parsePC logic preserved)
    final uri = Uri.tryParse(code);
    if (uri != null && uri.queryParameters.containsKey('code')) {
      code = uri.queryParameters['code']!.trim();
    }

    final parsedCode = parsePC(code);

    if (parsedCode == null || parsedCode.isEmpty) {
      // Bad code — glow red, don't navigate
      setState(() => _codeError = true);
      return;
    }

    // Clear error and proceed
    setState(() => _codeError = false);
    uniqueCodeController.clear();
    _codeFocus.unfocus();
    navigateToReport(parsedCode);
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [

          // ── Camera feed ──────────────────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.noDuplicates,
              ),
              onDetect: (BarcodeCapture capture) {
                if (scanLocked) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null) {
                    scanLocked = true;
                    final parsedCode = parsePC(raw);
                    if (parsedCode != null) {
                      navigateToReport(parsedCode);
                    } else {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE24B4A),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Invalid QR Code',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.all(22),
                                child: Text(
                                  'This QR code is not recognized by the system. Please scan a valid NU Clark QR code.',
                                  style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (mounted) setState(() => scanLocked = false);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _nuDarkBlue,
                                      foregroundColor: _nuGold,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    break;
                  }
                }
              },
            ),
          ),

          // ── Top vignette ─────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Bottom vignette ───────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.38,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.88), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Top navigation bar ───────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    // Hamburger
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _line(18), const SizedBox(height: 4),
                              _line(18), const SizedBox(height: 4),
                              _line(12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Logo
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white,
                        border: Border.all(color: _nuGold, width: 1.5),
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('QR SCANNER',
                            style: TextStyle(color: _nuWhite, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        Text('NATIONAL UNIVERSITY CLARK',
                            style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 8, fontWeight: FontWeight.w500, letterSpacing: 1.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Scan frame ───────────────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => SizedBox(
                width: 260, height: 260,
                child: CustomPaint(
                  painter: _ScanFramePainter(opacity: _pulseAnim.value),
                ),
              ),
            ),
          ),

          // ── Hint label ───────────────────────────────────────────────────────
          Positioned(
            bottom: 200, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Align QR code within the frame',
                    style: TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 0.3)),
              ),
            ),
          ),

          // ── Bottom action area ────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User info pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: _nuGold.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: _nuGold.withOpacity(0.5)),
                            ),
                            child: const Icon(Icons.person, color: _nuGold, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(userName,
                                  style: const TextStyle(color: _nuWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(userEmail,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Inline code entry (replaces dialog button) ──────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _codeError
                            ? [
                          BoxShadow(
                            color: const Color(0xFFE24B4A).withOpacity(0.7),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: uniqueCodeController,
                        focusNode: _codeFocus,
                        onChanged: (_) {
                          if (_codeError) setState(() => _codeError = false);
                        },
                        onSubmitted: (_) => _submitCode(),
                        style: TextStyle(
                          fontSize: 14,
                          color: _codeError ? const Color(0xFFE24B4A) : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter unique code…',
                          hintStyle: TextStyle(
                            color: _codeError
                                ? const Color(0xFFE24B4A).withOpacity(0.6)
                                : Colors.white38,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.keyboard_outlined,
                            size: 20,
                            color: _codeError ? const Color(0xFFE24B4A) : _nuGold,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: _submitCode,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _codeError ? const Color(0xFFE24B4A) : _nuGold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: _codeError ? Colors.white : _nuDarkBlue,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: _codeError
                              ? const Color(0xFF2D0A09)
                              : Colors.black.withOpacity(0.55),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeError
                                  ? const Color(0xFFE24B4A)
                                  : Colors.white.withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeError
                                  ? const Color(0xFFE24B4A)
                                  : Colors.white.withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeError ? const Color(0xFFE24B4A) : _nuGold,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          errorText: _codeError ? 'Invalid or unrecognized code' : null,
                          errorStyle: const TextStyle(
                            color: Color(0xFFE24B4A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(double width) => Container(
    width: width, height: 2,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
  );

  // ── Drawer ──────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24, left: 20, right: 20,
            ),
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
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white,
                    border: Border.all(color: _nuGold, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 14),
                Text(userName,
                    style: const TextStyle(color: _nuWhite, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(userEmail,
                    style: TextStyle(color: _nuGold.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _nuGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _nuGold.withOpacity(0.35)),
                  ),
                  child: const Text('Student',
                      style: TextStyle(color: _nuGold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
            label: 'Scan / Enter Code',
            onTap: () {
              Navigator.pop(context);
              // Focus the inline code field instead of opening a dialog
              Future.delayed(const Duration(milliseconds: 300), () {
                _codeFocus.requestFocus();
              });
            },
          ),

          const Spacer(),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          _DrawerItem(
            icon: Icons.logout,
            label: 'Logout',
            isDestructive: true,
            onTap: () => _logout(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Scan Frame Painter ────────────────────────────────────────────────────────
class _ScanFramePainter extends CustomPainter {
  final double opacity;
  const _ScanFramePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen  = 28.0;
    const strokeW    = 4.0;
    const r          = 12.0;

    final paint = Paint()
      ..color       = Color.fromRGBO(255, 215, 0, opacity)
      ..strokeWidth = strokeW
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, cornerLen), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14159, 1.5708, false, paint);

    // Top-right
    canvas.drawLine(Offset(w - cornerLen, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, cornerLen), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2), -1.5708, 1.5708, false, paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - cornerLen), Offset(0, h - r), paint);
    canvas.drawLine(Offset(r, h), Offset(cornerLen, h), paint);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2), 1.5708, 1.5708, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(w, h - cornerLen), Offset(w, h - r), paint);
    canvas.drawLine(Offset(w - cornerLen, h), Offset(w - r, h), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2), 0, 1.5708, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) => old.opacity != opacity;
}

// ── Drawer Item ───────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon, required this.label, required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive ? const Color(0xFF791F1F) : const Color(0xFF374151);
    final iconBg = isDestructive ? const Color(0xFFFCEBEB) : const Color(0xFFE8EEF8);
    final iconColor = isDestructive ? const Color(0xFF791F1F) : _nuDarkBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isDestructive ? const Color(0xFFFCEBEB) : Colors.transparent,
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
    );
  }
}