import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final List<String> rooms = ['706', '707', '708', '709', '710', '723'];
  String selectedRoom = '706';

  String currentSubject = '';
  String currentSection = '';
  String currentTimeSlot = '';
  String currentDay = '';
  String currentStartTime = '';
  String currentEndTime = '';
  bool hasOngoingClass = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _scheduleSub;
  Timer? _clockRefreshTimer;

  @override
  void initState() {
    super.initState();
    loadCurrentSchedule();
    _listenToScheduleRealtime();

    _clockRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await loadCurrentSchedule();
    });
  }

  @override
  void dispose() {
    _scheduleSub?.cancel();
    _clockRefreshTimer?.cancel();
    super.dispose();
  }

  String getCurrentDayName() {
    final now = DateTime.now();

    switch (now.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  DateTime? parseTimeForToday(String value) {
    final now = DateTime.now();
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final match =
    RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$', caseSensitive: false)
        .firstMatch(normalized);

    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();

    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTimeRange? getCurrentClassRange() {
    if (!hasOngoingClass ||
        currentStartTime.isEmpty ||
        currentEndTime.isEmpty) {
      return null;
    }

    final start = parseTimeForToday(currentStartTime);
    final end = parseTimeForToday(currentEndTime);

    if (start == null || end == null) return null;

    return DateTimeRange(start: start, end: end);
  }

  void _listenToScheduleRealtime() {
    _scheduleSub?.cancel();

    final day = getCurrentDayName();
    if (day.isEmpty) return;

    _scheduleSub = FirebaseFirestore.instance
        .collection('schedules')
        .where('room', isEqualTo: selectedRoom)
        .where('day', isEqualTo: day)
        .snapshots()
        .listen((_) async {
      await loadCurrentSchedule();
    });
  }

  Future<void> loadCurrentSchedule() async {
    final day = getCurrentDayName();
    final now = DateTime.now();

    if (day.isEmpty) {
      if (!mounted) return;
      setState(() {
        currentSubject = '';
        currentSection = '';
        currentTimeSlot = '';
        currentDay = '';
        currentStartTime = '';
        currentEndTime = '';
        hasOngoingClass = false;
      });
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('schedules')
          .where('room', isEqualTo: selectedRoom)
          .where('day', isEqualTo: day)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;

      for (final doc in query.docs) {
        final data = doc.data();

        final startTime = (data['start_time'] ?? '').toString().trim();
        final endTime = (data['end_time'] ?? '').toString().trim();

        final start = parseTimeForToday(startTime);
        final end = parseTimeForToday(endTime);

        if (start == null || end == null) continue;

        final isActive =
            (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
                now.isBefore(end);

        if (isActive) {
          activeDoc = doc;
          break;
        }
      }

      if (!mounted) return;

      if (activeDoc == null) {
        setState(() {
          currentSubject = '';
          currentSection = '';
          currentTimeSlot = '';
          currentDay = day;
          currentStartTime = '';
          currentEndTime = '';
          hasOngoingClass = false;
        });
      } else {
        final data = activeDoc.data();

        setState(() {
          currentSubject = (data['subject'] ?? '').toString();
          currentSection = (data['section'] ?? '').toString();
          currentTimeSlot = (data['time_slot'] ?? '').toString();
          currentDay = (data['day'] ?? '').toString();
          currentStartTime = (data['start_time'] ?? '').toString();
          currentEndTime = (data['end_time'] ?? '').toString();
          hasOngoingClass = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load current schedule: $e');
    }
  }

  Map<String, Map<String, dynamic>> groupAttendanceByEmailFromCurrentClass(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final Map<String, Map<String, dynamic>> grouped = {};
    final currentRange = getCurrentClassRange();

    if (currentRange == null) return grouped;

    final lateThreshold = currentRange.start.add(const Duration(minutes: 15));

    for (final doc in docs) {
      final data = doc.data();
      final email = (data['student_email'] ?? '').toString().trim();
      final timestamp = data['timestamp'];

      if (email.isEmpty || timestamp is! Timestamp) continue;

      final scannedAt = timestamp.toDate();

      final insideClass =
          (scannedAt.isAfter(currentRange.start) ||
              scannedAt.isAtSameMomentAs(currentRange.start)) &&
              scannedAt.isBefore(currentRange.end);

      if (!insideClass) continue;

      if (!grouped.containsKey(email)) {
        grouped[email] = {
          'present': 0.0,
          'late': 0.0,
          'dates': <String>[],
          'scan_times': <String>[],
        };
      }

      if (scannedAt.isBefore(lateThreshold)) {
        grouped[email]!['present'] =
            (grouped[email]!['present'] as double) + 1.0;
      } else {
        grouped[email]!['late'] = (grouped[email]!['late'] as double) + 0.5;
      }

      final date = (data['date'] ?? '').toString().trim();
      if (date.isNotEmpty) {
        final dates = grouped[email]!['dates'] as List<String>;
        if (!dates.contains(date)) {
          dates.add(date);
        }
      }

      final scanTimes = grouped[email]!['scan_times'] as List<String>;
      final formattedTime =
          '${scannedAt.year}-${scannedAt.month.toString().padLeft(2, '0')}-${scannedAt.day.toString().padLeft(2, '0')} '
          '${scannedAt.hour.toString().padLeft(2, '0')}:${scannedAt.minute.toString().padLeft(2, '0')}:${scannedAt.second.toString().padLeft(2, '0')}';
      scanTimes.add(formattedTime);
    }

    return grouped;
  }

  Future<void> exportToExcel(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
    try {
      final grouped = groupAttendanceByEmailFromCurrentClass(docs);

      final excel = ex.Excel.createExcel();
      final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[defaultSheetName];

      sheet.appendRow([
        ex.TextCellValue('Email'),
        ex.TextCellValue('Present'),
        ex.TextCellValue('Late'),
        ex.TextCellValue('Attendance Score'),
        ex.TextCellValue('Date Attended'),
        ex.TextCellValue('Room'),
        ex.TextCellValue('Section'),
        ex.TextCellValue('Subject'),
        ex.TextCellValue('Time Slot'),
      ]);

      for (final entry in grouped.entries) {
        final email = entry.key;
        final present = entry.value['present'] as double;
        final late = entry.value['late'] as double;
        final score = present + late;
        final dates = (entry.value['dates'] as List<String>).join(', ');

        sheet.appendRow([
          ex.TextCellValue(email),
          ex.TextCellValue(present.toString()),
          ex.TextCellValue(late.toString()),
          ex.TextCellValue(score.toString()),
          ex.TextCellValue(dates),
          ex.TextCellValue(selectedRoom),
          ex.TextCellValue(currentSection),
          ex.TextCellValue(currentSubject),
          ex.TextCellValue(currentTimeSlot),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      if (kIsWeb) {
        final uint8List = Uint8List.fromList(bytes);
        final base64Data = base64Encode(uint8List);

        html.AnchorElement(
          href:
          'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64Data',
        )
          ..download = 'attendance.xlsx'
          ..click();
      } else {
        throw Exception('This export code is currently set up for web only.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel exported successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void showAttendanceDetails(
      BuildContext context,
      String email,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final currentRange = getCurrentClassRange();
    if (currentRange == null) return;

    final userDocs = docs.where((doc) {
      final data = doc.data();
      final docEmail = (data['student_email'] ?? '').toString().trim();
      final timestamp = data['timestamp'];

      if (docEmail != email || timestamp is! Timestamp) return false;

      final scannedAt = timestamp.toDate();

      return (scannedAt.isAfter(currentRange.start) ||
          scannedAt.isAtSameMomentAs(currentRange.start)) &&
          scannedAt.isBefore(currentRange.end);
    }).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(email),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: userDocs.length,
            itemBuilder: (_, index) {
              final data = userDocs[index].data();
              final timestamp = data['timestamp'];
              String scanText = 'No timestamp';

              if (timestamp is Timestamp) {
                final dt = timestamp.toDate();
                scanText =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
              }

              return ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text((data['date'] ?? 'No date').toString()),
                subtitle: Text('Scan time: $scanText'),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildCurrentClassCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: hasOngoingClass
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Class Attendance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text('Room: $selectedRoom'),
          Text('Day: $currentDay'),
          Text('Time: $currentTimeSlot'),
          Text('Subject: $currentSubject'),
          Text('Section: $currentSection'),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Class Attendance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text('Room: $selectedRoom'),
          const Text('No class ongoing right now.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toString().split(' ')[0];

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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  "Room:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedRoom,
                    underline: const SizedBox(),
                    items: rooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room,
                        child: Text('Room $room'),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value == null) return;

                      setState(() {
                        selectedRoom = value;
                      });

                      await loadCurrentSchedule();
                      _listenToScheduleRealtime();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildCurrentClassCard(),
            const SizedBox(height: 16),
            Expanded(
              child: !hasOngoingClass
                  ? const Center(
                child: Text(
                  'No active class attendance to display.',
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('lab', isEqualTo: selectedRoom)
                    .where('date', isEqualTo: today)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  final grouped =
                  groupAttendanceByEmailFromCurrentClass(docs);
                  final emails = grouped.keys.toList();

                  return Column(
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
                        child: emails.isEmpty
                            ? const Center(
                          child: Text(
                            'No students have scanned for this class yet.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                            : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Present')),
                              DataColumn(label: Text('Late')),
                              DataColumn(
                                label: Text('Attendance Score'),
                              ),
                              DataColumn(label: Text('Details')),
                            ],
                            rows: emails.map((email) {
                              final present =
                              grouped[email]!['present']
                              as double;
                              final late =
                              grouped[email]!['late'] as double;
                              final score = present + late;

                              return DataRow(
                                cells: [
                                  DataCell(Text(email)),
                                  DataCell(
                                      Text(present.toString())),
                                  DataCell(Text(late.toString())),
                                  DataCell(Text(score.toString())),
                                  DataCell(
                                    ElevatedButton(
                                      onPressed: () {
                                        showAttendanceDetails(
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