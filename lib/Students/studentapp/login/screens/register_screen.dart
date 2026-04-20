import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final fullName        = TextEditingController();
  final email           = TextEditingController();
  final section         = TextEditingController();
  final password        = TextEditingController();
  final confirmPassword = TextEditingController();
  final auth = AuthService();

  bool showPassword        = false;
  bool showConfirmPassword = false;
  bool isSubmitting        = false;
  String? confirmPasswordError;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    section.dispose();
    password.dispose();
    confirmPassword.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    final normalizedName = fullName.text.trim();
    final normalizedSection = section.text.trim().toUpperCase();
    final normalizedEmail = email.text.trim().toLowerCase();
    final normalizedPassword = password.text;
    final normalizedConfirm = confirmPassword.text;

    if (normalizedName.isEmpty ||
        normalizedSection.isEmpty ||
        normalizedEmail.isEmpty ||
        normalizedPassword.isEmpty ||
        normalizedConfirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields'),
          backgroundColor: _nuDarkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (normalizedPassword != normalizedConfirm) {
      setState(() => confirmPasswordError = 'Passwords do not match');
      return;
    }

    setState(() {
      confirmPasswordError = null;
      isSubmitting = true;
    });

    try {
      await auth.register(
        normalizedName,
        normalizedSection,
        normalizedEmail,
        normalizedPassword,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registration successful'),
          backgroundColor: const Color(0xFF3B6D11),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: _nuDarkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Images/NUBackdrop.png', fit: BoxFit.cover),
          Container(color: _nuDarkBlue.withOpacity(0.72)),
          CustomPaint(painter: _CornerAccentPainter()),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Container(
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                            decoration: const BoxDecoration(
                              color: _nuDarkBlue,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                              border: Border(
                                bottom: BorderSide(color: _nuGold, width: 3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: _nuGold,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _nuGold.withOpacity(0.3),
                                        blurRadius: 18,
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
                                const SizedBox(height: 14),
                                const Text(
                                  'NATIONAL UNIVERSITY',
                                  style: TextStyle(
                                    color: _nuWhite,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'CLARK · STUDENT PORTAL',
                                  style: TextStyle(
                                    color: _nuGold.withOpacity(0.85),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    'Create your account',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                const _FieldLabel('FULL NAME'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: fullName,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDeco(
                                    hint: 'Enter your full name',
                                    prefix: const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                      color: _nuDarkBlue,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                const _FieldLabel('SECTION'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: section,
                                  textCapitalization:
                                  TextCapitalization.characters,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDeco(
                                    hint: 'Enter your section',
                                    prefix: const Icon(
                                      Icons.groups_2_outlined,
                                      size: 18,
                                      color: _nuDarkBlue,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                const _FieldLabel('EMAIL'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDeco(
                                    hint: 'Enter your email',
                                    prefix: const Icon(
                                      Icons.email_outlined,
                                      size: 18,
                                      color: _nuDarkBlue,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                const _FieldLabel('PASSWORD'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: password,
                                  obscureText: !showPassword,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDeco(
                                    hint: 'Create a password',
                                    prefix: const Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                      color: _nuDarkBlue,
                                    ),
                                    suffix: _eyeToggle(
                                      show: showPassword,
                                      onTap: () => setState(
                                            () => showPassword = !showPassword,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                const _FieldLabel('CONFIRM PASSWORD'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: confirmPassword,
                                  obscureText: !showConfirmPassword,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  onChanged: (_) {
                                    if (confirmPasswordError != null) {
                                      setState(
                                            () => confirmPasswordError = null,
                                      );
                                    }
                                  },
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDeco(
                                    hint: 'Repeat your password',
                                    prefix: const Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                      color: _nuDarkBlue,
                                    ),
                                    suffix: _eyeToggle(
                                      show: showConfirmPassword,
                                      onTap: () => setState(
                                            () => showConfirmPassword =
                                        !showConfirmPassword,
                                      ),
                                    ),
                                  ).copyWith(
                                    errorText: confirmPasswordError,
                                    errorStyle: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFE24B4A),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE24B4A),
                                        width: 1.5,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFF09595),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isSubmitting ? null : registerUser,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _nuDarkBlue,
                                      foregroundColor: _nuGold,
                                      disabledBackgroundColor:
                                      Colors.black.withOpacity(0.08),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    child: isSubmitting
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: _nuGold,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                        : Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.person_add_outlined,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('REGISTER'),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _nuDarkBlue,
                                      side: BorderSide(
                                        color: Colors.black.withOpacity(0.15),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text(
                                      'Already have an account? Log in',
                                    ),
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
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required Widget prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black26,
        fontSize: 13,
      ),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      isDense: true,
    );
  }

  Widget _eyeToggle({
    required bool show,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          show ? 'assets/Icons/eye.png' : 'assets/Icons/hidden.png',
          width: 20,
          height: 20,
          color: Colors.black45,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.black45,
        letterSpacing: 0.8,
      ),
    );
  }
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
    canvas.drawLine(
      Offset(size.width - 24, 0),
      Offset(size.width - 24, 56),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 56, 24),
      Offset(size.width, 24),
      p,
    );
    canvas.drawLine(
      Offset(24, size.height),
      Offset(24, size.height - 56),
      p,
    );
    canvas.drawLine(
      Offset(0, size.height - 24),
      Offset(56, size.height - 24),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 24, size.height),
      Offset(size.width - 24, size.height - 56),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 56, size.height - 24),
      Offset(size.width, size.height - 24),
      p,
    );

    final sp = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.05)
      ..strokeWidth = 36
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(-40, size.height * 0.3),
      Offset(size.width * 0.25, size.height * 0.75),
      sp,
    );
    canvas.drawLine(
      Offset(size.width + 40, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.7),
      sp,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}