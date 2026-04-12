import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

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
      _snack('Excel exported successfully', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Export failed: $e');
    }
  }

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? const Color(0xFF3B6D11) : _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
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
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: const BoxDecoration(
                  color: _nuDarkBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance Details',
                        style: TextStyle(color: _nuWhite, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(email,
                        style: TextStyle(color: _nuGold.withOpacity(0.8), fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: userDocs.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No attendance records found.', style: TextStyle(color: Colors.black38)),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: userDocs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (_, index) {
                    final data = userDocs[index].data();
                    final timestamp = data['timestamp'];
                    String scanText = 'No timestamp';

                    if (timestamp is Timestamp) {
                      final dt = timestamp.toDate();
                      final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
                      final m = dt.minute.toString().padLeft(2, '0');
                      final p = dt.hour >= 12 ? 'PM' : 'AM';
                      scanText = '$h:$m $p';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: const Color(0xFFE8EEF8), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.calendar_today_outlined, size: 15, color: _nuDarkBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((data['date'] ?? 'No date').toString(),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                Text('Scan time: $scanText', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _nuDarkBlue,
                      side: BorderSide(color: Colors.black.withOpacity(0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCurrentClassCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_nuBlue, _nuDarkBlue]),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: const Border(left: BorderSide(color: _nuGold, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: hasOngoingClass
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _nuGold, borderRadius: BorderRadius.circular(4)),
            child: const Text('ONGOING CLASS', style: TextStyle(color: _nuDarkBlue, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          Text(currentSubject, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _classMeta(Icons.access_time, currentTimeSlot),
              const SizedBox(width: 24),
              _classMeta(Icons.group_outlined, currentSection),
              const SizedBox(width: 24),
              _classMeta(Icons.meeting_room_outlined, 'Room $selectedRoom'),
            ],
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Room $selectedRoom', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('No class ongoing right now.', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _classMeta(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 14, color: _nuGold.withOpacity(0.7)),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toString().split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: _nuGold, width: 2),
              ),
              child: ClipOval(child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ATTENDANCE',
                    style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NATIONAL UNIVERSITY CLARK · FACULTY',
                    style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 2)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  const Text("Select Room:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F8),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRoom,
                        style: const TextStyle(color: _nuDarkBlue, fontWeight: FontWeight.w600, fontSize: 13),
                        items: rooms.map((room) => DropdownMenuItem(value: room, child: Text('Room $room'))).toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() { selectedRoom = value; });
                          await loadCurrentSchedule();
                          _listenToScheduleRealtime();
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Live status
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Live Sync Active', style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            buildCurrentClassCard(),
            const SizedBox(height: 20),
            Expanded(
              child: !hasOngoingClass
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_outlined, size: 52, color: Colors.black12),
                    const SizedBox(height: 12),
                    const Text('No active class attendance to display.', style: TextStyle(fontSize: 15, color: Colors.black38)),
                  ],
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
                    return const Center(child: CircularProgressIndicator(color: _nuDarkBlue));
                  }

                  final docs = snapshot.data!.docs;
                  final grouped = groupAttendanceByEmailFromCurrentClass(docs);
                  final emails = grouped.keys.toList();

                  return Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFE8EEF8), borderRadius: BorderRadius.circular(6)),
                            child: Text('${emails.length} student${emails.length != 1 ? 's' : ''} scanned',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _nuDarkBlue)),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => exportToExcel(docs),
                            icon: const Icon(Icons.download_outlined, size: 16),
                            label: const Text("Export Excel"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _nuDarkBlue,
                              foregroundColor: _nuGold,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: emails.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.black12),
                              const SizedBox(height: 12),
                              const Text('No students have scanned for this class yet.', style: TextStyle(fontSize: 14, color: Colors.black38)),
                            ],
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withOpacity(0.07)),
                          ),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                child: const Row(
                                  children: [
                                    _HeaderCell(flex: 4, text: 'STUDENT EMAIL'),
                                    _HeaderCell(flex: 1, text: 'PRESENT'),
                                    _HeaderCell(flex: 1, text: 'LATE'),
                                    _HeaderCell(flex: 2, text: 'SCORE'),
                                    _HeaderCell(flex: 2, text: 'ACTIONS'),
                                  ],
                                ),
                              ),
                              // Table Rows
                              Expanded(
                                child: ListView.separated(
                                  itemCount: emails.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                  itemBuilder: (context, index) {
                                    final email = emails[index];
                                    final present = grouped[email]!['present'] as double;
                                    final late = grouped[email]!['late'] as double;
                                    final score = present + late;

                                    return _AttendanceRow(
                                      email: email,
                                      present: present,
                                      late: late,
                                      score: score,
                                      onDetails: () => showAttendanceDetails(context, email, docs),
                                    );
                                  },
                                ),
                              ),
                              // Footer
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF9FAFB),
                                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                ),
                                child: Text('${emails.length} record${emails.length != 1 ? 's' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500)),
                              ),
                            ],
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

class _AttendanceRow extends StatefulWidget {
  final String email;
  final double present, late, score;
  final VoidCallback onDetails;

  const _AttendanceRow({
    required this.email, required this.present,
    required this.late, required this.score,
    required this.onDetails,
  });

  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scoreColor = widget.score >= 1.0 ? const Color(0xFF27500A) : const Color(0xFF791F1F);
    final scoreBg = widget.score >= 1.0 ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? const Color(0xFFF8FAFF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: const Color(0xFFE8EEF8), borderRadius: BorderRadius.circular(6)),
                    child: Center(
                      child: Text(widget.email.isNotEmpty ? widget.email[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _nuDarkBlue)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.email, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Expanded(flex: 1, child: Text(widget.present.toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
            Expanded(flex: 1, child: Text(widget.late.toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 48, padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: scoreBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: scoreColor.withOpacity(0.2))),
                  child: Text(widget.score.toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scoreColor)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _DetailsBtn(onTap: widget.onDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DetailsBtn({required this.onTap});

  @override
  State<_DetailsBtn> createState() => _DetailsBtnState();
}

class _DetailsBtnState extends State<_DetailsBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _h ? _nuDarkBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _h ? _nuDarkBlue : Colors.black.withOpacity(0.12), width: 1.5),
          ),
          child: Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _h ? _nuGold : _nuDarkBlue)),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final int flex;
  final String text;
  const _HeaderCell({required this.flex, required this.text});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8)),
  );
}
