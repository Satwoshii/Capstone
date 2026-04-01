import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

class PcHistoryPage extends StatelessWidget {
  final String lab;
  final String pcLabel;
  final String code;

  const PcHistoryPage({
    super.key,
    required this.lab,
    required this.pcLabel,
    required this.code,
  });

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }
    return 'No date';
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
          'Pc History',
          style: TextStyle(color: Colors.white),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                color: Colors.amber,
                child: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .where('pc_code', isEqualTo: code)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.toList();

                  docs.sort((a, b) {
                    final aTs = a.data()['timestamp'];
                    final bTs = b.data()['timestamp'];

                    final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(2000);
                    final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(2000);

                    return bDate.compareTo(aDate);
                  });

                  if (docs.isEmpty) {
                    return const Center(child: Text('No PC history records found.'));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date Reported')),
                        DataColumn(label: Text('Repaired By')),
                        DataColumn(label: Text('Reported Issue')),
                        DataColumn(label: Text('Action Taken')),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data();

                        final date = _formatDate(data['timestamp']);
                        final repairedBy = (data['repaired_by'] ?? 'Not recorded').toString();
                        final issue = (data['comment'] ?? 'No issue recorded').toString();
                        final action =
                        (data['action_taken'] ?? 'No action recorded').toString();

                        return DataRow(
                          cells: [
                            DataCell(Text(date)),
                            DataCell(SizedBox(width: 140, child: Text(repairedBy))),
                            DataCell(SizedBox(width: 200, child: Text(issue))),
                            DataCell(SizedBox(width: 260, child: Text(action))),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}