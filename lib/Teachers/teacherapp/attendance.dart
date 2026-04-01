import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final List<Map<String, dynamic>> attendanceData = [
    {
      "name": "examplename1",
      "present": 1,
      "late": 0,
      "absent": 0,
      "score": 1,
    },
    {
      "name": "examplename2",
      "present": 0,
      "late": 0.5,
      "absent": 0,
      "score": 0.5,
    },
    {
      "name": "examplename3",
      "present": 0,
      "late": 0,
      "absent": -1,
      "score": 0,
    },
  ];

  Future<void> exportToExcel() async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Attendance'];

      sheet.appendRow([
        "Name",
        "Present",
        "Late",
        "Absent",
        "Attendance Score",
      ]);

      for (final row in attendanceData) {
        sheet.appendRow([
          row["name"],
          row["present"],
          row["late"],
          row["absent"],
          row["score"],
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/attendance.xlsx";

      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception("Failed to generate excel file");
      }

      final file = File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Excel exported successfully:\n${file.path}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Export failed: $e"),
        ),
      );
    }
  }

  Widget buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget buildDataCell(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  TableRow buildTableRow(Map<String, dynamic> row) {
    return TableRow(
      children: [
        buildDataCell(row["name"].toString()),
        buildDataCell(row["present"].toString()),
        buildDataCell(row["late"].toString()),
        buildDataCell(row["absent"].toString()),
        buildDataCell(row["score"].toString()),
      ],
    );
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4EACF),
                foregroundColor: Colors.black,
              ),
              onPressed: exportToExcel,
              icon: const Icon(Icons.download),
              label: const Text("Export Excel"),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            color: Colors.white,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(220),
              border: TableBorder.all(color: Colors.black12),
              children: [
                TableRow(
                  children: [
                    buildHeaderCell("Name"),
                    buildHeaderCell("Present"),
                    buildHeaderCell("Late"),
                    buildHeaderCell("Absent"),
                    buildHeaderCell("Attendance Score"),
                  ],
                ),
                ...attendanceData.map(buildTableRow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}