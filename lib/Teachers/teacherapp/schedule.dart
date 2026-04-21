import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import 'attendance.dart';
import 'dashboard.dart';
import 'lab_map.dart';
import 'report_form.dart';
import 'login/screens/login_screen.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);
const Color _nuLightBg = Color(0xFFF0F3FA);
const Color _nuGrey = Color(0xFF64748B);
const Color _nuLightGrey = Color(0xFFE2E8F0);
const Color _nuAccentGold = Color(0xFFFFC107);

// ── Refined accent palette ─────────────────────────────────────────────────────
const Color _cardBorder = Color(0xFFD8E0F0);
const Color _rowAlt = Color(0xFFF7F9FE);
const Color _chipBg = Color(0xFFEEF3FF);
const Color _successGreen = Color(0xFF16A34A);
const Color _errorRed = Color(0xFFDC2626);

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<String> defaultRooms = ['706', '707', '708', '709', '710'];
  List<String> rooms = ['706', '707', '708', '709', '710'];
  bool isLoadingRooms = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _roomsSub;

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final List<String> timeSlots = [
    '7:00 AM - 7:20 AM',
    '7:20 AM - 7:40 AM',
    '7:40 AM - 8:00 AM',
    '8:00 AM - 8:20 AM',
    '8:20 AM - 8:40 AM',
    '8:40 AM - 9:00 AM',
    '9:00 AM - 9:20 AM',
    '9:20 AM - 9:40 AM',
    '9:40 AM - 10:00 AM',
    '10:00 AM - 10:20 AM',
    '10:20 AM - 10:40 AM',
    '10:40 AM - 11:00 AM',
    '11:00 AM - 11:20 AM',
    '11:20 AM - 11:40 AM',
    '11:40 AM - 12:00 PM',
    '12:00 PM - 12:20 PM',
    '12:20 PM - 12:40 PM',
    '12:40 PM - 1:00 PM',
    '1:00 PM - 1:20 PM',
    '1:20 PM - 1:40 PM',
    '1:40 PM - 2:00 PM',
    '2:00 PM - 2:20 PM',
    '2:20 PM - 2:40 PM',
    '2:40 PM - 3:00 PM',
    '3:00 PM - 3:20 PM',
    '3:20 PM - 3:40 PM',
    '3:40 PM - 4:00 PM',
    '4:00 PM - 4:20 PM',
    '4:20 PM - 4:40 PM',
    '4:40 PM - 5:00 PM',
    '5:00 PM - 5:20 PM',
    '5:20 PM - 5:40 PM',
    '5:40 PM - 6:00 PM',
    '6:00 PM - 6:20 PM',
    '6:20 PM - 6:40 PM',
    '6:40 PM - 7:00 PM',
    '7:00 PM - 7:20 PM',
    '7:20 PM - 7:40 PM',
    '7:40 PM - 8:00 PM',
    '8:00 PM - 8:20 PM',
    '8:20 PM - 8:40 PM',
    '8:40 PM - 9:00 PM',
  ];

  final List<String> sectionCourses = ['ITE'];
  final List<String> sectionNumbers = ['301', '302', '303', '304'];

  String selectedRoom = '706';
  String? selectedFileName;
  bool isImporting = false;
  bool isLoading = true;
  Map<String, Map<String, String>> scheduleMap = {};

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _initializeRoomsAndSchedule();
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get teacherEmail =>
      FirebaseAuth.instance.currentUser?.email?.trim() ?? 'unknown_teacher';

  String makeKey(String day, String timeSlot) => '${day}_$timeSlot';

  String buildSectionValue(String? course, String? sectionNumber) {
    final c = (course ?? '').trim();
    final s = (sectionNumber ?? '').trim();
    if (c.isEmpty || s.isEmpty) return '';
    return '$c$s';
  }

  String _normalizeRoomValue(String raw) {
    String value = raw.trim().toUpperCase();
    if (value.isEmpty) return '';

    if (value.startsWith('ROOM ')) {
      value = value.substring(5).trim();
    }

    return value;
  }

  Future<List<String>> _loadRoomsFromRoomsCollection() async {
    final snapshot = await FirebaseFirestore.instance.collection('rooms').get();
    final Set<String> foundRooms = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final candidates = <String>[
        (data['room'] ?? '').toString(),
        (data['lab'] ?? '').toString(),
        (data['room_number'] ?? '').toString(),
        (data['name'] ?? '').toString(),
        doc.id,
      ];

      for (final candidate in candidates) {
        final normalized = _normalizeRoomValue(candidate);
        if (normalized.isNotEmpty) {
          foundRooms.add(normalized);
          break;
        }
      }
    }

    return foundRooms.toList()..sort();
  }

  Future<List<String>> _loadRoomsFromPcsCollection() async {
    final snapshot = await FirebaseFirestore.instance.collection('pcs').get();
    final Set<String> foundRooms = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lab = _normalizeRoomValue((data['lab'] ?? '').toString());
      if (lab.isNotEmpty) {
        foundRooms.add(lab);
      }
    }

    return foundRooms.toList()..sort();
  }

  Future<void> loadRoomsFromFirestore() async {
    if (mounted) {
      setState(() => isLoadingRooms = true);
    }

    try {
      final Set<String> mergedRooms = {...defaultRooms};

      final firestoreRooms = await _loadRoomsFromRoomsCollection();
      mergedRooms.addAll(firestoreRooms);

      if (firestoreRooms.isEmpty) {
        mergedRooms.addAll(await _loadRoomsFromPcsCollection());
      }

      final sortedRooms = mergedRooms.toList()..sort();

      if (!mounted) return;
      setState(() {
        rooms = sortedRooms;
        if (rooms.isEmpty) {
          selectedRoom = '';
        } else if (!rooms.contains(selectedRoom)) {
          selectedRoom = defaultRooms.contains('706') && rooms.contains('706')
              ? '706'
              : rooms.first;
        }
      });
    } catch (e) {
      debugPrint('Failed to load schedule rooms: $e');
      if (!mounted) return;
      setState(() {
        rooms = [...defaultRooms];
        if (!rooms.contains(selectedRoom)) {
          selectedRoom = rooms.first;
        }
      });
    } finally {
      if (mounted) {
        setState(() => isLoadingRooms = false);
      }
    }
  }

  Future<void> _initializeRoomsAndSchedule() async {
    await loadRoomsFromFirestore();
    _listenToRoomUpdates();
    if (selectedRoom.isNotEmpty) {
      await loadScheduleForRoom();
    }
  }

  void _listenToRoomUpdates() {
    _roomsSub?.cancel();

    _roomsSub = FirebaseFirestore.instance
        .collection('rooms')
        .snapshots()
        .listen((_) async {
      final previousRoom = selectedRoom;
      await loadRoomsFromFirestore();

      if (!mounted) return;
      if (selectedRoom.isNotEmpty && previousRoom != selectedRoom) {
        await loadScheduleForRoom();
      }
    }, onError: (_) async {
      await loadRoomsFromFirestore();
    });
  }

  Future<void> _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("teacher_token");
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
          (route) => false,
    );
  }

  DateTime? parseTimeOnly(String value) {
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

    return DateTime(2000, 1, 1, hour, minute);
  }

  bool slotOverlapsClass({
    required String cellSlot,
    required String classStart,
    required String classEnd,
  }) {
    final parts = cellSlot.split(' - ');
    if (parts.length != 2) return false;

    final cellStart = parseTimeOnly(parts[0]);
    final cellEnd = parseTimeOnly(parts[1]);
    final clsStart = parseTimeOnly(classStart);
    final clsEnd = parseTimeOnly(classEnd);

    if (cellStart == null ||
        cellEnd == null ||
        clsStart == null ||
        clsEnd == null) {
      return false;
    }

    return cellStart.isBefore(clsEnd) && cellEnd.isAfter(clsStart);
  }

  bool rangesConflict({
    required String startA,
    required String endA,
    required String startB,
    required String endB,
  }) {
    final aStart = parseTimeOnly(startA);
    final aEnd = parseTimeOnly(endA);
    final bStart = parseTimeOnly(startB);
    final bEnd = parseTimeOnly(endB);

    if (aStart == null || aEnd == null || bStart == null || bEnd == null) {
      return false;
    }

    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  Future<Map<String, dynamic>?> findConflict({
    required String room,
    required String day,
    required String startTime,
    required String endTime,
    String? ignoreDocId,
  }) async {
    final roomQuery = await FirebaseFirestore.instance
        .collection('schedules')
        .where('room', isEqualTo: room)
        .where('day', isEqualTo: day)
        .get();

    for (final doc in roomQuery.docs) {
      if (ignoreDocId != null && doc.id == ignoreDocId) continue;

      final data = doc.data();
      final existingStart = (data['start_time'] ?? '').toString().trim();
      final existingEnd = (data['end_time'] ?? '').toString().trim();

      if (existingStart.isEmpty || existingEnd.isEmpty) continue;

      if (rangesConflict(
        startA: startTime,
        endA: endTime,
        startB: existingStart,
        endB: existingEnd,
      )) {
        return {
          'conflict_type': 'room',
          'docId': doc.id,
          'teacher_email': (data['teacher_email'] ?? '').toString(),
          'subject': (data['subject'] ?? '').toString(),
          'section': (data['section'] ?? '').toString(),
          'time_slot': (data['time_slot'] ?? '').toString(),
          'room': (data['room'] ?? '').toString(),
          'day': (data['day'] ?? '').toString(),
        };
      }
    }

    final teacherQuery = await FirebaseFirestore.instance
        .collection('schedules')
        .where('teacher_email', isEqualTo: teacherEmail)
        .where('day', isEqualTo: day)
        .get();

    for (final doc in teacherQuery.docs) {
      if (ignoreDocId != null && doc.id == ignoreDocId) continue;

      final data = doc.data();
      final existingStart = (data['start_time'] ?? '').toString().trim();
      final existingEnd = (data['end_time'] ?? '').toString().trim();

      if (existingStart.isEmpty || existingEnd.isEmpty) continue;

      if (rangesConflict(
        startA: startTime,
        endA: endTime,
        startB: existingStart,
        endB: existingEnd,
      )) {
        return {
          'conflict_type': 'teacher',
          'docId': doc.id,
          'teacher_email': (data['teacher_email'] ?? '').toString(),
          'subject': (data['subject'] ?? '').toString(),
          'section': (data['section'] ?? '').toString(),
          'time_slot': (data['time_slot'] ?? '').toString(),
          'room': (data['room'] ?? '').toString(),
          'day': (data['day'] ?? '').toString(),
        };
      }
    }

    return null;
  }

  void showConflictMessage(Map<String, dynamic> conflict) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: _errorRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (conflict['conflict_type'] ?? 'room') == 'teacher'
                                ? 'Teacher Schedule Conflict'
                                : 'Room Schedule Conflict',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _errorRed,
                            ),
                          ),
                          Text(
                            (conflict['conflict_type'] ?? 'room') == 'teacher'
                                ? 'You already have another class during this time'
                                : 'This room already has an existing class during this time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildConflictRow(
                      Icons.meeting_room_outlined,
                      'Room',
                      conflict['room'] ?? '',
                    ),
                    _buildConflictRow(
                      Icons.calendar_today_outlined,
                      'Day',
                      conflict['day'] ?? '',
                    ),
                    _buildConflictRow(
                      Icons.schedule_outlined,
                      'Time',
                      conflict['time_slot'] ?? '',
                    ),
                    _buildConflictRow(
                      Icons.book_outlined,
                      'Subject',
                      conflict['subject'] ?? '',
                    ),
                    _buildConflictRow(
                      Icons.groups_outlined,
                      'Section',
                      conflict['section'] ?? '',
                    ),
                    _buildConflictRow(
                      Icons.person_outline,
                      'Teacher',
                      conflict['teacher_email'] ?? '',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              (conflict['conflict_type'] ?? 'room') == 'teacher'
                                  ? 'Please check your day and time. A teacher cannot be assigned to two rooms at the same time.'
                                  : 'Please check the room number, day, and time. An existing class schedule already uses this room during that time.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _nuDarkBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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

  Widget _buildConflictRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _nuGrey),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              color: _nuGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: _nuDarkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> loadScheduleForRoom() async {
    setState(() => isLoading = true);
    _fadeCtrl.reset();

    try {
      final query = await FirebaseFirestore.instance
          .collection('schedules')
          .where('room', isEqualTo: selectedRoom)
          .get();

      final Map<String, Map<String, String>> loaded = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final day = (data['day'] ?? '').toString().trim();
        final startTime = (data['start_time'] ?? '').toString().trim();
        final endTime = (data['end_time'] ?? '').toString().trim();
        final subject = (data['subject'] ?? '').toString().trim();
        final section = (data['section'] ?? '').toString().trim();

        if (day.isEmpty || startTime.isEmpty || endTime.isEmpty) continue;

        final fullClassTime = '$startTime - $endTime';

        for (final slot in timeSlots) {
          if (slotOverlapsClass(
            cellSlot: slot,
            classStart: startTime,
            classEnd: endTime,
          )) {
            loaded[makeKey(day, slot)] = {
              'subject': subject,
              'section': section,
              'class_time': fullClassTime,
            };
          }
        }
      }

      if (!mounted) return;
      setState(() => scheduleMap = loaded);
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to load schedule: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String cellText(dynamic value) => value == null ? '' : value.toString().trim();

  List<String> extractCellLines(String raw) =>
      raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();


  String _compactSlotKey(String standardSlot) {
    final parts = standardSlot.split(' - ');
    if (parts.length != 2) return standardSlot.trim();

    String compact(String value) {
      final match = RegExp(
        r'^(\d{1,2}:\d{2})\s?(AM|PM)$',
        caseSensitive: false,
      ).firstMatch(value.trim());

      if (match == null) return value.trim();
      return match.group(1)!.trim();
    }

    return '${compact(parts.first)}-${compact(parts.last)}';
  }

  String? normalizeTimeSlotLabel(String raw) {
    final normalized = raw
        .trim()
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'\s+'), '');

    if (normalized.isEmpty) return null;

    for (final slot in timeSlots) {
      if (_compactSlotKey(slot).toLowerCase() == normalized.toLowerCase()) {
        return slot;
      }
    }

    return null;
  }

  bool isSectionText(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(' ', '');
    return RegExp(r'^[A-Z]{2,6}-?\d{3,4}$').hasMatch(normalized);
  }

  String normalizeSectionText(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  bool isIgnoredScheduleCell(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.isEmpty ||
        normalized == 'LUNCH BREAK' ||
        normalized == 'BREAK' ||
        normalized == 'VACANT';
  }

  int? findHeaderRow(ex.Sheet sheet) {
    for (int row = 0; row < 200; row++) {
      final firstCell = cellText(
        sheet
            .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value,
      ).toUpperCase();

      if (firstCell == 'TIME') {
        return row;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> parseStandardTemplateSheet(
      ex.Sheet sheet,
      String fileName,
      ) {
    final List<Map<String, dynamic>> parsedEntries = [];

    for (int row = 1; row <= timeSlots.length; row++) {
      final rowTime = cellText(
        sheet
            .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value,
      );

      if (rowTime.isEmpty) continue;

      for (int col = 1; col <= days.length; col++) {
        final day = days[col - 1];
        final rawCell = cellText(
          sheet
              .cell(
            ex.CellIndex.indexByColumnRow(
              columnIndex: col,
              rowIndex: row,
            ),
          )
              .value,
        );

        if (rawCell.isEmpty) continue;

        final lines = extractCellLines(rawCell);

        String subject = '';
        String section = '';
        String fullTime = '';

        if (lines.isNotEmpty) subject = lines[0];
        if (lines.length > 1) section = normalizeSectionText(lines[1]);
        if (lines.length > 2) fullTime = lines[2];

        if (subject.isEmpty) continue;

        String startTime;
        String endTime;

        if (fullTime.isNotEmpty && fullTime.contains(' - ')) {
          final parts = fullTime.split(' - ');
          startTime = parts.first.trim();
          endTime = parts.last.trim();
        } else {
          final normalizedSlot = normalizeTimeSlotLabel(rowTime) ?? rowTime;
          final parts = normalizedSlot.split(' - ');
          if (parts.length != 2) continue;
          startTime = parts.first.trim();
          endTime = parts.last.trim();
          fullTime = normalizedSlot;
        }

        parsedEntries.add({
          'room': selectedRoom,
          'day': day,
          'start_time': startTime,
          'end_time': endTime,
          'time_slot': '$startTime - $endTime',
          'subject': subject,
          'section': section,
          'teacher_email': teacherEmail,
          'source_file': fileName,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }

    return parsedEntries;
  }

  List<Map<String, dynamic>> parseFacultyScheduleSheet(
      ex.Sheet sheet,
      String fileName,
      ) {
    final List<Map<String, dynamic>> parsedEntries = [];
    final headerRow = findHeaderRow(sheet);

    if (headerRow == null) return parsedEntries;

    final Map<int, String> dayColumns = {};
    for (int col = 1; col <= 10; col++) {
      final headerText = cellText(
        sheet
            .cell(
          ex.CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: headerRow,
          ),
        )
            .value,
      ).toUpperCase();

      for (final day in days) {
        if (headerText == day.toUpperCase()) {
          dayColumns[col] = day;
          break;
        }
      }
    }

    if (dayColumns.isEmpty) return parsedEntries;

    for (final entry in dayColumns.entries) {
      final col = entry.key;
      final day = entry.value;

      int row = headerRow + 1;

      while (row < 200) {
        final timeText = cellText(
          sheet
              .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
          )
              .value,
        );
        final cellValue = cellText(
          sheet
              .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          )
              .value,
        );

        final normalizedSlot = normalizeTimeSlotLabel(timeText);

        if (normalizedSlot == null) {
          row++;
          continue;
        }

        if (isIgnoredScheduleCell(cellValue) || isSectionText(cellValue)) {
          row++;
          continue;
        }

        String subject = cellValue;
        String section = '';
        int endRow = row;

        int nextRow = row + 1;
        while (nextRow < 200) {
          final nextTimeText = cellText(
            sheet
                .cell(
              ex.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: nextRow,
              ),
            )
                .value,
          );
          final nextSlot = normalizeTimeSlotLabel(nextTimeText);
          if (nextSlot == null) break;

          final nextValue = cellText(
            sheet
                .cell(
              ex.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: nextRow,
              ),
            )
                .value,
          );

          if (isSectionText(nextValue) && section.isEmpty) {
            section = normalizeSectionText(nextValue);
            endRow = nextRow;
            nextRow++;
            continue;
          }

          if (nextValue.trim().toUpperCase() == subject.trim().toUpperCase()) {
            endRow = nextRow;
            nextRow++;
            continue;
          }

          break;
        }

        final startSlot = normalizeTimeSlotLabel(
          cellText(
            sheet
                .cell(
              ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
            )
                .value,
          ),
        );
        final endSlot = normalizeTimeSlotLabel(
          cellText(
            sheet
                .cell(
              ex.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: endRow,
              ),
            )
                .value,
          ),
        );

        if (startSlot != null && endSlot != null) {
          final startParts = startSlot.split(' - ');
          final endParts = endSlot.split(' - ');

          if (startParts.length == 2 && endParts.length == 2) {
            final startTime = startParts.first.trim();
            final endTime = endParts.last.trim();

            parsedEntries.add({
              'room': selectedRoom,
              'day': day,
              'start_time': startTime,
              'end_time': endTime,
              'time_slot': '$startTime - $endTime',
              'subject': subject,
              'section': section,
              'teacher_email': teacherEmail,
              'source_file': fileName,
              'created_at': FieldValue.serverTimestamp(),
            });
          }
        }

        row = endRow + 1;
      }
    }

    return parsedEntries;
  }

  Future<void> exportScheduleTemplate() async {
    try {
      final excel = ex.Excel.createExcel();
      final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[defaultSheetName];

      sheet.appendRow([
        ex.TextCellValue('Time'),
        ...days.map((d) => ex.TextCellValue(d)),
      ]);

      // Export should always be a blank template.
      // It must not include the currently loaded classes from scheduleMap.
      for (final slot in timeSlots) {
        sheet.appendRow([
          ex.TextCellValue(slot),
          ...List.generate(days.length, (_) => ex.TextCellValue('')),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      if (kIsWeb) {
        final base64Data = base64Encode(Uint8List.fromList(bytes));
        html.AnchorElement(
          href:
          'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64Data',
        )
          ..download = 'schedule_template_room_$selectedRoom.xlsx'
          ..click();
      } else {
        throw Exception('Excel export is currently set up for web only.');
      }

      if (!mounted) return;
      _showSuccessSnackBar('Blank schedule template exported successfully');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Export failed: $e');
    }
  }

  Future<void> importExcelFile() async {
    try {
      setState(() => isImporting = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => isImporting = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('No file data found.');
      }

      final excel = ex.Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null) {
        throw Exception('No sheet found in the Excel file.');
      }

      final parsedEntries = <Map<String, dynamic>>[];
      parsedEntries.addAll(parseStandardTemplateSheet(sheet, file.name));

      if (parsedEntries.isEmpty) {
        parsedEntries.addAll(parseFacultyScheduleSheet(sheet, file.name));
      }

      final unique = <String, Map<String, dynamic>>{};
      for (final entry in parsedEntries) {
        final key =
            '${entry['room']}_${entry['day']}_${entry['start_time']}_${entry['end_time']}_${entry['subject']}_${entry['section']}';
        unique[key] = entry;
      }

      final importedEntries = unique.values.toList();

      for (int i = 0; i < importedEntries.length; i++) {
        for (int j = i + 1; j < importedEntries.length; j++) {
          final a = importedEntries[i];
          final b = importedEntries[j];

          if (a['room'] == b['room'] &&
              a['day'] == b['day'] &&
              rangesConflict(
                startA: a['start_time'].toString(),
                endA: a['end_time'].toString(),
                startB: b['start_time'].toString(),
                endB: b['end_time'].toString(),
              )) {
            throw Exception(
              'Imported Excel has overlapping schedules in ${a['day']} (${a['time_slot']} and ${b['time_slot']}).',
            );
          }
        }
      }

      final oldDocs = await FirebaseFirestore.instance
          .collection('schedules')
          .where('room', isEqualTo: selectedRoom)
          .get();

      final deleteBatch = FirebaseFirestore.instance.batch();
      for (final doc in oldDocs.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      final saveBatch = FirebaseFirestore.instance.batch();
      for (final entry in importedEntries) {
        saveBatch.set(
          FirebaseFirestore.instance.collection('schedules').doc(),
          entry,
        );
      }
      await saveBatch.commit();

      if (!mounted) return;

      setState(() => selectedFileName = file.name);

      await loadScheduleForRoom();

      if (!mounted) return;

      _showSuccessSnackBar(
        importedEntries.isEmpty
            ? 'File imported, but no schedule entries were found.'
            : 'Successfully imported ${importedEntries.length} schedule entries',
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to import file: $e');
    } finally {
      if (mounted) {
        setState(() => isImporting = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: _successGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: _errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> showManageScheduleDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 720,
          height: 560,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 22,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_nuBlue, _nuDarkBlue],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Schedule',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Add, edit, or remove schedule entries',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PillButton(
                      label: 'Add Entry',
                      icon: Icons.add_rounded,
                      color: _nuGold,
                      textColor: _nuDarkBlue,
                      onPressed: () async {
                        Navigator.pop(context);
                        await showScheduleFormDialog();
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('schedules')
                      .where('room', isEqualTo: selectedRoom)
                      .where('teacher_email', isEqualTo: teacherEmail)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _nuBlue,
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _nuLightBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.event_busy_rounded,
                                size: 36,
                                color: _nuGrey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No entries yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _nuDarkBlue,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "Add Entry" to create a new schedule',
                              style: TextStyle(fontSize: 12, color: _nuGrey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final day = (data['day'] ?? '').toString();
                        final subject = (data['subject'] ?? '').toString();
                        final section = (data['section'] ?? '').toString();
                        final slot = (data['time_slot'] ?? '').toString();

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _chipBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.class_rounded,
                                color: _nuBlue,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _nuDarkBlue,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _InfoChip(
                                    icon: Icons.calendar_today_outlined,
                                    label: day,
                                  ),
                                  _InfoChip(
                                    icon: Icons.schedule_outlined,
                                    label: slot,
                                  ),
                                  if (section.isNotEmpty)
                                    _InfoChip(
                                      icon: Icons.groups_outlined,
                                      label: section,
                                      highlight: true,
                                    ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _IconActionBtn(
                                  icon: Icons.edit_rounded,
                                  color: _nuBlue,
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await showScheduleFormDialog(
                                      docId: doc.id,
                                      initialDay: day,
                                      initialStartTime:
                                      (data['start_time'] ?? '').toString(),
                                      initialEndTime:
                                      (data['end_time'] ?? '').toString(),
                                      initialSubject: subject,
                                      initialSection: section,
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                _IconActionBtn(
                                  icon: Icons.delete_rounded,
                                  color: _errorRed,
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection('schedules')
                                        .doc(doc.id)
                                        .delete();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await loadScheduleForRoom();
  }

  Future<void> showScheduleFormDialog({
    String? docId,
    String? initialDay,
    String? initialStartTime,
    String? initialEndTime,
    String? initialSubject,
    String? initialSection,
  }) async {
    String selectedDay = initialDay ?? days.first;
    final startCtrl = TextEditingController(text: initialStartTime ?? '');
    final endCtrl = TextEditingController(text: initialEndTime ?? '');
    final subjectCtrl = TextEditingController(text: initialSubject ?? '');

    String? selectedCourse;
    String? selectedSectionNumber;

    final initialSectionValue = (initialSection ?? '').trim();
    if (initialSectionValue.isNotEmpty) {
      if (initialSectionValue.startsWith('ITE')) {
        selectedCourse = 'ITE';
        selectedSectionNumber = initialSectionValue.replaceFirst('ITE', '');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 480,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: _nuLightBg,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _nuBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            docId == null
                                ? Icons.add_circle_outline_rounded
                                : Icons.edit_rounded,
                            color: _nuBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          docId == null ? 'Add New Schedule' : 'Edit Schedule',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _nuDarkBlue,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _nuGrey,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _FormField(
                          label: 'Day',
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            decoration: _inputDecoration('Select Day'),
                            items: days
                                .map(
                                  (d) => DropdownMenuItem(
                                value: d,
                                child: Text(d),
                              ),
                            )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) selectedDay = v;
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Start Time',
                                child: TextField(
                                  controller: startCtrl,
                                  decoration: _inputDecoration(
                                    'e.g., 1:00 PM',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _FormField(
                                label: 'End Time',
                                child: TextField(
                                  controller: endCtrl,
                                  decoration: _inputDecoration(
                                    'e.g., 2:30 PM',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _FormField(
                          label: 'Subject',
                          child: TextField(
                            controller: subjectCtrl,
                            decoration: _inputDecoration('Enter subject name'),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Course',
                                child: DropdownButtonFormField<String>(
                                  value: selectedCourse,
                                  decoration: _inputDecoration('Select course'),
                                  items: sectionCourses
                                      .map(
                                        (course) => DropdownMenuItem(
                                      value: course,
                                      child: Text(course),
                                    ),
                                  )
                                      .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      selectedCourse = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _FormField(
                                label: 'Section',
                                child: DropdownButtonFormField<String>(
                                  value: selectedSectionNumber,
                                  decoration: _inputDecoration(
                                    'Select section',
                                  ),
                                  items: sectionNumbers
                                      .map(
                                        (number) => DropdownMenuItem(
                                      value: number,
                                      child: Text(number),
                                    ),
                                  )
                                      .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      selectedSectionNumber = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _nuGrey,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: _nuLightGrey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _nuDarkBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final start = startCtrl.text.trim();
                              final end = endCtrl.text.trim();
                              final subject = subjectCtrl.text.trim();
                              final section = buildSectionValue(
                                selectedCourse,
                                selectedSectionNumber,
                              );

                              if (start.isEmpty ||
                                  end.isEmpty ||
                                  subject.isEmpty) {
                                _showErrorSnackBar(
                                  'Please fill all required fields',
                                );
                                return;
                              }

                              if (section.isEmpty) {
                                _showErrorSnackBar(
                                  'Please select both course and section',
                                );
                                return;
                              }

                              final conflict = await findConflict(
                                room: selectedRoom,
                                day: selectedDay,
                                startTime: start,
                                endTime: end,
                                ignoreDocId: docId,
                              );

                              if (conflict != null) {
                                if (!mounted) return;
                                Navigator.pop(context);
                                showConflictMessage(conflict);
                                return;
                              }

                              final data = {
                                'room': selectedRoom,
                                'day': selectedDay,
                                'start_time': start,
                                'end_time': end,
                                'time_slot': '$start - $end',
                                'subject': subject,
                                'section': section,
                                'teacher_email': teacherEmail,
                                'source_file':
                                docId == null ? 'manual_add' : 'manual_edit',
                                'created_at': FieldValue.serverTimestamp(),
                              };

                              if (docId == null) {
                                await FirebaseFirestore.instance
                                    .collection('schedules')
                                    .add(data);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('schedules')
                                    .doc(docId)
                                    .update(data);
                              }

                              if (!mounted) return;
                              Navigator.pop(context);
                              await loadScheduleForRoom();
                              _showSuccessSnackBar(
                                docId == null
                                    ? 'Schedule added successfully'
                                    : 'Schedule updated successfully',
                              );
                            },
                            child: Text(
                              docId == null
                                  ? 'Save Schedule'
                                  : 'Update Schedule',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) => InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: _nuGrey.withOpacity(0.5), fontSize: 13),
    filled: true,
    fillColor: _nuLightBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _nuBlue, width: 1.5),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

  Widget buildCell(String day, String timeSlot, int rowIndex) {
    final entry = scheduleMap[makeKey(day, timeSlot)];
    final subject = entry?['subject'] ?? '';
    final section = entry?['section'] ?? '';
    final classTime = entry?['class_time'] ?? '';
    final hasClass = subject.isNotEmpty || section.isNotEmpty;
    final isAlt = rowIndex.isOdd;

    return Container(
      width: 148,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: hasClass
            ? _nuDarkBlue.withOpacity(0.07)
            : (isAlt ? _rowAlt : Colors.white),
        border: Border(
          right: BorderSide(color: _nuLightGrey.withOpacity(0.6), width: 1),
          bottom: BorderSide(color: _nuLightGrey.withOpacity(0.6), width: 1),
        ),
      ),
      child: hasClass
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _nuDarkBlue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (section.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              section,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                color: _nuBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (classTime.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              classTime,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                color: _nuGrey.withOpacity(0.7),
              ),
            ),
          ],
        ],
      )
          : const SizedBox.shrink(),
    );
  }

  Widget buildTimetable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeaderCell(label: 'TIME', width: 128, isFirst: true),
              ...days.map(
                    (d) => _HeaderCell(label: d.toUpperCase(), width: 148),
              ),
            ],
          ),
          ...timeSlots.asMap().entries.map((entry) {
            final i = entry.key;
            final slot = entry.value;
            return Row(
              children: [
                Container(
                  width: 128,
                  height: 62,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: i.isOdd ? _rowAlt : Colors.white,
                    border: Border(
                      right: BorderSide(color: _nuLightGrey.withOpacity(0.6)),
                      bottom: BorderSide(color: _nuLightGrey.withOpacity(0.6)),
                    ),
                  ),
                  child: Text(
                    slot,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: _nuGrey.withOpacity(0.8),
                      height: 1.3,
                    ),
                  ),
                ),
                ...days.map((day) => buildCell(day, slot, i)),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final occupiedCount =
        scheduleMap.values.map((e) => e['class_time']).toSet().length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _nuLightBg,
      drawer: _TeacherDrawer(onLogout: () => _signOut(context)),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'ROOM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _nuGrey,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        isLoadingRooms
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _nuBlue,
                          ),
                        )
                            : _RoomDropdown(
                          rooms: rooms,
                          selectedRoom: selectedRoom,
                          onChanged: (v) async {
                            if (v == null || v == selectedRoom) return;
                            setState(() => selectedRoom = v);
                            await loadScheduleForRoom();
                          },
                        ),
                        const Spacer(),
                        _StatPill(
                          label: 'Room $selectedRoom',
                          icon: Icons.meeting_room_outlined,
                          color: _nuBlue,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          label: '$occupiedCount classes',
                          icon: Icons.event_note_rounded,
                          color: _successGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: _nuLightGrey),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ActionButton(
                          label: isImporting ? 'Importing…' : 'Import Excel',
                          icon: Icons.upload_file_rounded,
                          bgColor: _nuGold,
                          textColor: _nuDarkBlue,
                          onPressed: isImporting ? null : importExcelFile,
                          isLoading: isImporting,
                        ),
                        _ActionButton(
                          label: 'Export Excel',
                          icon: Icons.download_rounded,
                          bgColor: _chipBg,
                          textColor: _nuDarkBlue,
                          onPressed: exportScheduleTemplate,
                        ),
                        _ActionButton(
                          label: 'Manage Schedule',
                          icon: Icons.edit_calendar_rounded,
                          bgColor: const Color(0xFFDCFCE7),
                          textColor: _successGreen,
                          onPressed: showManageScheduleDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FileBanner(fileName: selectedFileName),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isLoading
                        ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              color: _nuBlue,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Loading schedule…',
                            style: TextStyle(
                              color: _nuGrey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                        : FadeTransition(
                      opacity: _fadeAnim,
                      child: Scrollbar(
                        thumbVisibility: true,
                        radius: const Radius.circular(8),
                        child: SingleChildScrollView(
                          child: buildTimetable(),
                        ),
                      ),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _nuDarkBlue,
      elevation: 0,
      toolbarHeight: 66,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: _nuGold, size: 24),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _nuGold.withOpacity(0.7), width: 1.5),
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
                'SCHEDULE MANAGEMENT',
                style: TextStyle(
                  color: _nuWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                'National University · Clark',
                style: TextStyle(
                  color: _nuGold.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            label: const Text(
              'Back',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_nuGold, Color(0xFFFFB300)]),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final bool isFirst;

  const _HeaderCell({
    required this.label,
    required this.width,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_nuBlue, _nuDarkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RoomDropdown extends StatelessWidget {
  final List<String> rooms;
  final String selectedRoom;
  final ValueChanged<String?> onChanged;

  const _RoomDropdown({
    required this.rooms,
    required this.selectedRoom,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _nuBlue.withOpacity(0.2)),
      ),
      child: DropdownButton<String>(
        value: rooms.contains(selectedRoom) ? selectedRoom : null,
        hint: const Text(
          'No rooms',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _nuDarkBlue,
            fontSize: 13,
          ),
        ),
        underline: const SizedBox(),
        isDense: true,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: _nuDarkBlue,
          fontSize: 14,
        ),
        items: rooms
            .map(
              (r) => DropdownMenuItem(
            value: r,
            child: Text(
              'Room $r',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _nuDarkBlue,
                fontSize: 13,
              ),
            ),
          ),
        )
            .toList(),
        onChanged: rooms.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: textColor,
        ),
      )
          : Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _FileBanner extends StatelessWidget {
  final String? fileName;

  const _FileBanner({this.fileName});

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFEFF6FF) : _nuLightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasFile ? const Color(0xFFBFDBFE) : _nuLightGrey,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFile ? Icons.task_alt_rounded : Icons.info_outline_rounded,
            size: 16,
            color: hasFile ? const Color(0xFF2563EB) : _nuGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasFile
                  ? 'Imported: $fileName'
                  : 'No Excel file imported yet — use "Import Excel" to load a schedule.',
              style: TextStyle(
                fontSize: 12,
                color: hasFile
                    ? const Color(0xFF1D4ED8)
                    : _nuGrey.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _nuDarkBlue,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? _nuGold.withOpacity(0.12) : _chipBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? _nuGold.withOpacity(0.3) : _nuLightGrey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: highlight ? _nuAccentGold : _nuGrey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? _nuAccentGold : _nuGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

class _ConflictInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ConflictInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _nuBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _nuGrey.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _nuDarkBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherDrawer extends StatelessWidget {
  final VoidCallback onLogout;

  const _TeacherDrawer({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 54, 22, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_nuBlue, _nuDarkBlue],
              ),
              borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _nuGold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/Images/NUSchoolLogo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'National University',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Clark Campus',
                  style: TextStyle(
                    color: _nuGold.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _nuGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _nuGold.withOpacity(0.25)),
                  ),
                  child: const Text(
                    'Faculty Member',
                    style: TextStyle(
                      color: _nuGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 2, color: _nuGold),
          const SizedBox(height: 10),
          _DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const TeacherDashboard()),
                    (r) => false,
              );
            },
          ),
          _DrawerItem(
            icon: Icons.calendar_month_rounded,
            label: 'Schedule',
            onTap: () => Navigator.pop(context),
            isActive: true,
          ),
          _DrawerItem(
            icon: Icons.map_rounded,
            label: 'Lab Map',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LabMapPage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.people_rounded,
            label: 'Attendance',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendancePage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.report_problem_rounded,
            label: 'Report to ITSO',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherReportFormPage()),
              );
            },
          ),
          const Spacer(),
          Container(height: 1, color: _nuLightGrey),
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            isDestructive: true,
            onTap: onLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isActive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? _errorRed
        : (isActive ? _nuBlue : _nuDarkBlue);
    final bgColor = isDestructive
        ? _errorRed.withOpacity(0.08)
        : (isActive ? _nuBlue.withOpacity(0.1) : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _nuBlue.withOpacity(0.12)
                        : color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _nuBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}