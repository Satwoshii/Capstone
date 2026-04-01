import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../widgets/itso_drawer.dart';
import 'pc_history.dart';

class ReportViewPage extends StatelessWidget {
  final String docId;
  final String lab;
  final String pcLabel;
  final String code;
  final Map<String, bool> status;
  final String comment;
  final String reportedBy;

  const ReportViewPage({
    super.key,
    required this.docId,
    required this.lab,
    required this.pcLabel,
    required this.code,
    required this.status,
    required this.comment,
    required this.reportedBy,
  });

  Future<void> _deletePcCompletely(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete PC'),
        content: Text(
          'Delete $pcLabel in room $lab?\n\nThis will also remove related reports and incident reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance.collection('pcs').doc(docId).delete();

      final reportsSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('pc_code', isEqualTo: code)
          .get();

      for (final doc in reportsSnap.docs) {
        await doc.reference.delete();
      }

      final incidentSnap = await FirebaseFirestore.instance
          .collection('incident_reports')
          .where('pc_code', isEqualTo: code)
          .get();

      for (final doc in incidentSnap.docs) {
        await doc.reference.delete();
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$pcLabel deleted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete PC: $e')),
      );
    }
  }

  void _openIncidentReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentReportPage(
          docId: docId,
          lab: lab,
          pcLabel: pcLabel,
          code: code,
          status: status,
          existingComment: comment,
          reportedBy: reportedBy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      key: scaffoldKey,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        backgroundColor: color.primary,
        title: const Text('ITSO View', style: TextStyle(color: Colors.white)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lab: $lab',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(pcLabel),
                        const SizedBox(height: 12),
                        Container(width: 60, height: 60, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    width: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: status.entries.map((entry) {
                        final ok = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: ok ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  ok ? 'Ok' : 'No',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Comments:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(comment.isEmpty ? 'No comment' : comment),
                          const SizedBox(height: 12),
                          Text('Reported by: ${reportedBy.isEmpty ? "Unknown" : reportedBy}'),
                          const SizedBox(height: 12),
                          Text('PC Code: $code'),
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _openIncidentReport(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Make Incident Report'),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PcHistoryPage(
                                          lab: lab,
                                          pcLabel: pcLabel,
                                          code: code,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('View PC History'),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => _deletePcCompletely(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete PC'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncidentReportPage extends StatefulWidget {
  final String docId;
  final String lab;
  final String pcLabel;
  final String code;
  final Map<String, bool> status;
  final String existingComment;
  final String reportedBy;

  const IncidentReportPage({
    super.key,
    required this.docId,
    required this.lab,
    required this.pcLabel,
    required this.code,
    required this.status,
    required this.existingComment,
    required this.reportedBy,
  });

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final _typeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _narrativeCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _repairedByCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final broken = widget.status.entries
        .where((entry) => entry.value == false)
        .map((entry) => entry.key)
        .toList();

    _typeCtrl.text = broken.isEmpty ? 'General concern' : broken.join(', ');
    _locationCtrl.text = '${widget.lab} - ${widget.pcLabel}';
    _narrativeCtrl.text = widget.existingComment.isEmpty
        ? 'Reported issue on ${widget.pcLabel}.'
        : widget.existingComment;
    _repairedByCtrl.text =
    widget.reportedBy.isEmpty ? 'ITSO Staff' : widget.reportedBy;
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _locationCtrl.dispose();
    _narrativeCtrl.dispose();
    _actionCtrl.dispose();
    _repairedByCtrl.dispose();
    super.dispose();
  }

  Future<void> _writeAuditLog({
    required String action,
    required String details,
  }) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': action,
      'details': details,
      'pc': widget.pcLabel,
      'pc_code': widget.code,
      'lab': widget.lab,
      'user': _repairedByCtrl.text.trim().isEmpty
          ? 'ITSO Staff'
          : _repairedByCtrl.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _printPdf({
    required String repairedBy,
    required String actionTaken,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: PdfColor.fromHex('#F4C400'),
                    child: pw.Text(
                      'Incident Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text('Type Of Incident: ${_typeCtrl.text.trim()}'),
                pw.SizedBox(height: 10),
                pw.Text('Exact Location Of Incident: ${_locationCtrl.text.trim()}'),
                pw.SizedBox(height: 10),
                pw.Text('Narrative Details Of Incident: ${_narrativeCtrl.text.trim()}'),
                pw.SizedBox(height: 10),
                pw.Text('Repaired By: $repairedBy'),
                pw.SizedBox(height: 10),
                pw.Text('Actions Taken: $actionTaken'),
                pw.SizedBox(height: 18),
                pw.Text('Lab: ${widget.lab}'),
                pw.Text('PC: ${widget.pcLabel}'),
                pw.Text('PC Code: ${widget.code}'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  Future<void> _saveIncidentReport() async {
    if (_saving) return;

    if (_typeCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _narrativeCtrl.text.trim().isEmpty ||
        _actionCtrl.text.trim().isEmpty ||
        _repairedByCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all incident report fields.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repairedBy = _repairedByCtrl.text.trim();
      final actionTaken = _actionCtrl.text.trim();

      final reportRef =
      await FirebaseFirestore.instance.collection('incident_reports').add({
        'pc_doc_id': widget.docId,
        'pc_code': widget.code,
        'lab': widget.lab,
        'pc': widget.pcLabel,
        'reported_by': widget.reportedBy,
        'repaired_by': repairedBy,
        'type_of_incident': _typeCtrl.text.trim(),
        'exact_location': _locationCtrl.text.trim(),
        'narrative_details': _narrativeCtrl.text.trim(),
        'action_taken': actionTaken,
        'peripherals': widget.status,
        'created_at': FieldValue.serverTimestamp(),
        'source': 'itso',
      });

      final matchedReports = await FirebaseFirestore.instance
          .collection('reports')
          .where('pc_code', isEqualTo: widget.code)
          .get();

      for (final doc in matchedReports.docs) {
        await doc.reference.update({
          'action_taken': actionTaken,
          'repaired_by': repairedBy,
          'status': 'resolved',
          'resolved_at': FieldValue.serverTimestamp(),
          'incident_report_id': reportRef.id,
        });
      }

      await FirebaseFirestore.instance.collection('pcs').doc(widget.docId).update({
        'peripherals': {
          'keyboard': true,
          'mouse': true,
          'monitor': true,
          'cables': true,
          'system_unit': true,
        },
        'comment': '',
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _writeAuditLog(
        action: 'Incident report created',
        details: 'Incident report saved and PC marked resolved.',
      );

      await _printPdf(
        repairedBy: repairedBy,
        actionTaken: actionTaken,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident report saved successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save incident report: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      key: scaffoldKey,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        backgroundColor: color.primary,
        title: const Text('ITSO View', style: TextStyle(color: Colors.white)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  color: Colors.amber,
                  child: const Text(
                    'Incident Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Type Of Incident:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _typeCtrl,
                  decoration: _fieldDecoration(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exact Location Of Incident:',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _locationCtrl,
                          decoration: _fieldDecoration(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Narrative Details Of Incident:',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _narrativeCtrl,
                          decoration: _fieldDecoration(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Repaired By:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _repairedByCtrl,
                  decoration: _fieldDecoration(),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Actions Taken:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _actionCtrl,
                  maxLines: 5,
                  decoration: _fieldDecoration(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _saveIncidentReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: Text(_saving ? 'Saving...' : 'Print report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}