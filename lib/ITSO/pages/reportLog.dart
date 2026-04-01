import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

class ReportLogPage extends StatefulWidget {
  const ReportLogPage({super.key});

  @override
  State<ReportLogPage> createState() => _ReportLogPageState();
}

class _ReportLogPageState extends State<ReportLogPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      final hour = d.hour == 0
          ? 12
          : d.hour > 12
          ? d.hour - 12
          : d.hour;
      final minute = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '${d.month}/${d.day}/${d.year} $hour:$minute $ampm';
    }
    return 'No date';
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();

    final values = [
      (data['lab'] ?? '').toString(),
      (data['pc'] ?? '').toString(),
      (data['pc_code'] ?? '').toString(),
      (data['comment'] ?? '').toString(),
      (data['status'] ?? '').toString(),
      (data['reported_by'] ?? '').toString(),
      (data['repaired_by'] ?? '').toString(),
      (data['action_taken'] ?? '').toString(),
    ];

    return values.any((v) => v.toLowerCase().contains(q));
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    if (_statusFilter == 'all') return true;
    return (data['status'] ?? '').toString().toLowerCase() == _statusFilter;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': newStatus,
      if (newStatus == 'resolved') 'resolved_at': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report marked as $newStatus')),
    );
  }

  void _showDetails(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'unknown').toString();
    final lab = (data['lab'] ?? '').toString();
    final pc = (data['pc'] ?? '').toString();
    final code = (data['pc_code'] ?? '').toString();
    final comment = (data['comment'] ?? '').toString();
    final reportedBy = (data['reported_by'] ?? 'Unknown').toString();
    final repairedBy = (data['repaired_by'] ?? 'Not recorded').toString();
    final actionTaken = (data['action_taken'] ?? 'No action recorded').toString();
    final timestamp = _formatDate(data['timestamp']);
    final resolvedAt = _formatDate(data['resolved_at']);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Report Details'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Lab', lab),
                  _detailRow('PC', pc),
                  _detailRow('Unique Code', code),
                  _detailRow('Status', status),
                  _detailRow('Reported By', reportedBy),
                  _detailRow('Repaired By', repairedBy),
                  _detailRow('Date Reported', timestamp),
                  _detailRow('Date Resolved', resolvedAt),
                  const SizedBox(height: 10),
                  const Text(
                    'Issue / Comment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(comment.isEmpty ? 'No comment' : comment),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Action Taken',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(actionTaken),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (status.toLowerCase() != 'pending')
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateStatus(docId, 'pending');
                },
                child: const Text('Mark Pending'),
              ),
            if (status.toLowerCase() != 'resolved')
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateStatus(docId, 'resolved');
                },
                child: const Text('Mark Resolved'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value.isEmpty ? '-' : value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        backgroundColor: color.primary,
        title: const Text(
          'Report Log',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search lab, pc, code, comment...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value ?? 'all';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('reports').snapshots(),
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

                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    return _matchesSearch(data, _searchCtrl.text) &&
                        _matchesStatus(data);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No reports found.'),
                    );
                  }

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            border: Border(
                              bottom: BorderSide(color: Colors.black12),
                            ),
                          ),
                          child: const Row(
                            children: [
                              _HeaderCell(flex: 1, text: 'Lab'),
                              _HeaderCell(flex: 1, text: 'PC'),
                              _HeaderCell(flex: 2, text: 'Unique Code'),
                              _HeaderCell(flex: 3, text: 'Issue'),
                              _HeaderCell(flex: 1, text: 'Status'),
                              _HeaderCell(flex: 2, text: 'Date Reported'),
                              _HeaderCell(flex: 2, text: 'Actions'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();

                              final lab = (data['lab'] ?? '').toString();
                              final pc = (data['pc'] ?? '').toString();
                              final code = (data['pc_code'] ?? '').toString();
                              final comment = (data['comment'] ?? '').toString();
                              final status = (data['status'] ?? 'unknown').toString();
                              final timestamp = _formatDate(data['timestamp']);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    _BodyCell(flex: 1, text: lab),
                                    _BodyCell(flex: 1, text: pc),
                                    _BodyCell(flex: 2, text: code),
                                    _BodyCell(
                                      flex: 3,
                                      text: comment.isEmpty ? 'No comment' : comment,
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    _BodyCell(flex: 2, text: timestamp),
                                    Expanded(
                                      flex: 2,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => _showDetails(
                                              context,
                                              doc.id,
                                              data,
                                            ),
                                            child: const Text('View'),
                                          ),
                                          if (status.toLowerCase() != 'resolved')
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _updateStatus(doc.id, 'resolved'),
                                              child: const Text('Resolve'),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

class _HeaderCell extends StatelessWidget {
  final int flex;
  final String text;

  const _HeaderCell({
    required this.flex,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final int flex;
  final String text;

  const _BodyCell({
    required this.flex,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}