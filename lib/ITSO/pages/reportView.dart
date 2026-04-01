import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Future<void> _markResolved(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('pcs').doc(docId).update({
        'peripherals': {
          'Keyboard': true,
          'Mouse': true,
          'Monitor': true,
          'Cables': true,
          'System Unit': true,
        },
        'comment': '',
        'updated_at': FieldValue.serverTimestamp(),
      });

      final pendingReports = await FirebaseFirestore.instance
          .collection('reports')
          .where('pc_code', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingReports.docs) {
        await doc.reference.update({
          'status': 'resolved',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PC problem marked as resolved.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark resolved: $e')),
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

  void _openPcHistory(BuildContext context) {
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
        title: const Text(
          'ITSO View',
          style: TextStyle(color: Colors.white),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: ColoredBox(color: Colors.amber),
          ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
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
                        Container(
                          width: 60,
                          height: 60,
                          color: Colors.white,
                        ),
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
                          Text(
                            'Reported by: ${reportedBy.isEmpty ? "Unknown" : reportedBy}',
                          ),
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
                                  onPressed: () => _openPcHistory(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('View Pc History'),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => _markResolved(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Mark Resolved'),
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
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _locationCtrl.dispose();
    _narrativeCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveIncidentReport() async {
    if (_saving) return;

    if (_typeCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _narrativeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the incident report fields.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final reportRef = await FirebaseFirestore.instance.collection('incident_reports').add({
        'pc_doc_id': widget.docId,
        'pc_code': widget.code,
        'lab': widget.lab,
        'pc': widget.pcLabel,
        'reported_by': widget.reportedBy,
        'type_of_incident': _typeCtrl.text.trim(),
        'exact_location': _locationCtrl.text.trim(),
        'narrative_details': _narrativeCtrl.text.trim(),
        'action_taken': _actionCtrl.text.trim(),
        'peripherals': widget.status,
        'created_at': FieldValue.serverTimestamp(),
        'source': 'itso',
      });

      final pendingReports = await FirebaseFirestore.instance
          .collection('reports')
          .where('pc_code', isEqualTo: widget.code)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingReports.docs) {
        await doc.reference.update({
          'action_taken': _actionCtrl.text.trim(),
          'repaired_by': widget.reportedBy,
          'incident_report_id': reportRef.id,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

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
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
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
        title: const Text(
          'ITSO View',
          style: TextStyle(color: Colors.white),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: ColoredBox(color: Colors.amber),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
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
                        const Text('Exact Location Of Incident:', style: TextStyle(fontSize: 12)),
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
                        const Text('Narrative Details Of Incident:', style: TextStyle(fontSize: 12)),
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