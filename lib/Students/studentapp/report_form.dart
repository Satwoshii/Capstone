import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login/services/jwt_service.dart';
import '../studentapp/login/services/ai_helper_service.dart';

const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);

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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool _mouseOk = true;
  bool _keyboardOk = true;
  bool _monitorOk = true;
  bool _cablesOk = true;
  bool _systemUnitOk = true;

  bool _loading = true;
  bool _submitting = false;
  bool _loadingAi = false;

  String? _pcCode;
  String? _lab;
  String? _pcLabel;

  AiHelperResult? _aiResult;
  bool _showAiSuggestion = false;
  bool _aiTriedFix = false;
  bool? _aiSolved;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadPageData();

    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _commentCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    await _loadLoggedInUser();
    await _loadPcData();

    if (mounted) {
      setState(() => _loading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        _nameCtrl.text = (widget.initialStudentName ?? 'Student').trim();
        _emailCtrl.text = (widget.initialStudentEmail ?? '').trim();
        return;
      }

      final payload = JWTService.verifyToken(token);

      if (payload == null) {
        _nameCtrl.text = (widget.initialStudentName ?? 'Student').trim();
        _emailCtrl.text = (widget.initialStudentEmail ?? '').trim();
        return;
      }

      final String uid = (payload['uid'] ?? '').toString();
      final String tokenName =
      (payload['full_name'] ?? payload['name'] ?? 'Student').toString();
      final String tokenEmail = (payload['email'] ?? '').toString();

      if (uid.isNotEmpty) {
        final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          _nameCtrl.text =
              (data['full_name'] ?? data['name'] ?? tokenName).toString().trim();
          _emailCtrl.text = (data['email'] ?? tokenEmail).toString().trim();
          return;
        }
      }

      _nameCtrl.text = tokenName.trim();
      _emailCtrl.text = tokenEmail.trim();
    } catch (_) {
      _nameCtrl.text = (widget.initialStudentName ?? 'Student').trim();
      _emailCtrl.text = (widget.initialStudentEmail ?? '').trim();
    }
  }

  Future<void> _loadPcData() async {
    try {
      String? code = widget.pcCode;

      if (code == null || code.isEmpty) {
        final uri = Uri.base;
        code = uri.queryParameters['code'];
      }

      if (code == null || code.isEmpty) return;

      final doc =
      await FirebaseFirestore.instance.collection('pcs').doc(code).get();

      _pcCode = code;

      if (!doc.exists) {
        return;
      }

      final data = doc.data()!;
      _lab = (data['lab'] ?? '').toString();
      _pcLabel = (data['pc'] ?? '').toString();
    } catch (_) {}
  }

  List<String> _getProblemList() {
    final problems = <String>[];

    if (!_keyboardOk) problems.add('keyboard');
    if (!_mouseOk) problems.add('mouse');
    if (!_monitorOk) problems.add('monitor');
    if (!_cablesOk) problems.add('cables');
    if (!_systemUnitOk) problems.add('system unit');

    if (problems.isEmpty &&
        _aiResult != null &&
        _aiResult!.category.trim().isNotEmpty) {
      problems.add(_aiResult!.category.trim().toLowerCase());
    }

    return problems;
  }

  String _problemSentence() {
    final problems = _getProblemList();

    if (problems.isEmpty) return 'workstation';
    if (problems.length == 1) return problems.first;
    if (problems.length == 2) return '${problems[0]} and ${problems[1]}';

    return '${problems.sublist(0, problems.length - 1).join(', ')}, and ${problems.last}';
  }

  String _capitalize(String value) {
    if (value.trim().isEmpty) return value;
    final text = value.trim();
    return text[0].toUpperCase() + text.substring(1);
  }

  String _normalizeTipToAttempt(String text) {
    String cleaned = text.trim();

    if (cleaned.isEmpty) {
      return 'basic troubleshooting';
    }

    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    final lower = cleaned.toLowerCase();

    if (lower.startsWith('have you tried ')) {
      cleaned = cleaned.substring(15).trim();
    } else if (lower.startsWith('try ')) {
      cleaned = cleaned.substring(4).trim();
    } else if (lower.startsWith('please try ')) {
      cleaned = cleaned.substring(11).trim();
    }

    if (cleaned.isEmpty) {
      return 'basic troubleshooting';
    }

    return cleaned;
  }

  String _buildMascotMessage(AiHelperResult result) {
    final problem = _problemSentence();
    final attempt = _normalizeTipToAttempt(result.studentTip);

    return 'It seems like you have a problem with the $problem. '
        'Have you tried $attempt?';
  }

  String _buildFinalIncidentNarrative({
    required String originalComment,
    required AiHelperResult aiResult,
    required bool solved,
  }) {
    final problem = _problemSentence();
    final attempt = _normalizeTipToAttempt(aiResult.studentTip);
    final cleanComment = originalComment.trim();

    if (solved) {
      return 'This PC had a problem with the $problem. '
          'The student tried $attempt and confirmed that the issue was fixed.';
    }

    if (cleanComment.isNotEmpty) {
      return 'This PC has a problem with the $problem. '
          'The student reported: "$cleanComment". '
          'The student tried $attempt, but the issue still persists.';
    }

    return 'This PC has a problem with the $problem and the student has tried '
        '$attempt, but the problem still persists.';
  }

  String _buildFallbackNarrative(String originalComment) {
    final problem = _problemSentence();
    final cleanComment = originalComment.trim();

    if (cleanComment.isEmpty) {
      return 'This PC has a problem with the $problem.';
    }

    return 'This PC has a problem with the $problem. '
        'Student description: "$cleanComment".';
  }

  Future<void> _openAiHelper() async {
    if (_pcCode == null || _pcCode!.isEmpty || _lab == null || _pcLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing PC information.')),
      );
      return;
    }

    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue first.')),
      );
      return;
    }

    setState(() {
      _loadingAi = true;
      _showAiSuggestion = false;
      _aiResult = null;
      _aiTriedFix = false;
      _aiSolved = null;
    });

    final result = await AiHelperService.generate(
      pcCode: _pcCode!,
      lab: _lab!,
      pc: _pcLabel!,
      comment: _commentCtrl.text.trim(),
      peripherals: {
        'mouse': _mouseOk,
        'keyboard': _keyboardOk,
        'monitor': _monitorOk,
        'cables': _cablesOk,
        'system_unit': _systemUnitOk,
      },
    );

    if (!mounted) return;

    setState(() {
      _loadingAi = false;
      _aiResult = result;
      _showAiSuggestion = result != null;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mascot helper failed. Check logs.')),
      );
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pcCode == null || _pcCode!.isEmpty) return;

    setState(() => _submitting = true);

    final studentName = _nameCtrl.text.trim();
    final studentEmail = _emailCtrl.text.trim().toLowerCase();

    final peripherals = {
      'mouse': _mouseOk,
      'keyboard': _keyboardOk,
      'monitor': _monitorOk,
      'cables': _cablesOk,
      'system_unit': _systemUnitOk,
    };

    bool hasProblem = peripherals.values.any((e) => e == false);

    if (_aiSolved == true) {
      hasProblem = false;
    }

    final bool reportHealthy = _aiSolved == true;
    final bool sendToItso = _aiSolved != true;

    final String finalNarrative = _aiResult == null
        ? _buildFallbackNarrative(_commentCtrl.text.trim())
        : _buildFinalIncidentNarrative(
      originalComment: _commentCtrl.text.trim(),
      aiResult: _aiResult!,
      solved: _aiSolved == true,
    );

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'pc_code': _pcCode,
        'lab': _lab ?? '',
        'pc': _pcLabel ?? '',
        'student_name': studentName,
        'student_email': studentEmail,
        'reported_by': studentName,
        'reported_by_name': studentName,
        'reported_by_email': studentEmail,
        'comment': _commentCtrl.text.trim(),
        'final_report_text': finalNarrative,
        'peripherals': peripherals,
        'timestamp': FieldValue.serverTimestamp(),
        'status': reportHealthy ? 'healthy' : 'pending',
        'report_route': reportHealthy ? 'healthy' : 'itso',
        'ai_category': _aiResult?.category ?? '',
        'ai_priority': _aiResult?.priority ?? '',
        'ai_student_tip': _aiResult?.studentTip ?? '',
        'ai_action_done_template': _aiResult?.actionDoneTemplate ?? '',
        'ai_escalate_to_itso': _aiResult?.escalateToItso ?? sendToItso,
        'ai_itso_action': _aiResult?.itsoAction ?? '',
        'ai_attempted_fix': _showAiSuggestion,
        'ai_resolved': _aiSolved == true,
        'ai_attempt_summary': finalNarrative,
      });

      await FirebaseFirestore.instance.collection('attendance').add({
        'student_name': studentName,
        'student_email': studentEmail,
        'lab': _lab ?? '',
        'pc': _pcLabel ?? '',
        'present': 1.0,
        'late': 0.0,
        'attendance_score': 1.0,
        'date': DateTime.now().toString().split(' ')[0],
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('pcs').doc(_pcCode).update({
        'status': hasProblem ? 'problem' : 'available',
        'comment': _commentCtrl.text.trim(),
        'final_report_text': finalNarrative,
        'reported_by': studentName,
        'reported_by_name': studentName,
        'reported_by_email': studentEmail,
        'updated_at': FieldValue.serverTimestamp(),
        'peripherals': peripherals,
        'ai_category': _aiResult?.category ?? '',
        'ai_priority': _aiResult?.priority ?? '',
        'ai_student_tip': _aiResult?.studentTip ?? '',
        'ai_escalate_to_itso': _aiResult?.escalateToItso ?? sendToItso,
        'ai_itso_action': _aiResult?.itsoAction ?? '',
        'ai_attempted_fix': _showAiSuggestion,
        'ai_resolved': _aiSolved == true,
        'ai_attempt_summary': finalNarrative,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reportHealthy
                ? 'Problem fixed. Report saved as healthy.'
                : 'Problem submitted to ITSO.',
          ),
          backgroundColor:
          reportHealthy ? const Color(0xFF3B6D11) : _nuDarkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      _commentCtrl.clear();

      setState(() {
        _mouseOk = true;
        _keyboardOk = true;
        _monitorOk = true;
        _cablesOk = true;
        _systemUnitOk = true;
        _aiResult = null;
        _showAiSuggestion = false;
        _aiTriedFix = false;
        _aiSolved = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: _nuDarkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F8),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_pcCode == null || _pcCode!.isEmpty) {
      return _ErrorScaffold(
        message: 'Invalid QR code or unique code.',
        onBack: () => Navigator.pop(context),
      );
    }

    if (_lab == null || _pcLabel == null) {
      return _ErrorScaffold(
        message: 'PC not found for code:\n$_pcCode',
        onBack: () => Navigator.pop(context),
      );
    }

    final allOk =
        _mouseOk && _keyboardOk && _monitorOk && _cablesOk && _systemUnitOk;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        title: const Text(
          'PC REPORT',
          style: TextStyle(color: _nuWhite, fontWeight: FontWeight.w800),
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
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _nuDarkBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_lab · $_pcLabel',
                              style: const TextStyle(
                                color: _nuWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _pcCode!,
                              style: TextStyle(
                                color: _nuGold.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              allOk ? 'All OK' : 'Issues detected',
                              style: TextStyle(
                                color: allOk
                                    ? const Color(0xFF9FE1CB)
                                    : const Color(0xFFFCA5A5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FormPanel(
                        title: 'Student Information',
                        child: Column(
                          children: [
                            _ReadOnlyField(
                              label: 'FULL NAME',
                              controller: _nameCtrl,
                            ),
                            const SizedBox(height: 12),
                            _ReadOnlyField(
                              label: 'STUDENT EMAIL',
                              controller: _emailCtrl,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FormPanel(
                        title: 'Peripheral Status',
                        child: Column(
                          children: [
                            _PeripheralTile(
                              label: 'Mouse',
                              value: _mouseOk,
                              onChanged: (v) =>
                                  setState(() => _mouseOk = v ?? true),
                            ),
                            _PeripheralTile(
                              label: 'Keyboard',
                              value: _keyboardOk,
                              onChanged: (v) =>
                                  setState(() => _keyboardOk = v ?? true),
                            ),
                            _PeripheralTile(
                              label: 'Monitor',
                              value: _monitorOk,
                              onChanged: (v) =>
                                  setState(() => _monitorOk = v ?? true),
                            ),
                            _PeripheralTile(
                              label: 'Cables',
                              value: _cablesOk,
                              onChanged: (v) =>
                                  setState(() => _cablesOk = v ?? true),
                            ),
                            _PeripheralTile(
                              label: 'System Unit',
                              value: _systemUnitOk,
                              onChanged: (v) =>
                                  setState(() => _systemUnitOk = v ?? true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FormPanel(
                        title: 'Comment / Issue',
                        child: TextFormField(
                          controller: _commentCtrl,
                          maxLines: 4,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Please describe the issue first.';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText:
                            'Example: The keyboard is not responding even after reconnecting it.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loadingAi ? null : _openAiHelper,
                          icon: _loadingAi
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.smart_toy_outlined),
                          label: Text(
                            _loadingAi
                                ? 'Opening Lab Buddy...'
                                : 'Ask Lab Buddy',
                          ),
                        ),
                      ),
                      if (_showAiSuggestion && _aiResult != null) ...[
                        const SizedBox(height: 16),
                        _MascotHelperCard(
                          mascotName: 'Lab Buddy',
                          issueType: _capitalize(_problemSentence()),
                          priority: _aiResult!.priority,
                          message: _buildMascotMessage(_aiResult!),
                          tip: _aiResult!.studentTip,
                          solved: _aiSolved,
                          onSolved: () {
                            setState(() {
                              _aiTriedFix = true;
                              _aiSolved = true;
                            });
                          },
                          onNotSolved: () {
                            setState(() {
                              _aiTriedFix = true;
                              _aiSolved = false;
                            });
                          },
                        ),
                        if (_aiTriedFix && _aiSolved == false) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD58A),
                              ),
                            ),
                            child: Text(
                              _buildFinalIncidentNarrative(
                                originalComment: _commentCtrl.text.trim(),
                                aiResult: _aiResult!,
                                solved: false,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submitReport,
                          icon: _submitting
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: _nuGold,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _submitting ? 'Submitting...' : 'Submit Report',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _nuDarkBlue,
                            foregroundColor: _nuGold,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
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
    );
  }
}

class _MascotHelperCard extends StatelessWidget {
  final String mascotName;
  final String issueType;
  final String priority;
  final String message;
  final String tip;
  final bool? solved;
  final VoidCallback onSolved;
  final VoidCallback onNotSolved;

  const _MascotHelperCard({
    required this.mascotName,
    required this.issueType,
    required this.priority,
    required this.message,
    required this.tip,
    required this.solved,
    required this.onSolved,
    required this.onNotSolved,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = priority.toLowerCase() == 'high'
        ? const Color(0xFFE24B4A)
        : priority.toLowerCase() == 'medium'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF3B82F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3BF),
                  shape: BoxShape.circle,
                  border: Border.all(color: _nuGold, width: 2),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: _nuDarkBlue,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD9E2FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            mascotName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _nuDarkBlue,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Priority: $priority',
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Detected issue: $issueType',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Suggested step: $tip',
                        style: const TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Were you able to solve it?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onSolved,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B6D11),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('YES, SOLVED'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNotSolved,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE24B4A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('NO, STILL NOT SOLVED'),
                ),
              ),
            ],
          ),
          if (solved != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                solved == true
                    ? 'Great. The issue will be saved as resolved.'
                    : 'The issue will be forwarded to ITSO with your attempted fix.',
                style: TextStyle(
                  color: solved == true
                      ? const Color(0xFF3B6D11)
                      : const Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormPanel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _nuDarkBlue,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _ReadOnlyField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _PeripheralTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _PeripheralTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
      subtitle: Text(value ? 'Working fine' : 'Has a problem'),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorScaffold({
    required this.message,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        title: const Text('PC REPORT', style: TextStyle(color: _nuWhite)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onBack,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}