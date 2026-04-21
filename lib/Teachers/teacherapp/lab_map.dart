import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'attendance.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);

class LabMapPage extends StatefulWidget {
  const LabMapPage({super.key});

  @override
  State<LabMapPage> createState() => _LabMapPageState();
}

class _LabMapPageState extends State<LabMapPage> {
  final List<String> rooms = ['706', '707', '708', '709', '710', '723'];
  String selectedRoom = '706';

  String? selectedPc;
  Map<String, dynamic>? selectedPcData;
  String? selectedPcDocId;

  final Map<String, Map<String, dynamic>> docsByPc = {};
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  attendanceByPc = {};

  String currentSubject = '';
  String currentSection = '';
  String currentTimeSlot = '';
  String currentStartTime = '';
  String currentEndTime = '';
  bool hasOngoingClass = false;

  Timer? refreshTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pcsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _scheduleSub;

  @override
  void initState() {
    super.initState();
    refreshAll();
    _listenToRealtimeUpdates();
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await refreshAll();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    _attendanceSub?.cancel();
    _pcsSub?.cancel();
    _scheduleSub?.cancel();
    super.dispose();
  }

  Future<void> refreshAll() async {
    await loadPcsForSelectedRoom();
    await loadCurrentScheduleForRoom();
    await loadTodayAttendanceForRoom();
  }

