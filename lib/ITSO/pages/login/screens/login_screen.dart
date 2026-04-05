import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../landingITso.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _email    = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _auth = AuthService();

  bool    _busy            = false;
  String? _error;
  bool    _obscurePassword = true;

  // ── Entrance animation ─────────────────────────────────────────────────────
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
    _email.dispose();
    _password.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      final user = await _auth.login(_email.text, _password.text);
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingITSO()),
        );
      } else {
        setState(() => _error = 'Invalid email or password.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() =>
      _error = e.toString().replaceFirst('Exception: ', ''));
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

          // ── Background image ────────────────────────────────────────────────
          Image.asset(
            'assets/Images/NUBackdrop.png',
            fit: BoxFit.cover,
          ),

          // ── Dark blue overlay ───────────────────────────────────────────────
          Container(color: _nuDarkBlue.withOpacity(0.72)),

          // ── Geometric corner accents ────────────────────────────────────────
          CustomPaint(painter: _CornerAccentPainter()),

          // ── Centered login card ─────────────────────────────────────────────
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

                        // ── Card header ─────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                          decoration: const BoxDecoration(
                            color: _nuDarkBlue,
                            borderRadius:
                            BorderRadius.vertical(top: Radius.circular(18)),
                            border: Border(
                                bottom: BorderSide(color: _nuGold, width: 3)),
                          ),
                          child: Column(
                            children: [
                              // NU Logo circle
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
                              Text('CLARK · ITSO SYSTEM',
                                  style: TextStyle(
                                      color: _nuGold.withOpacity(0.85),
                                      fontSize: 10, fontWeight: FontWeight.w600,
                                      letterSpacing: 3)),
                            ],
                          ),
                        ),

                        // ── Form body ───────────────────────────────────────
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
                                        color: Colors.black54,
                                        letterSpacing: 0.3)),
                              ),

                              const SizedBox(height: 22),

                              // Email field
                              _FieldLabel('EMAIL'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                enableSuggestions: false,
                                onSubmitted: (_) => _busy ? null : _submit(),
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
                                controller: _password,
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                onSubmitted: (_) => _busy ? null : _submit(),
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDeco(
                                  hint: 'Enter your password',
                                  prefix: const Icon(Icons.lock_outline,
                                      size: 18, color: _nuDarkBlue),
                                  suffix: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Image.asset(
                                        _obscurePassword
                                            ? 'assets/Icons/hidden.png'
                                            : 'assets/Icons/eye.png',
                                        width: 20, height: 20,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Error message
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCEBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFF09595)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 15,
                                          color: Color(0xFFE24B4A)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF791F1F))),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 22),

                              // Login button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _busy ? null : _submit,
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
                                    Expanded(
                                      child: Text(
                                        'Only Admin and ITSO accounts can access this system.',
                                        style: const TextStyle(
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
        hintStyle:
        const TextStyle(color: Colors.black26, fontSize: 13),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F5F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          BorderSide(color: Colors.black.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          BorderSide(color: Colors.black.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: _nuGold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        isDense: true,
      );
}

// ── Field Label ───────────────────────────────────────────────────────────────
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

// ── Corner Accent Painter ─────────────────────────────────────────────────────
class _CornerAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(const Offset(24, 0), const Offset(24, 56), paint);
    canvas.drawLine(const Offset(0, 24), const Offset(56, 24), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - 24, 0),
        Offset(size.width - 24, 56), paint);
    canvas.drawLine(Offset(size.width - 56, 24),
        Offset(size.width, 24), paint);
    // Bottom-left
    canvas.drawLine(Offset(24, size.height),
        Offset(24, size.height - 56), paint);
    canvas.drawLine(Offset(0, size.height - 24),
        Offset(56, size.height - 24), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - 24, size.height),
        Offset(size.width - 24, size.height - 56), paint);
    canvas.drawLine(Offset(size.width - 56, size.height - 24),
        Offset(size.width, size.height - 24), paint);

    // Diagonal soft stripes
    final stripePaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.05)
      ..strokeWidth = 36
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(-40, size.height * 0.3),
        Offset(size.width * 0.25, size.height * 0.75),
        stripePaint);
    canvas.drawLine(
        Offset(size.width + 40, size.height * 0.25),
        Offset(size.width * 0.75, size.height * 0.7),
        stripePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}