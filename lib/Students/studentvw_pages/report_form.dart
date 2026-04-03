import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login/services/jwt_service.dart';

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

class _StudentReportFormPageState extends State<StudentReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();

  bool _mouseOk = true;
  bool _keyboardOk = true;
  bool _monitorOk = true;
  bool _cablesOk = true;
  bool _systemUnitOk = true;

  bool _loading = true;
  bool _submitting = false;

  String? _pcCode;
  String? _lab;
  String? _pcLabel;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    await _loadLoggedInUser();
    await _loadPcData();

    if (mounted) {
      setState(() {
        _loading = false;
      });
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
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() ?? {};

          _nameCtrl.text =
              (data['full_name'] ?? data['name'] ?? tokenName).toString().trim();

          _emailCtrl.text =
              (data['email'] ?? tokenEmail).toString().trim();
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

      if (code == null || code.isEmpty) {
        return;
      }

      final doc =
      await FirebaseFirestore.instance.collection('pcs').doc(code).get();

      if (!doc.exists) {
        _pcCode = code;
        return;
      }

      final data = doc.data()!;
      _pcCode = code;
      _lab = (data['lab'] ?? '').toString();
      _pcLabel = (data['pc'] ?? '').toString();
    } catch (_) {}
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

    final hasProblem = peripherals.values.any((e) => e == false);

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
        'peripherals': peripherals,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
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
        'reported_by': studentName,
        'reported_by_name': studentName,
        'reported_by_email': studentEmail,
        'updated_at': FieldValue.serverTimestamp(),
        'peripherals': peripherals,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      _commentCtrl.clear();

      setState(() {
        _mouseOk = true;
        _keyboardOk = true;
        _monitorOk = true;
        _cablesOk = true;
        _systemUnitOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _statusCheckbox({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: Text(title),
        subtitle: Text(value ? 'OK' : 'Problem'),
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pcCode == null || _pcCode!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Invalid QR code or unique code')),
      );
    }

    if (_lab == null || _pcLabel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Report')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('PC not found for code: $_pcCode'),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Report'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          'Lab: $_lab',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pcLabel!,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'Code: $_pcCode',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Student Email',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Check peripherals',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _statusCheckbox(
                          title: 'Mouse',
                          value: _mouseOk,
                          onChanged: (value) {
                            setState(() => _mouseOk = value ?? true);
                          },
                        ),
                        _statusCheckbox(
                          title: 'Keyboard',
                          value: _keyboardOk,
                          onChanged: (value) {
                            setState(() => _keyboardOk = value ?? true);
                          },
                        ),
                        _statusCheckbox(
                          title: 'Monitor',
                          value: _monitorOk,
                          onChanged: (value) {
                            setState(() => _monitorOk = value ?? true);
                          },
                        ),
                        _statusCheckbox(
                          title: 'Cables',
                          value: _cablesOk,
                          onChanged: (value) {
                            setState(() => _cablesOk = value ?? true);
                          },
                        ),
                        _statusCheckbox(
                          title: 'System Unit',
                          value: _systemUnitOk,
                          onChanged: (value) {
                            setState(() => _systemUnitOk = value ?? true);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _commentCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Comment / Issue',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submitReport,
                            child: Text(
                              _submitting ? 'Submitting...' : 'Submit Report',
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
      ),
    );
  }
}