  void _listenToRealtimeUpdates() {
    _attendanceSub?.cancel();
    _pcsSub?.cancel();
    _scheduleSub?.cancel();

    final today = DateTime.now().toString().split(' ')[0];
    final currentDay = getCurrentDayName();

    _attendanceSub = FirebaseFirestore.instance
        .collection('attendance')
        .where('lab', isEqualTo: selectedRoom)
        .where('date', isEqualTo: today)
        .snapshots()
        .listen((_) async {
      await loadTodayAttendanceForRoom();
      if (!mounted) return;
      if (selectedPc != null) {
        final selected = docsByPc[selectedPc!.toUpperCase()];
        setState(() {
          selectedPcData = selected?['data'] as Map<String, dynamic>?;
          selectedPcDocId = selected?['docId'] as String?;
        });
      } else {
        setState(() {});
      }
    });

    _pcsSub = FirebaseFirestore.instance
        .collection('pcs')
        .where('lab', isEqualTo: selectedRoom)
        .snapshots()
        .listen((_) async {
      await loadPcsForSelectedRoom();
      if (!mounted) return;
      if (selectedPc != null) {
        final selected = docsByPc[selectedPc!.toUpperCase()];
        setState(() {
          selectedPcData = selected?['data'] as Map<String, dynamic>?;
          selectedPcDocId = selected?['docId'] as String?;
        });
      } else {
        setState(() {});
      }
    });

    if (currentDay.isNotEmpty) {
      _scheduleSub = FirebaseFirestore.instance
          .collection('schedules')
          .where('room', isEqualTo: selectedRoom)
          .where('day', isEqualTo: currentDay)
          .snapshots()
          .listen((_) async {
        await loadCurrentScheduleForRoom();
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  String getCurrentDayName() {
    switch (DateTime.now().weekday) {
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

  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.month}/${dt.day}/${dt.year} $h:$m $p';
    }
    return timestamp.toString();
  }

  String normalizePcName(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return '';
    final noSpaces = value.replaceAll(' ', '');
    final match1 = RegExp(r'^PC(\d+)$').firstMatch(noSpaces);
    if (match1 != null) return 'PC${match1.group(1)}';
    final match2 = RegExp(r'PC\s*(\d+)', caseSensitive: false).firstMatch(value);
    if (match2 != null) return 'PC${match2.group(1)}';
    return noSpaces;
  }

  Future<void> loadCurrentScheduleForRoom() async {
    final currentDay = getCurrentDayName();
    final now = DateTime.now();

    if (currentDay.isEmpty) {
      if (!mounted) return;
      setState(() {
        currentSubject = '';
        currentSection = '';
        currentTimeSlot = '';
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
          .where('day', isEqualTo: currentDay)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;

      for (final doc in query.docs) {
        final data = doc.data();
        final start =
        parseTimeForToday((data['start_time'] ?? '').toString().trim());
        final end = parseTimeForToday((data['end_time'] ?? '').toString().trim());

        if (start == null || end == null) continue;

        if ((now.isAfter(start) || now.isAtSameMomentAs(start)) &&
            now.isBefore(end)) {
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
          currentStartTime = (data['start_time'] ?? '').toString();
          currentEndTime = (data['end_time'] ?? '').toString();
          hasOngoingClass = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load current schedule: $e');
    }
  }

  Future<void> loadTodayAttendanceForRoom() async {
    final today = DateTime.now().toString().split(' ')[0];

    try {
      final query = await FirebaseFirestore.instance
          .collection('attendance')
          .where('lab', isEqualTo: selectedRoom)
          .where('date', isEqualTo: today)
          .get();

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      mapped = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final rawPc =
        (data['pc'] ?? data['pc_name'] ?? data['workstation'] ?? '')
            .toString();
        final pc = normalizePcName(rawPc);

        if (pc.isEmpty) continue;

        mapped.putIfAbsent(pc, () => []);
        mapped[pc]!.add(doc);
      }

      if (!mounted) return;
      setState(() {
        attendanceByPc
          ..clear()
          ..addAll(mapped);
      });
    } catch (e) {
      debugPrint('Failed to load attendance: $e');
    }
  }

  Future<void> loadPcsForSelectedRoom() async {
    final allDocs = await FirebaseFirestore.instance.collection('pcs').get();
    final Map<String, Map<String, dynamic>> mapped = {};

    for (int i = 1; i <= 40; i++) {
      final pcName = 'PC$i';
      final expectedPrefix = '$selectedRoom-$pcName-';

      for (final doc in allDocs.docs) {
        final data = doc.data();
        final fieldLab = (data['lab'] ?? '').toString().trim();
        final fieldPc = normalizePcName((data['pc'] ?? '').toString());

        if (doc.id.startsWith(expectedPrefix) ||
            (fieldLab == selectedRoom && fieldPc == pcName.toUpperCase())) {
          mapped[pcName.toUpperCase()] = {
            'docId': doc.id,
            'data': data,
          };
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      docsByPc
        ..clear()
        ..addAll(mapped);

      if (selectedPc != null) {
        final selected = docsByPc[selectedPc!.toUpperCase()];
        selectedPcData = selected?['data'] as Map<String, dynamic>?;
        selectedPcDocId = selected?['docId'] as String?;
      }
    });
  }

  bool isPcScannedDuringCurrentClass(String pcName) {
    if (!hasOngoingClass) return false;

    final docs = attendanceByPc[pcName.toUpperCase()];
    if (docs == null || docs.isEmpty) return false;

    final currentRange = getCurrentClassRange();
    if (currentRange == null) return false;

    for (final doc in docs) {
      final timestamp = doc.data()['timestamp'];
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        if ((dt.isAfter(currentRange.start) ||
            dt.isAtSameMomentAs(currentRange.start)) &&
            dt.isBefore(currentRange.end)) {
          return true;
        }
      }
    }
    return false;
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? getLatestCurrentClassAttendance(
      String pcName,
      ) {
    if (!hasOngoingClass) return null;

    final docs = attendanceByPc[pcName.toUpperCase()];
    if (docs == null || docs.isEmpty) return null;

    final currentRange = getCurrentClassRange();
    if (currentRange == null) return null;

    QueryDocumentSnapshot<Map<String, dynamic>>? latest;

    for (final doc in docs) {
      final timestamp = doc.data()['timestamp'];
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        if ((dt.isAfter(currentRange.start) ||
            dt.isAtSameMomentAs(currentRange.start)) &&
            dt.isBefore(currentRange.end)) {
          if (latest == null) {
            latest = doc;
          } else {
            final latestTs = latest.data()['timestamp'];
            if (latestTs is Timestamp && dt.isAfter(latestTs.toDate())) {
              latest = doc;
            }
          }
        }
      }
    }
    return latest;
  }

  Future<void> updateAttendanceStatusForSelectedPc(String status) async {
    if (selectedPc == null) return;

    final latest = getLatestCurrentClassAttendance(selectedPc!);
    if (latest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No current class attendance record found for this PC.',
          ),
          backgroundColor: _nuDarkBlue,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    double score = 0.0;
    double present = 0.0;
    double late = 0.0;
    double absent = 0.0;

    switch (status.toLowerCase()) {
      case 'present':
        score = 1.0;
        present = 1.0;
        break;
      case 'late':
        score = 0.5;
        late = 1.0;
        break;
      case 'absent':
        score = 0.0;
        absent = 1.0;
        break;
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(latest.id)
        .update({
      'teacher_attendance_status': status.toLowerCase(),
      'teacher_attendance_score': score,
      'teacher_present': present,
      'teacher_late': late,
      'teacher_absent': absent,
      'teacher_marked_at': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance marked as ${status.toUpperCase()}'),
        backgroundColor: const Color(0xFF3B6D11),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    await loadTodayAttendanceForRoom();
    setState(() {});
  }

  Widget buildAttendanceActionButtons() {
    final latest =
    selectedPc == null ? null : getLatestCurrentClassAttendance(selectedPc!);

    if (!hasOngoingClass) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No ongoing class right now.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    if (latest == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'This PC has no attendance record for the current class yet.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final data = latest.data();
    final currentStatus =
    (data['teacher_attendance_status'] ?? '').toString().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _attendanceButton(
              label: 'Present',
              selected: currentStatus == 'present',
              bg: const Color(0xFFEAF3DE),
              fg: const Color(0xFF27500A),
              onTap: () => updateAttendanceStatusForSelectedPc('present'),
            ),
            _attendanceButton(
              label: 'Late',
              selected: currentStatus == 'late',
              bg: const Color(0xFFFAEEDA),
              fg: const Color(0xFF854F0B),
              onTap: () => updateAttendanceStatusForSelectedPc('late'),
            ),
            _attendanceButton(
              label: 'Absent',
              selected: currentStatus == 'absent',
              bg: const Color(0xFFFCEBEB),
              fg: const Color(0xFF791F1F),
              onTap: () => updateAttendanceStatusForSelectedPc('absent'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          currentStatus.isEmpty
              ? 'No teacher override yet.'
              : 'Teacher marked: ${currentStatus.toUpperCase()}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _attendanceButton({
    required String label,
    required bool selected,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? fg : fg.withOpacity(0.25),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }

  int get _scannedCount {
    int count = 0;
    for (int i = 1; i <= 40; i++) {
      if (isPcScannedDuringCurrentClass('PC$i')) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildLeftPanel(),
          _buildCenterGrid(),
          _buildRightPanel(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
                'LAB MAP',
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
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _nuGold.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRoom,
                dropdownColor: _nuDarkBlue,
                style: const TextStyle(
                  color: _nuGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: _nuGold,
                  size: 18,
                ),
                items: rooms
                    .map(
                      (r) => DropdownMenuItem(
                    value: r,
                    child: Text('Room $r'),
                  ),
                )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    selectedRoom = value;
                    selectedPc = null;
                    selectedPcData = null;
                    selectedPcDocId = null;
                    docsByPc.clear();
                    attendanceByPc.clear();
                    hasOngoingClass = false;
                  });
                  await refreshAll();
                  _listenToRealtimeUpdates();
                },
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(height: 3, color: _nuGold),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendancePage()),
            ),
            icon: const Icon(Icons.checklist, color: _nuGold, size: 18),
            label: const Text(
              'Attendance',
              style: TextStyle(
                color: _nuGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.07)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _panelLabel('Current Class'),
          const SizedBox(height: 10),
          _buildClassCard(),
          const SizedBox(height: 24),
          _panelLabel('Summary'),
          const SizedBox(height: 10),
          _buildStatRow(),
          const SizedBox(height: 24),
          _panelLabel('Legend'),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _panelLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.black45,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildClassCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_nuBlue, _nuDarkBlue]),
        borderRadius: BorderRadius.circular(12),
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
              'ONGOING',
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
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _classMeta(Icons.access_time, currentTimeSlot),
          const SizedBox(height: 4),
          _classMeta(Icons.group_outlined, currentSection),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room $selectedRoom',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No class ongoing',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _classMeta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: _nuGold.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow() {
    return Row(
      children: [
        _statItem(
          _scannedCount.toString(),
          'Scanned',
          const Color(0xFF3B6D11),
        ),
        const SizedBox(width: 10),
        _statItem(docsByPc.length.toString(), 'Ready', _nuDarkBlue),
      ],
    );
  }

  Widget _statItem(String val, String lab, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              lab,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        _legendItem(
          const Color(0xFFEAF3DE),
          const Color(0xFF3B6D11),
          'Scanned during class',
        ),
        const SizedBox(height: 8),
        _legendItem(
          const Color(0xFFFAEEDA),
          const Color(0xFF854F0B),
          'QR code active',
        ),
        const SizedBox(height: 8),
        _legendItem(Colors.white, Colors.black12, 'No QR generated'),
      ],
    );
  }

  Widget _legendItem(Color bg, Color border, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterGrid() {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 16, color: Colors.black38),
                const SizedBox(width: 10),
                Text(
                  'WORKSTATION LAYOUT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black45,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _LiveBadge(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 40,
                    itemBuilder: (_, i) => _buildPcBox('PC${i + 1}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPcBox(String pcName) {
    final isSelected = selectedPc == pcName;
    final qrCreated = docsByPc.containsKey(pcName.toUpperCase());
    final scanned = isPcScannedDuringCurrentClass(pcName);

    Color bg = Colors.white;
    Color border = Colors.black.withOpacity(0.08);
    Color labelColor = Colors.black54;

    if (scanned) {
      bg = const Color(0xFFEAF3DE);
      border = const Color(0xFF3B6D11);
      labelColor = const Color(0xFF27500A);
    } else if (qrCreated) {
      bg = const Color(0xFFFAEEDA);
      border = const Color(0xFFEF9F27);
      labelColor = const Color(0xFF633806);
    }

    return GestureDetector(
      onTap: () => setState(() {
        selectedPc = pcName;
        final s = docsByPc[pcName.toUpperCase()];
        selectedPcData = s?['data'] as Map<String, dynamic>?;
        selectedPcDocId = s?['docId'] as String?;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _nuGold : border,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _nuGold.withOpacity(0.3), blurRadius: 10)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              pcName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              qrCreated ? 'READY' : 'EMPTY',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: labelColor.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.black.withOpacity(0.07)),
        ),
      ),
      child: selectedPc == null ? _buildEmptyDetail() : _buildPcDetail(),
    );
  }

  Widget _buildEmptyDetail() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mouse_outlined, size: 32, color: Colors.black12),
            const SizedBox(height: 16),
            const Text(
              'Select PC',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click any workstation to view activity',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPcDetail() {
    final latest = getLatestCurrentClassAttendance(selectedPc!);
    final attData = latest?.data();
    final email = attData?['student_email']?.toString() ?? '—';
    final time = formatTimestamp(attData?['timestamp']);
    final comment = attData?['comment']?.toString() ?? '—';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          selectedPc!,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _nuDarkBlue,
          ),
        ),
        Text(
          'ROOM $selectedRoom · WORKSTATION',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),
        _detailItem(
          'Current Status',
          _statusPill(selectedPcData?['status']?.toString()),
        ),
        const SizedBox(height: 16),
        _detailItem(
          'Student Email',
          Text(
            email,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _detailItem(
          'Scanned At',
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 16),
        _detailItem(
          'Reported Issue',
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _detailItem(
          'Attendance Override',
          buildAttendanceActionButtons(),
        ),
        const SizedBox(height: 24),
        _detailItem(
          'Hardware Code',
          Text(
            selectedPcDocId ?? 'N/A',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.black38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailItem(String label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        content,
      ],
    );
  }

  Widget _statusPill(String? s) {
    final ok = s?.toLowerCase() == 'available' || s?.toLowerCase() == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s?.toUpperCase() ?? 'OFFLINE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: ok ? const Color(0xFF27500A) : const Color(0xFF791F1F),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _a = Tween(begin: 1.0, end: 0.4).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FadeTransition(
        opacity: _a,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        'LIVE SYNC',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.black38,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}