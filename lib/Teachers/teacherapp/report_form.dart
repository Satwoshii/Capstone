import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherReportFormPage extends StatefulWidget {
  const TeacherReportFormPage({super.key});

  @override
  State<TeacherReportFormPage> createState() => _TeacherReportFormPageState();
}

class _TeacherReportFormPageState extends State<TeacherReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _commentCtrl = TextEditingController();

  bool _mouseOk = true;
  bool _keyboardOk = true;
  bool _monitorOk = true;
  bool _cablesOk = true;
  bool _systemUnitOk = true;

  bool _submitting = false;

  final List<String> _labs = ['706', '707', '708', '709', '710', '723'];
  final List<String> _pcs = List.generate(40, (index) => 'PC${index + 1}');

  String? _selectedLab;
  String? _selectedPc;

  String? _pcCode;
  String? _pcLabel;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPcDataFromSelection() async {
    if (_selectedLab == null || _selectedPc == null) {
      _pcCode = null;
      _pcLabel = null;
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('pcs')
        .where('lab', isEqualTo: _selectedLab)
        .where('pc', isEqualTo: _selectedPc)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      _pcCode = null;
      _pcLabel = _selectedPc;
      return;
    }

    final doc = query.docs.first;
    final data = doc.data();

    _pcCode = doc.id;
    _pcLabel = (data['pc'] ?? _selectedPc).toString();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLab == null || _selectedPc == null) return;

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
      await _loadPcDataFromSelection();

      if (_pcCode == null || _pcCode!.isEmpty) {
        throw Exception(
          'No matching PC found in Firestore for Lab $_selectedLab and $_selectedPc',
        );
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'pc_code': _pcCode,
        'lab': _selectedLab ?? '',
        'pc': _pcLabel ?? _selectedPc ?? '',
        'student_email': '',
        'comment': _commentCtrl.text.trim(),
        'peripherals': peripherals,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reporter_type': 'Teacher',
      });

      await FirebaseFirestore.instance.collection('pcs').doc(_pcCode).update({
        'status': hasProblem ? 'problem' : 'available',
        'comment': _commentCtrl.text.trim(),
        'reported_by': 'Teacher',
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
        _selectedLab = null;
        _selectedPc = null;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Report'),
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
                        const Text(
                          'Teacher Report Form',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedLab,
                          decoration: const InputDecoration(
                            labelText: 'Laboratory Room',
                            border: OutlineInputBorder(),
                          ),
                          items: _labs.map((lab) {
                            return DropdownMenuItem<String>(
                              value: lab,
                              child: Text('Lab $lab'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLab = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a laboratory room';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedPc,
                          decoration: const InputDecoration(
                            labelText: 'PC Number',
                            border: OutlineInputBorder(),
                          ),
                          items: _pcs.map((pc) {
                            return DropdownMenuItem<String>(
                              value: pc,
                              child: Text(pc),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPc = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a PC number';
                            }
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