import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../studentvw_pages/report_form.dart';
import 'login/screens/login_screen.dart';
import 'login/services/jwt_service.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);
const Color _nuLightGray = Color(0xFFF3F4F6);
const Color _nuDarkGray = Color(0xFF1F2937);
const Color _errorRed = Color(0xFFE24B4A);

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

  bool _codeError = false;

  String userName = 'Student';
  String userEmail = 'No email';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

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

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      await _logout(context);
      return;
    }

    final payload = JWTService.verifyToken(token);

    if (payload == null) {
      await _logout(context);
      return;
    }

    final savedFullName = prefs.getString("full_name");
    final savedName = prefs.getString("name");
    final savedUsername = prefs.getString("username");
    final savedStudentName = prefs.getString("student_name");
    final savedEmail = prefs.getString("email");

    String resolvedName = '';
    String resolvedEmail = '';

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
      final uri = Uri.parse(qrData);
      final code = uri.queryParameters['code'];
      if (code == null && !qrData.contains('://')) return qrData.trim();
      if (code != null && code.isNotEmpty) return code.trim();
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
          pcCode: scannedPC,
          initialStudentName: userName,
          initialStudentEmail: userEmail,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => scanLocked = false);
    });
  }

  void _submitCode() {
    String code = uniqueCodeController.text.trim();

    if (code.isEmpty) {
      setState(() => _codeError = true);
      return;
    }

    final uri = Uri.tryParse(code);
    if (uri != null && uri.queryParameters.containsKey('code')) {
      code = uri.queryParameters['code']!.trim();
    }

    final parsedCode = parsePC(code);

    if (parsedCode == null || parsedCode.isEmpty) {
      setState(() => _codeError = true);
      return;
    }

    setState(() => _codeError = false);
    uniqueCodeController.clear();
    _codeFocus.unfocus();
    navigateToReport(parsedCode);
  }

  void _showInvalidQRDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: _errorRed,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Invalid QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This QR code is not recognized by the system. Please scan a valid NU Clark QR code.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: _nuDarkGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (mounted) setState(() => scanLocked = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _nuDarkBlue,
                      foregroundColor: _nuGold,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Try Again',
                      style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
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
                      _showInvalidQRDialog();
                    }
                    break;
                  }
                }
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.32,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.92),
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMenuLine(18),
                              const SizedBox(height: 5),
                              _buildMenuLine(18),
                              const SizedBox(height: 5),
                              _buildMenuLine(12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: _nuGold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _nuGold.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'QR SCANNER',
                            style: TextStyle(
                              color: _nuWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NATIONAL UNIVERSITY CLARK',
                            style: TextStyle(
                              color: _nuGold.withOpacity(0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => SizedBox(
                    width: 280,
                    height: 280,
                    child: CustomPaint(
                      painter: _ScanFramePainter(opacity: _pulseAnim.value),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Align QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _nuGold.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _nuGold.withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _nuGold,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: _nuWhite,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCodeInputField(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _codeError
                ? _errorRed.withOpacity(0.5)
                : Colors.black.withOpacity(0.4),
            blurRadius: _codeError ? 12 : 8,
            spreadRadius: _codeError ? 1 : 0,
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
          fontSize: 15,
          color: _codeError ? _errorRed : _nuWhite,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        decoration: InputDecoration(
          hintText: 'Enter unique code…',
          hintStyle: TextStyle(
            color: _codeError
                ? _errorRed.withOpacity(0.5)
                : Colors.white.withOpacity(0.4),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.keyboard_outlined,
            size: 20,
            color: _codeError ? _errorRed : _nuGold,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6),
            child: GestureDetector(
              onTap: _submitCode,
              child: Container(
                decoration: BoxDecoration(
                  color: _codeError ? _errorRed : _nuGold,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color:
                      (_codeError ? _errorRed : _nuGold).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: _codeError ? Colors.white : _nuDarkBlue,
                ),
              ),
            ),
          ),
          filled: true,
          fillColor: _codeError
              ? const Color(0xFF2D0A09)
              : Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _codeError
                  ? _errorRed.withOpacity(0.7)
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _codeError
                  ? _errorRed.withOpacity(0.7)
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _codeError ? _errorRed : _nuGold,
              width: 2,
            ),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          errorText: _codeError ? 'Invalid or unrecognized code' : null,
          errorStyle: const TextStyle(
            color: _errorRed,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuLine(double width) => Container(
    width: width,
    height: 2.5,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(1.5),
    ),
  );

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Material(
        color: _nuWhite,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 28,
                bottom: 28,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_nuBlue, _nuDarkBlue],
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
                      boxShadow: [
                        BoxShadow(
                          color: _nuGold.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
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
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: _nuWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: _nuGold.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _nuGold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _nuGold.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Student Account',
                      style: TextStyle(
                        color: _nuGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 3,
              color: _nuGold,
            ),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.qr_code_2,
              label: 'Scan / Enter Code',
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  _codeFocus.requestFocus();
                });
              },
            ),
            const Spacer(),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              isDestructive: true,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final double opacity;
  const _ScanFramePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 32.0;
    const strokeW = 3.5;
    const r = 14.0;

    final paint = Paint()
      ..color = Color.fromRGBO(255, 215, 0, opacity)
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(const Offset(r, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, cornerLen), paint);
    canvas.drawArc(
      const Rect.fromLTWH(0, 0, r * 2, r * 2),
      3.14159,
      1.5708,
      false,
      paint,
    );

    canvas.drawLine(Offset(w - cornerLen, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, cornerLen), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
      -1.5708,
      1.5708,
      false,
      paint,
    );

    canvas.drawLine(Offset(0, h - cornerLen), Offset(0, h - r), paint);
    canvas.drawLine(Offset(r, h), Offset(cornerLen, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
      1.5708,
      1.5708,
      false,
      paint,
    );

    canvas.drawLine(Offset(w, h - cornerLen), Offset(w, h - r), paint);
    canvas.drawLine(Offset(w - cornerLen, h), Offset(w - r, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
      0,
      1.5708,
      false,
      paint,
    );

    final centerPaint = Paint()
      ..color = Color.fromRGBO(255, 215, 0, opacity * 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), 3, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) => old.opacity != opacity;
}

class _DrawerItem extends StatefulWidget {
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
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final iconBg = widget.isDestructive
        ? const Color(0xFFFCEBEB)
        : const Color(0xFFE8EEF8);
    final iconColor =
    widget.isDestructive ? const Color(0xFFDC2626) : _nuDarkBlue;
    final textColor =
    widget.isDestructive ? const Color(0xFFDC2626) : _nuDarkGray;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDestructive
                ? const Color(0xFFFCEBEB)
                : const Color(0xFFE8EEF8))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: widget.onTap,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: iconColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(widget.icon, size: 20, color: iconColor),
            ),
            title: Text(
              widget.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: textColor.withOpacity(0.3),
            ),
            dense: false,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }
}