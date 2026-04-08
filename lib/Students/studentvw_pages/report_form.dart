import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login/services/jwt_service.dart';
import '../studentvw_pages/login/services/ai_helper_service.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class StudentReportFormPage extends StatefulWidget {
  final String? pcCode;
  final String? initialStudentName;
  final String? initialStudentEmail;

  const StudentReportFormPage({
    super.key,
    this.pcCode,
    this.initialStudentName,
    this.initialStudentEmail,
  });

  @override
  State<StudentReportFormPage> createState() => _StudentReportFormPageState();
}

class _StudentReportFormPageState extends State<StudentReportFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _commentCtrl = TextEditingController();

  // ── ORIGINAL state — untouched ─────────────────────────────────────────────
  bool _mouseOk      = true;
  bool _keyboardOk   = true;
  bool _monitorOk    = true;
  bool _cablesOk     = true;
  bool _systemUnitOk = true;

  bool _loading    = true;
  bool _submitting = false;
  bool _loadingAi  = false;

  String? _pcCode;
  String? _lab;
  String? _pcLabel;

  AiHelperResult? _aiResult;
  bool  _showAiSuggestion = false;
  bool  _aiTriedFix       = false;
  bool? _aiSolved;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  late Animation<Offset>    _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadPageData();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _commentCtrl.dispose(); _fadeCtrl.dispose();
    super.dispose();
  }

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  Future<void> _loadPageData() async {
    await _loadLoggedInUser();
    await _loadPcData();
    if (mounted) { setState(() => _loading = false); _fadeCtrl.forward(); }
  }

  Future<void> _loadLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null || token.isEmpty) {
        _nameCtrl.text  = (widget.initialStudentName  ?? 'Student').trim();
        _emailCtrl.text = (widget.initialStudentEmail ?? '').trim(); return;
      }
      final payload = JWTService.verifyToken(token);
      if (payload == null) {
        _nameCtrl.text  = (widget.initialStudentName  ?? 'Student').trim();
        _emailCtrl.text = (widget.initialStudentEmail ?? '').trim(); return;
      }
      final uid        = (payload['uid']       ?? '').toString();
      final tokenName  = (payload['full_name'] ?? payload['name'] ?? 'Student').toString();
      final String tokenEmail = (payload['email']     ?? '').toString();
      if (uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          _nameCtrl.text  = (data['full_name'] ?? data['name'] ?? tokenName).toString().trim();
          _emailCtrl.text = (data['email'] ?? tokenEmail).toString().trim(); return;
        }
      }
      _nameCtrl.text  = tokenName.trim();
      _emailCtrl.text = tokenEmail.trim();
    } catch (_) {
      _nameCtrl.text  = (widget.initialStudentName  ?? 'Student').trim();
      _emailCtrl.text = (widget.initialStudentEmail ?? '').trim();
    }
  }

  Future<void> _loadPcData() async {
    try {
      String? code = widget.pcCode;
      if (code == null || code.isEmpty) { final uri = Uri.base; code = uri.queryParameters['code']; }
      if (code == null || code.isEmpty) return;
      final doc = await FirebaseFirestore.instance.collection('pcs').doc(code).get();
      _pcCode = code;
      if (!doc.exists) return;
      final data = doc.data()!;
      _lab     = (data['lab'] ?? '').toString();
      _pcLabel = (data['pc']  ?? '').toString();
    } catch (_) {}
  }

  List<String> _getProblemList() {
    final problems = <String>[];
    if (!_keyboardOk)   problems.add('keyboard');
    if (!_mouseOk)      problems.add('mouse');
    if (!_monitorOk)    problems.add('monitor');
    if (!_cablesOk)     problems.add('cables');
    if (!_systemUnitOk) problems.add('system unit');
    if (problems.isEmpty && _aiResult != null && _aiResult!.category.trim().isNotEmpty) {
      problems.add(_aiResult!.category.trim().toLowerCase());
    }
    return problems;
  }

  String _problemSentence() {
    final p = _getProblemList();
    if (p.isEmpty)    return 'workstation';
    if (p.length == 1) return p.first;
    if (p.length == 2) return '${p[0]} and ${p[1]}';
    return '${p.sublist(0, p.length - 1).join(', ')}, and ${p.last}';
  }

  String _capitalize(String value) {
    if (value.trim().isEmpty) return value;
    final t = value.trim();
    return t[0].toUpperCase() + t.substring(1);
  }

  String _normalizeTipToAttempt(String text) {
    String c = text.trim();
    if (c.isEmpty) return 'basic troubleshooting';
    if (c.endsWith('.')) c = c.substring(0, c.length - 1);
    final l = c.toLowerCase();
    if (l.startsWith('have you tried '))  c = c.substring(15).trim();
    else if (l.startsWith('try '))        c = c.substring(4).trim();
    else if (l.startsWith('please try ')) c = c.substring(11).trim();
    return c.isEmpty ? 'basic troubleshooting' : c;
  }

  String _buildMascotMessage(AiHelperResult result) {
    final problem = _problemSentence();
    final attempt = _normalizeTipToAttempt(result.studentTip);
    return 'It seems like you have a problem with the $problem. Have you tried $attempt?';
  }

  String _buildFinalIncidentNarrative({
    required String originalComment,
    required AiHelperResult aiResult,
    required bool solved,
  }) {
    final problem  = _problemSentence();
    final attempt  = _normalizeTipToAttempt(aiResult.studentTip);
    final cleanCmt = originalComment.trim();
    if (solved) return 'This PC had a problem with the $problem. The student tried $attempt and confirmed that the issue was fixed.';
    if (cleanCmt.isNotEmpty) return 'This PC has a problem with the $problem. The student reported: "$cleanCmt". The student tried $attempt, but the issue still persists.';
    return 'This PC has a problem with the $problem and the student has tried $attempt, but the problem still persists.';
  }

  String _buildFallbackNarrative(String originalComment) {
    final problem  = _problemSentence();
    final cleanCmt = originalComment.trim();
    if (cleanCmt.isEmpty) return 'This PC has a problem with the $problem.';
    return 'This PC has a problem with the $problem. Student description: "$cleanCmt".';
  }

  Future<void> _openAiHelper() async {
    if (_pcCode == null || _pcCode!.isEmpty || _lab == null || _pcLabel == null) {
      _snack('Missing PC information.'); return;
    }
    if (_commentCtrl.text.trim().isEmpty) {
      _snack('Please describe the issue first.'); return;
    }
    setState(() { _loadingAi = true; _showAiSuggestion = false; _aiResult = null; _aiTriedFix = false; _aiSolved = null; });
    final result = await AiHelperService.generate(
      pcCode: _pcCode!, lab: _lab!, pc: _pcLabel!,
      comment: _commentCtrl.text.trim(),
      peripherals: { 'mouse': _mouseOk, 'keyboard': _keyboardOk, 'monitor': _monitorOk, 'cables': _cablesOk, 'system_unit': _systemUnitOk },
    );
    if (!mounted) return;
    setState(() { _loadingAi = false; _aiResult = result; _showAiSuggestion = result != null; });
    if (result == null) _snack('Mascot helper failed. Check logs.');
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pcCode == null || _pcCode!.isEmpty) return;
    setState(() => _submitting = true);

    final studentName  = _nameCtrl.text.trim();
    final studentEmail = _emailCtrl.text.trim().toLowerCase();
    final peripherals  = { 'mouse': _mouseOk, 'keyboard': _keyboardOk, 'monitor': _monitorOk, 'cables': _cablesOk, 'system_unit': _systemUnitOk };
    bool hasProblem    = peripherals.values.any((e) => e == false);
    if (_aiSolved == true) hasProblem = false;
    final bool reportHealthy = _aiSolved == true;
    final bool sendToItso    = _aiSolved != true;
    final String finalNarrative = _aiResult == null
        ? _buildFallbackNarrative(_commentCtrl.text.trim())
        : _buildFinalIncidentNarrative(originalComment: _commentCtrl.text.trim(), aiResult: _aiResult!, solved: _aiSolved == true);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'pc_code': _pcCode, 'lab': _lab ?? '', 'pc': _pcLabel ?? '',
        'student_name': studentName, 'student_email': studentEmail,
        'reported_by': studentName, 'reported_by_name': studentName, 'reported_by_email': studentEmail,
        'comment': _commentCtrl.text.trim(), 'final_report_text': finalNarrative,
        'peripherals': peripherals, 'timestamp': FieldValue.serverTimestamp(),
        'status': reportHealthy ? 'healthy' : 'pending',
        'report_route': reportHealthy ? 'healthy' : 'itso',
        'ai_category': _aiResult?.category ?? '', 'ai_priority': _aiResult?.priority ?? '',
        'ai_student_tip': _aiResult?.studentTip ?? '', 'ai_action_done_template': _aiResult?.actionDoneTemplate ?? '',
        'ai_escalate_to_itso': _aiResult?.escalateToItso ?? sendToItso,
        'ai_itso_action': _aiResult?.itsoAction ?? '',
        'ai_attempted_fix': _showAiSuggestion, 'ai_resolved': _aiSolved == true,
        'ai_attempt_summary': finalNarrative,
      });
      await FirebaseFirestore.instance.collection('attendance').add({
        'student_name': studentName, 'student_email': studentEmail,
        'lab': _lab ?? '', 'pc': _pcLabel ?? '',
        'present': 1.0, 'late': 0.0, 'attendance_score': 1.0,
        'date': DateTime.now().toString().split(' ')[0],
        'timestamp': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('pcs').doc(_pcCode).update({
        'status': hasProblem ? 'problem' : 'available',
        'comment': _commentCtrl.text.trim(), 'final_report_text': finalNarrative,
        'reported_by': studentName, 'reported_by_name': studentName, 'reported_by_email': studentEmail,
        'updated_at': FieldValue.serverTimestamp(), 'peripherals': peripherals,
        'ai_category': _aiResult?.category ?? '', 'ai_priority': _aiResult?.priority ?? '',
        'ai_student_tip': _aiResult?.studentTip ?? '',
        'ai_escalate_to_itso': _aiResult?.escalateToItso ?? sendToItso,
        'ai_itso_action': _aiResult?.itsoAction ?? '',
        'ai_attempted_fix': _showAiSuggestion, 'ai_resolved': _aiSolved == true,
        'ai_attempt_summary': finalNarrative,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reportHealthy ? 'Problem fixed. Report saved as healthy.' : 'Problem submitted to ITSO.'),
        backgroundColor: reportHealthy ? const Color(0xFF3B6D11) : _nuDarkBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      _commentCtrl.clear();
      setState(() {
        _mouseOk = true; _keyboardOk = true; _monitorOk = true; _cablesOk = true; _systemUnitOk = true;
        _aiResult = null; _showAiSuggestion = false; _aiTriedFix = false; _aiSolved = null;
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to submit report: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? const Color(0xFF3B6D11) : _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F8),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _nuDarkBlue, border: Border.all(color: _nuGold, width: 2)),
                child: const Padding(padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(color: _nuGold, strokeWidth: 2.5))),
            const SizedBox(height: 14),
            Text('Loading report form…', style: TextStyle(color: Colors.black45, fontSize: 14)),
          ]),
        ),
      );
    }

    if (_pcCode == null || _pcCode!.isEmpty) {
      return _ErrorScaffold(message: 'Invalid QR code or unique code.', onBack: () => Navigator.pop(context));
    }
    if (_lab == null || _pcLabel == null) {
      return _ErrorScaffold(message: 'PC not found for code:\n$_pcCode', onBack: () => Navigator.pop(context));
    }

    final allOk = _mouseOk && _keyboardOk && _monitorOk && _cablesOk && _systemUnitOk;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: _nuGold, width: 2)),
              child: ClipOval(child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('PC REPORT', style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('NATIONAL UNIVERSITY CLARK', style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 2)),
          ]),
        ]),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(3), child: Container(height: 3, color: _nuGold)),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── PC Info Banner ─────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF003087), Color(0xFF001A52)]),
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                          border: const Border(left: BorderSide(color: _nuGold, width: 5)),
                        ),
                        child: Row(children: [
                          Container(width: 46, height: 46,
                              decoration: BoxDecoration(color: _nuGold.withOpacity(0.12), shape: BoxShape.circle, border: Border.all(color: _nuGold.withOpacity(0.4))),
                              child: const Icon(Icons.desktop_windows_outlined, color: _nuGold, size: 22)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$_lab · $_pcLabel', style: const TextStyle(color: _nuWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(_pcCode!, style: TextStyle(color: _nuGold.withOpacity(0.75), fontSize: 11, fontFamily: 'monospace')),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: allOk ? const Color(0xFF1D9E75).withOpacity(0.2) : const Color(0xFFE24B4A).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: allOk ? const Color(0xFF1D9E75) : const Color(0xFFE24B4A)),
                            ),
                            child: Text(allOk ? 'All OK' : 'Issues',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: allOk ? const Color(0xFF9FE1CB) : const Color(0xFFFCA5A5))),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // ── Student Info ───────────────────────────────────
                      _FormPanel(dotColor: const Color(0xFF185FA5), title: 'Student Information',
                          child: Column(children: [
                            _ReadOnlyField(label: 'FULL NAME',     controller: _nameCtrl,  icon: Icons.person_outline),
                            const SizedBox(height: 14),
                            _ReadOnlyField(label: 'STUDENT EMAIL', controller: _emailCtrl, icon: Icons.email_outlined),
                          ])),

                      const SizedBox(height: 16),

                      // ── Peripheral Status ──────────────────────────────
                      _FormPanel(dotColor: _nuGold, title: 'Peripheral Status',
                          subtitle: 'Uncheck any item that has a problem',
                          child: Column(children: [
                            _PeripheralTile(label: 'Mouse',       icon: Icons.mouse_outlined,     value: _mouseOk,      onChanged: (v) => setState(() => _mouseOk      = v ?? true)),
                            _PeripheralTile(label: 'Keyboard',    icon: Icons.keyboard_outlined,  value: _keyboardOk,   onChanged: (v) => setState(() => _keyboardOk   = v ?? true)),
                            _PeripheralTile(label: 'Monitor',     icon: Icons.monitor_outlined,   value: _monitorOk,    onChanged: (v) => setState(() => _monitorOk    = v ?? true)),
                            _PeripheralTile(label: 'Cables',      icon: Icons.cable_outlined,     value: _cablesOk,     onChanged: (v) => setState(() => _cablesOk     = v ?? true)),
                            _PeripheralTile(label: 'System Unit', icon: Icons.computer_outlined,  value: _systemUnitOk, onChanged: (v) => setState(() => _systemUnitOk = v ?? true), isLast: true),
                          ])),

                      const SizedBox(height: 16),

                      // ── Comment ────────────────────────────────────────
                      _FormPanel(dotColor: const Color(0xFF639922), title: 'Comment / Issue',
                          subtitle: 'Describe the problem in detail',
                          child: TextFormField(
                            controller: _commentCtrl,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 14),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Please describe the issue first.' : null,
                            decoration: InputDecoration(
                              hintText: 'Example: The keyboard is not responding even after reconnecting it.',
                              hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withOpacity(0.12))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withOpacity(0.12))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _nuDarkBlue, width: 1.5)),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          )),

                      const SizedBox(height: 16),

                      // ── Ask Lab Buddy button ───────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loadingAi ? null : _openAiHelper,
                          icon: _loadingAi
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _nuDarkBlue))
                              : const Icon(Icons.smart_toy_outlined, size: 18),
                          label: Text(_loadingAi ? 'Opening Lab Buddy…' : 'Ask Lab Buddy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _nuDarkBlue,
                            side: const BorderSide(color: _nuDarkBlue, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      // ── AI Mascot Card ─────────────────────────────────
                      if (_showAiSuggestion && _aiResult != null) ...[
                        const SizedBox(height: 16),
                        _MascotHelperCard(
                          mascotName: 'Lab Buddy',
                          issueType: _capitalize(_problemSentence()),
                          priority:  _aiResult!.priority,
                          message:   _buildMascotMessage(_aiResult!),
                          tip:       _aiResult!.studentTip,
                          solved:    _aiSolved,
                          onSolved:    () => setState(() { _aiTriedFix = true; _aiSolved = true; }),
                          onNotSolved: () => setState(() { _aiTriedFix = true; _aiSolved = false; }),
                        ),

                        // Final narrative preview when not solved
                        if (_aiTriedFix && _aiSolved == false) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD58A)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFF854F0B)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                _buildFinalIncidentNarrative(originalComment: _commentCtrl.text.trim(), aiResult: _aiResult!, solved: false),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF633806), height: 1.5, fontWeight: FontWeight.w500),
                              )),
                            ]),
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // ── Submit button ──────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submitReport,
                          icon: _submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _nuGold, strokeWidth: 2))
                              : const Icon(Icons.send_outlined, size: 18),
                          label: Text(_submitting ? 'Submitting…' : 'Submit Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _nuDarkBlue,
                            foregroundColor: _nuGold,
                            disabledBackgroundColor: Colors.black.withOpacity(0.08),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MASCOT HELPER CARD
// ══════════════════════════════════════════════════════════════════════════════
class _MascotHelperCard extends StatelessWidget {
  final String mascotName, issueType, priority, message, tip;
  final bool? solved;
  final VoidCallback onSolved, onNotSolved;

  const _MascotHelperCard({
    required this.mascotName, required this.issueType, required this.priority,
    required this.message, required this.tip, required this.solved,
    required this.onSolved, required this.onNotSolved,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh   = priority.toLowerCase() == 'high';
    final isMedium = priority.toLowerCase() == 'medium';
    final badgeColor = isHigh
        ? const Color(0xFFE24B4A)
        : isMedium ? const Color(0xFFF59E0B) : const Color(0xFF185FA5);
    final badgeBg = isHigh
        ? const Color(0xFFFCEBEB)
        : isMedium ? const Color(0xFFFAEEDA) : const Color(0xFFE6F1FB);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [

        // ── Card header ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _nuGold, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Lab Buddy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _nuDarkBlue, letterSpacing: 0.3)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
              child: Text('Priority: $priority',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Mascot row ────────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3BF),
                  shape: BoxShape.circle,
                  border: Border.all(color: _nuGold, width: 2.5),
                  boxShadow: [BoxShadow(color: _nuGold.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)],
                ),
                child: const Icon(Icons.smart_toy_rounded, color: _nuDarkBlue, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD9E2FF)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Detected issue: $issueType',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _nuDarkBlue, letterSpacing: 0.3)),
                    const SizedBox(height: 8),
                    Text(message, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151))),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_outline, size: 14, color: _nuDarkBlue),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Suggested: $tip',
                            style: const TextStyle(fontSize: 12, color: _nuDarkBlue, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Solved question ───────────────────────────────────────────
            const Text('Were you able to solve it?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: onSolved,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('YES, SOLVED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B6D11),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: onNotSolved,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('STILL NOT SOLVED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE24B4A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )),
            ]),

            // ── Resolution message ─────────────────────────────────────────
            if (solved != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: solved == true ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(solved == true ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      size: 16,
                      color: solved == true ? const Color(0xFF3B6D11) : const Color(0xFFE24B4A)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    solved == true
                        ? 'Great! The issue will be saved as resolved.'
                        : 'The issue will be forwarded to ITSO with your attempted fix.',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: solved == true ? const Color(0xFF27500A) : const Color(0xFF791F1F),
                    ),
                  )),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _FormPanel extends StatelessWidget {
  final Color dotColor;
  final String title;
  final String? subtitle;
  final Widget child;

  const _FormPanel({
    required this.dotColor, required this.title,
    required this.child, this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black.withOpacity(0.07)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _nuDarkBlue, letterSpacing: 0.3)),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text('· $subtitle', style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ]),
      ),
      Padding(padding: const EdgeInsets.all(18), child: child),
    ]),
  );
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  const _ReadOnlyField({required this.label, required this.controller, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
        decoration: InputDecoration(
          filled: true, fillColor: const Color(0xFFF4F5F8),
          prefixIcon: Icon(icon, color: _nuDarkBlue, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), isDense: true,
        ),
      ),
    ],
  );
}

class _PeripheralTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool isLast;

  const _PeripheralTile({
    required this.label, required this.icon,
    required this.value, required this.onChanged, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: value ? const Color(0xFF3B6D11) : const Color(0xFF791F1F)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            Text(value ? 'Working fine' : 'Has a problem',
                style: TextStyle(fontSize: 11, color: value ? const Color(0xFF639922) : const Color(0xFFE24B4A))),
          ])),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF639922),
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: value ? const Color(0xFF639922) : Colors.black26, width: 1.5),
          ),
        ]),
      ),
    ),
  );
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorScaffold({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F5F8),
    appBar: AppBar(
      backgroundColor: _nuDarkBlue, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18), onPressed: onBack),
      title: const Text('PC REPORT', style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(3), child: Container(height: 3, color: _nuGold)),
    ),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 60, height: 60,
          decoration: BoxDecoration(color: const Color(0xFFFCEBEB), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF09595))),
          child: const Icon(Icons.error_outline, color: Color(0xFFE24B4A), size: 30)),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.6)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back, size: 16),
        label: const Text('Go Back'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _nuDarkBlue, foregroundColor: _nuGold, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ])),
  );
}