import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  Future<void> exportToExcel(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Attendance'];

      sheet.appendRow([
        'Email',
        'Present',
        'Late',
        'Attendance Score',
      ]);

      for (final doc in docs) {
        final data = doc.data();

        sheet.appendRow([
          data['student_email'] ?? '',
          data['present'] ?? 0,
          data['late'] ?? 0,
          data['attendance_score'] ?? 0,
        ]);
      }

      final directory = Directory.systemTemp;
      final path = "${directory.path}/attendance.xlsx";

      final bytes = excel.encode();
      if (bytes == null) return;

      final file = File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Excel exported: ${file.path}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  void showAttendanceDates(
      BuildContext context,
      String email,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final userDocs = docs
        .where((doc) => doc.data()['student_email'] == email)
        .toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(email),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: userDocs.length,
            itemBuilder: (_, index) {
              final data = userDocs[index].data();

              return ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(data['date'] ?? 'No date'),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<String, Map<String, dynamic>> groupAttendanceByEmail(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final doc in docs) {
      final data = doc.data();
      final email = data['student_email'] ?? '';

      if (!grouped.containsKey(email)) {
        grouped[email] = {
          'present': 0.0,
          'late': 0.0,
        };
      }

      grouped[email]!['present'] +=
          (data['present'] as num?)?.toDouble() ?? 0;
      grouped[email]!['late'] +=
          (data['late'] as num?)?.toDouble() ?? 0;
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E5A97),
        title: const Text(
          "Attendance",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;
          final grouped = groupAttendanceByEmail(docs);
          final emails = grouped.keys.toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4EACF),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => exportToExcel(docs),
                    icon: const Icon(Icons.download),
                    label: const Text("Export Excel"),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Present')),
                        DataColumn(label: Text('Late')),
                        DataColumn(label: Text('Attendance Score')),
                        DataColumn(label: Text('Details')),
                      ],
                      rows: emails.map((email) {
                        final present =
                        grouped[email]!['present'] as double;
                        final late =
                        grouped[email]!['late'] as double;
                        final score = present + late;

                        return DataRow(
                          cells: [
                            DataCell(Text(email)),
                            DataCell(Text(present.toString())),
                            DataCell(Text(late.toString())),
                            DataCell(Text(score.toString())),
                            DataCell(
                              ElevatedButton(
                                onPressed: () {
                                  showAttendanceDates(
                                    context,
                                    email,
                                    docs,
                                  );
                                },
                                child: const Text("Details"),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}