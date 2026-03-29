import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentReportFormPage extends StatefulWidget {
  const StudentReportFormPage({super.key});

  @override
  State<StudentReportFormPage> createState() => _StudentReportFormPageState();
}

class _StudentReportFormPageState extends State<StudentReportFormPage> {
  final _formKey = GlobalKey<FormState>();
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
    _loadPcFromUrl();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPcFromUrl() async {
    try {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];

      if (code == null || code.isEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('pcs')
          .doc(code)
          .get();

      if (!doc.exists) {
        setState(() {
          _pcCode = code;
          _loading = false;
        });
        return;
      }

      final data = doc.data()!;

      setState(() {
        _pcCode = code;
        _lab = (data['lab'] ?? '').toString();
        _pcLabel = (data['pc'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pcCode == null || _pcCode!.isEmpty) return;

    setState(() {
      _submitting = true;
    });

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
        'student_email': _emailCtrl.text.trim(),
        'comment': _commentCtrl.text.trim(),
        'peripherals': peripherals,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      await FirebaseFirestore.instance.collection('pcs').doc(_pcCode).update({
        'status': hasProblem ? 'problem' : 'available',
        'comment': _commentCtrl.text.trim(),
        'reported_by': _emailCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        'peripherals': peripherals,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      setState(() {
        _mouseOk = true;
        _keyboardOk = true;
        _monitorOk = true;
        _cablesOk = true;
        _systemUnitOk = true;
      });
      _commentCtrl.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _statusSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(value ? 'OK' : 'Problem'),
      value: value,
      onChanged: onChanged,
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
        body: Center(
          child: Text('Invalid QR code'),
        ),
      );
    }

    if (_lab == null || _pcLabel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Report')),
        body: Center(
          child: Text('PC not found for code: $_pcCode'),
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
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Student Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Enter your email';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _statusSwitch(
                          title: 'Mouse OK',
                          value: _mouseOk,
                          onChanged: (v) => setState(() => _mouseOk = v),
                        ),
                        _statusSwitch(
                          title: 'Keyboard OK',
                          value: _keyboardOk,
                          onChanged: (v) => setState(() => _keyboardOk = v),
                        ),
                        _statusSwitch(
                          title: 'Monitor OK',
                          value: _monitorOk,
                          onChanged: (v) => setState(() => _monitorOk = v),
                        ),
                        _statusSwitch(
                          title: 'Cables OK',
                          value: _cablesOk,
                          onChanged: (v) => setState(() => _cablesOk = v),
                        ),
                        _statusSwitch(
                          title: 'System Unit OK',
                          value: _systemUnitOk,
                          onChanged: (v) => setState(() => _systemUnitOk = v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _commentCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Comments / Problem Description',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final hasProblem = [
                              _mouseOk,
                              _keyboardOk,
                              _monitorOk,
                              _cablesOk,
                              _systemUnitOk,
                            ].any((e) => e == false);

                            if (hasProblem && (value?.trim().isEmpty ?? true)) {
                              return 'Please describe the problem';
                            }
                            return null;
                          },
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