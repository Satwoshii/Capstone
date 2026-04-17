import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../studentvw_pages/report_form.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class EnterCodePage extends StatefulWidget {
  const EnterCodePage({super.key});

  @override
  State<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends State<EnterCodePage>
    with SingleTickerProviderStateMixin {

  final codeController = TextEditingController();
  String? _errorText;
  bool _isChecking = false;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  late Animation<Offset>    _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    codeController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> submitCode() async {
    String code = codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorText = 'Please enter a unique code');
      return;
    }

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    try {
      String actualCode = code;
      final uri = Uri.tryParse(code);
      if (uri != null && uri.queryParameters.containsKey('code')) {
        actualCode = uri.queryParameters['code']!.trim();
      }

      // Verify if the PC exists in Firestore before navigating
      final doc = await FirebaseFirestore.instance.collection('pcs').doc(actualCode).get();

      if (!doc.exists) {
        setState(() {
          _errorText = 'PC Not Found. Please put a proper code';
          _isChecking = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isChecking = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentReportFormPage(pcCode: actualCode),
        ),
      );
    } catch (e) {
      setState(() {
        _errorText = 'Connection error. Please try again.';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),

      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
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
                const Text('ENTER CODE',
                    style: TextStyle(
                        color: _nuWhite, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NATIONAL UNIVERSITY CLARK',
                    style: TextStyle(
                        color: _nuGold.withOpacity(0.85),
                        fontSize: 10, fontWeight: FontWeight.w500,
                        letterSpacing: 2)),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _nuDarkBlue,
                      border: Border.all(color: _nuGold, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _nuGold.withOpacity(0.2),
                          blurRadius: 20, spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_2, color: _nuGold, size: 36),
                  ),

                  const SizedBox(height: 20),

                  const Text('Enter Your PC Code',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: _nuDarkBlue)),
                  const SizedBox(height: 6),
                  Text(
                    'Type or paste the unique code from your PC\'s QR label',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.black45, height: 1.5),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.07)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        const Text('UNIQUE CODE',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: Colors.black45, letterSpacing: 0.8)),
                        const SizedBox(height: 8),

                        TextField(
                          controller: codeController,
                          onSubmitted: (_) => _isChecking ? null : submitCode(),
                          style: const TextStyle(
                              fontSize: 14, fontFamily: 'monospace',
                              letterSpacing: 0.5),
                          decoration: InputDecoration(
                            hintText: 'e.g. L201-PC1-A1B2',
                            errorText: _errorText,
                            hintStyle: const TextStyle(
                                color: Colors.black26,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5),
                            prefixIcon: const Icon(
                                Icons.qr_code, color: _nuDarkBlue, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.black.withOpacity(0.12)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.black.withOpacity(0.12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: _nuDarkBlue, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red, width: 2.0),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        if (_errorText == null)
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isChecking ? null : submitCode,
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(color: _nuGold, strokeWidth: 2))
                                : const Icon(Icons.send_outlined, size: 16),
                            label: Text(_isChecking ? 'Checking...' : 'Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _nuDarkBlue,
                              foregroundColor: _nuGold,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: _nuDarkBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _nuDarkBlue.withOpacity(0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EEF8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.lightbulb_outline,
                              size: 16, color: _nuDarkBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Where to find the code?',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: _nuDarkBlue)),
                              const SizedBox(height: 4),
                              Text(
                                'Look for the QR sticker attached to your PC unit. Scan it with the QR scanner or type the code printed below it.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54,
                                    height: 1.5),
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
    );
  }
}
