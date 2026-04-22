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
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);

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
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s?(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(normalized);

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
          .where('day', isEqualTo: day)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;

      for (final room in rooms) {
        for (final doc in query.docs) {
          final data = doc.data();

          final docRoom = (data['room'] ?? '').toString().trim();
          if (docRoom != room) continue;

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
        if (activeDoc != null) break;
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
          selectedRoom = (data['room'] ?? '').toString().trim();
          currentSubject = (data['subject'] ?? '').toString().trim();
          currentSection = (data['section'] ?? '').toString().trim();
          currentTimeSlot = (data['time_slot'] ?? '').toString().trim();
          currentDay = (data['day'] ?? '').toString().trim();
          currentStartTime = (data['start_time'] ?? '').toString().trim();
          currentEndTime = (data['end_time'] ?? '').toString().trim();
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
      final name = (data['student_name'] ?? '').toString().trim();
      final section = (data['student_section'] ?? '').toString().trim();
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
          'email': email,
          'student_name': name,
          'student_section': section,
          'present': 0.0,
          'late': 0.0,
          'absent': 0.0,
          'score': 0.0,
          'dates': <String>[],
          'scan_times': <String>[],
          'docs': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          'latest_doc': doc,
          'latest_scan': scannedAt,
          'teacher_attendance_status':
          (data['teacher_attendance_status'] ?? '').toString().toLowerCase(),
        };
      }

      final group = grouped[email]!;

      (group['docs'] as List<QueryDocumentSnapshot<Map<String, dynamic>>>)
          .add(doc);

      final latestScan = group['latest_scan'] as DateTime;
      if (scannedAt.isAfter(latestScan)) {
        group['latest_doc'] = doc;
        group['latest_scan'] = scannedAt;

        if (name.isNotEmpty) {
          group['student_name'] = name;
        }
        if (section.isNotEmpty) {
          group['student_section'] = section;
        }

        group['teacher_attendance_status'] =
            (data['teacher_attendance_status'] ?? '')
                .toString()
                .toLowerCase();
      }

      final overrideStatus =
      (data['teacher_attendance_status'] ?? '').toString().toLowerCase();

      if (overrideStatus == 'present') {
        group['present'] = (group['present'] as double) + 1.0;
        group['score'] = (group['score'] as double) + 1.0;
      } else if (overrideStatus == 'late') {
        group['late'] = (group['late'] as double) + 1.0;
        group['score'] = (group['score'] as double) + 0.5;
      } else if (overrideStatus == 'absent') {
        group['absent'] = (group['absent'] as double) + 1.0;
      } else {
        if (scannedAt.isBefore(lateThreshold)) {
          group['present'] = (group['present'] as double) + 1.0;
          group['score'] = (group['score'] as double) + 1.0;
        } else {
          group['late'] = (group['late'] as double) + 1.0;
          group['score'] = (group['score'] as double) + 0.5;
        }
      }

      final date = (data['date'] ?? '').toString().trim();
      if (date.isNotEmpty) {
        final dates = group['dates'] as List<String>;
        if (!dates.contains(date)) {
          dates.add(date);
        }
      }

      final scanTimes = group['scan_times'] as List<String>;
      final formattedTime =
          '${scannedAt.year}-${scannedAt.month.toString().padLeft(2, '0')}-${scannedAt.day.toString().padLeft(2, '0')} '
          '${scannedAt.hour.toString().padLeft(2, '0')}:${scannedAt.minute.toString().padLeft(2, '0')}:${scannedAt.second.toString().padLeft(2, '0')}';
      scanTimes.add(formattedTime);
    }

    return grouped;
  }

  Future<void> updateTeacherAttendanceStatus({
    required QueryDocumentSnapshot<Map<String, dynamic>> targetDoc,
    required String status,
  }) async {
    try {
      final normalized = status.toLowerCase();

      double present = 0;
      double late = 0;
      double absent = 0;
      double attendanceScore = 0;

      if (normalized == 'present') {
        present = 1;
        late = 0;
        absent = 0;
        attendanceScore = 1;
      } else if (normalized == 'late') {
        present = 0;
        late = 1;
        absent = 0;
        attendanceScore = 0.5;
      } else if (normalized == 'absent') {
        present = 0;
        late = 0;
        absent = 1;
        attendanceScore = 0;
      }

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(targetDoc.id)
          .update({
        'teacher_attendance_status': normalized,
        'teacher_attendance_updated_at': FieldValue.serverTimestamp(),
        'present': present,
        'late': late,
        'absent': absent,
        'attendance_score': attendanceScore,
      });

      if (!mounted) return;
      _snack('Attendance updated to ${status.toUpperCase()}',
          isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to update attendance: $e');
    }
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
        ex.TextCellValue('Student Name'),
        ex.TextCellValue('Email'),
        ex.TextCellValue('Section'),
        ex.TextCellValue('Present'),
        ex.TextCellValue('Late'),
        ex.TextCellValue('Absent'),
        ex.TextCellValue('Attendance Score'),
        ex.TextCellValue('Teacher Override'),
        ex.TextCellValue('Date Attended'),
        ex.TextCellValue('Room'),
        ex.TextCellValue('Class Section'),
        ex.TextCellValue('Subject'),
        ex.TextCellValue('Time Slot'),
      ]);

      for (final entry in grouped.entries) {
        final email = entry.key;
        final studentName = (entry.value['student_name'] ?? '').toString();
        final studentSection =
        (entry.value['student_section'] ?? '').toString();
        final present = entry.value['present'] as double;
        final late = entry.value['late'] as double;
        final absent = entry.value['absent'] as double;
        final score = entry.value['score'] as double;
        final dates = (entry.value['dates'] as List<String>).join(', ');
        final overrideStatus =
        (entry.value['teacher_attendance_status'] ?? '').toString();

        sheet.appendRow([
          ex.TextCellValue(studentName),
          ex.TextCellValue(email),
          ex.TextCellValue(studentSection),
          ex.TextCellValue(present.toString()),
          ex.TextCellValue(late.toString()),
          ex.TextCellValue(absent.toString()),
          ex.TextCellValue(score.toString()),
          ex.TextCellValue(overrideStatus),
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
          ..download =
              'attendance_${selectedRoom}_${currentSection}_${currentSubject}.xlsx'
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? const Color(0xFF3B6D11) : _nuDarkBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: const BoxDecoration(
                  color: _nuDarkBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Details',
                      style: TextStyle(
                        color: _nuWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: _nuGold.withOpacity(0.8),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: userDocs.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No attendance records found.',
                    style: TextStyle(color: Colors.black38),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: userDocs.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFFF3F4F6),
                  ),
                  itemBuilder: (_, index) {
                    final data = userDocs[index].data();
                    final timestamp = data['timestamp'];
                    String scanText = 'No timestamp';

                    if (timestamp is Timestamp) {
                      final dt = timestamp.toDate();
                      final h = dt.hour == 0
                          ? 12
                          : dt.hour > 12
                          ? dt.hour - 12
                          : dt.hour;
                      final m = dt.minute.toString().padLeft(2, '0');
                      final p = dt.hour >= 12 ? 'PM' : 'AM';
                      scanText = '$h:$m $p';
                    }

                    final teacherStatus =
                    (data['teacher_attendance_status'] ?? '')
                        .toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: _nuDarkBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (data['date'] ?? 'No date').toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                Text(
                                  'Scan time: $scanText',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Teacher status: ${teacherStatus.isEmpty ? 'Auto' : teacherStatus}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _nuDarkBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: hasOngoingClass
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _nuGold,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ONGOING CLASS',
              style: TextStyle(
                color: _nuDarkBlue,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currentSubject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _classMeta(Icons.access_time, currentTimeSlot),
              _classMeta(Icons.group_outlined, currentSection),
              _classMeta(
                Icons.meeting_room_outlined,
                'Room $selectedRoom',
              ),
            ],
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Auto Room Detection',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No class ongoing right now.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _classMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _nuGold.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _nuGold, width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/Images/NUSchoolLogo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ATTENDANCE',
                  style: TextStyle(
                    color: _nuWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'NATIONAL UNIVERSITY CLARK · FACULTY',
                  style: TextStyle(
                    color: _nuGold.withOpacity(0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
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
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  const Text(
                    "Current Room:",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F8),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasOngoingClass ? 'Room $selectedRoom' : 'No active room',
                      style: const TextStyle(
                        color: _nuDarkBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: const [
                      _LiveIndicator(),
                      SizedBox(width: 8),
                      Text(
                        'Live Sync Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                  children: const [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 52,
                      color: Colors.black12,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No active class attendance to display.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black38,
                      ),
                    ),
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
                  if (snapshot.hasError) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Attendance stream error',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _nuDarkBlue,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final grouped =
                  groupAttendanceByEmailFromCurrentClass(docs);
                  final emails = grouped.keys.toList();

                  return Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${emails.length} student${emails.length != 1 ? 's' : ''} scanned',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _nuDarkBlue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => exportToExcel(docs),
                            icon: const Icon(
                              Icons.download_outlined,
                              size: 16,
                            ),
                            label: const Text("Export Excel"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _nuDarkBlue,
                              foregroundColor: _nuGold,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
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
                            children: const [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.black12,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No students have scanned for this class yet.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.07),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF9FAFB),
                                  borderRadius:
                                  BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    _HeaderCell(
                                      flex: 4,
                                      text: 'STUDENT',
                                    ),
                                    _HeaderCell(
                                      flex: 1,
                                      text: 'PRESENT',
                                    ),
                                    _HeaderCell(
                                      flex: 1,
                                      text: 'LATE',
                                    ),
                                    _HeaderCell(
                                      flex: 1,
                                      text: 'ABSENT',
                                    ),
                                    _HeaderCell(
                                      flex: 1,
                                      text: 'SCORE',
                                    ),
                                    _HeaderCell(
                                      flex: 4,
                                      text: 'ACTIONS',
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: emails.length,
                                  separatorBuilder: (_, __) =>
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFF3F4F6),
                                  ),
                                  itemBuilder: (context, index) {
                                    final email = emails[index];
                                    final data = grouped[email]!;
                                    final present =
                                    data['present'] as double;
                                    final late =
                                    data['late'] as double;
                                    final absent =
                                    data['absent'] as double;
                                    final score =
                                    data['score'] as double;
                                    final studentName =
                                    (data['student_name'] ?? '')
                                        .toString();
                                    final studentSection =
                                    (data['student_section'] ??
                                        '')
                                        .toString();
                                    final latestDoc =
                                    data['latest_doc']
                                    as QueryDocumentSnapshot<
                                        Map<String, dynamic>>;
                                    final teacherStatus =
                                    (data['teacher_attendance_status'] ??
                                        '')
                                        .toString();

                                    return _AttendanceRow(
                                      email: email,
                                      studentName: studentName,
                                      studentSection:
                                      studentSection,
                                      present: present,
                                      late: late,
                                      absent: absent,
                                      score: score,
                                      teacherStatus:
                                      teacherStatus,
                                      onSetPresent: () =>
                                          updateTeacherAttendanceStatus(
                                            targetDoc: latestDoc,
                                            status: 'present',
                                          ),
                                      onSetLate: () =>
                                          updateTeacherAttendanceStatus(
                                            targetDoc: latestDoc,
                                            status: 'late',
                                          ),
                                      onSetAbsent: () =>
                                          updateTeacherAttendanceStatus(
                                            targetDoc: latestDoc,
                                            status: 'absent',
                                          ),
                                      onDetails: () =>
                                          showAttendanceDetails(
                                            context,
                                            email,
                                            docs,
                                          ),
                                    );
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 11,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF9FAFB),
                                  border: Border(
                                    top: BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  borderRadius:
                                  BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  '${emails.length} record${emails.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF22C55E),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AttendanceRow extends StatefulWidget {
  final String email;
  final String studentName;
  final String studentSection;
  final double present;
  final double late;
  final double absent;
  final double score;
  final String teacherStatus;
  final VoidCallback onSetPresent;
  final VoidCallback onSetLate;
  final VoidCallback onSetAbsent;
  final VoidCallback onDetails;

  const _AttendanceRow({
    required this.email,
    required this.studentName,
    required this.studentSection,
    required this.present,
    required this.late,
    required this.absent,
    required this.score,
    required this.teacherStatus,
    required this.onSetPresent,
    required this.onSetLate,
    required this.onSetAbsent,
    required this.onDetails,
  });

  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scoreColor = widget.score >= 1.0
        ? const Color(0xFF27500A)
        : widget.score > 0
        ? const Color(0xFF854F0B)
        : const Color(0xFF791F1F);

    final scoreBg = widget.score >= 1.0
        ? const Color(0xFFEAF3DE)
        : widget.score > 0
        ? const Color(0xFFFAEEDA)
        : const Color(0xFFFCEBEB);

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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        widget.email.isNotEmpty
                            ? widget.email[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _nuDarkBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.studentName.isNotEmpty
                              ? widget.studentName
                              : 'No name',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.studentSection.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Section: ${widget.studentSection}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _nuDarkBlue,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.teacherStatus.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Override: ${widget.teacherStatus.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _nuDarkBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.present.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.late.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.absent.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    widget.score.toStringAsFixed(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusBtn(
                    label: 'Present',
                    color: const Color(0xFF166534),
                    bg: const Color(0xFFDCFCE7),
                    onTap: widget.onSetPresent,
                  ),
                  _StatusBtn(
                    label: 'Late',
                    color: const Color(0xFF92400E),
                    bg: const Color(0xFFFEF3C7),
                    onTap: widget.onSetLate,
                  ),
                  _StatusBtn(
                    label: 'Absent',
                    color: const Color(0xFF991B1B),
                    bg: const Color(0xFFFEE2E2),
                    onTap: widget.onSetAbsent,
                  ),
                  _DetailsBtn(onTap: widget.onDetails),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBtn extends StatefulWidget {
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  State<_StatusBtn> createState() => _StatusBtnState();
}

class _StatusBtnState extends State<_StatusBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? widget.color : widget.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.color.withOpacity(0.2)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _hovered ? Colors.white : widget.color,
            ),
          ),
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
            border: Border.all(
              color: _h ? _nuDarkBlue : Colors.black.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Text(
            'Details',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _h ? _nuGold : _nuDarkBlue,
            ),
          ),
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
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.black45,
        letterSpacing: 0.8,
      ),
    ),
  );
}