import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

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
    await FirebaseFirestore.instance.collection('pcs').doc(docId).update({
      'status': 'available',
      'comment': '',
      'reported_by': '',
      'updated_at': FieldValue.serverTimestamp(),
      'peripherals': {
        'keyboard': true,
        'mouse': true,
        'monitor': true,
        'cables': true,
        'system_unit': true,
      },
    });

    await FirebaseFirestore.instance
        .collection('reports')
        .where('pc_code', isEqualTo: code)
        .where('status', isEqualTo: 'pending')
        .get()
        .then((snapshot) async {
      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'status': 'resolved',
          'resolved_at': FieldValue.serverTimestamp(),
        });
      }
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PC marked as resolved')),
    );
    Navigator.pop(context);
  }

  Future<void> _makeIncidentReport(BuildContext context) async {
    await FirebaseFirestore.instance.collection('incident_reports').add({
      'pc_code': code,
      'lab': lab,
      'pc': pcLabel,
      'comment': comment,
      'reported_by': reportedBy,
      'peripherals': status,
      'created_at': FieldValue.serverTimestamp(),
      'source': 'itso',
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident report created')),
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
                      color: Colors.grey.shade300,
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
                    width: 220,
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
                                  onPressed: () => _makeIncidentReport(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Make Incident Report'),
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