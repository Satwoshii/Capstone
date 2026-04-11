import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'attendance.dart';

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

  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');

      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '$hour:$minute:$second';
    }

    return timestamp.toString();
  }

  String normalizePcName(String raw) {
    final value = raw.trim().toUpperCase();

    if (value.isEmpty) return '';

    final noSpaces = value.replaceAll(' ', '');

    final match1 = RegExp(r'^PC(\d+)$').firstMatch(noSpaces);
    if (match1 != null) {
      return 'PC${match1.group(1)}';
    }

    final match2 =
    RegExp(r'PC\s*(\d+)', caseSensitive: false).firstMatch(value);
    if (match2 != null) {
      return 'PC${match2.group(1)}';
    }

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
        final docId = doc.id.trim();
        final data = doc.data();

        final fieldLab = (data['lab'] ?? '').toString().trim();
        final fieldPc = normalizePcName((data['pc'] ?? '').toString());

        final bool prefixMatch = docId.startsWith(expectedPrefix);
        final bool fieldMatch =
            fieldLab == selectedRoom && fieldPc == pcName.toUpperCase();

        if (prefixMatch || fieldMatch) {
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
      final data = doc.data();
      final timestamp = data['timestamp'];

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
      final data = doc.data();
      final timestamp = data['timestamp'];

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

  void onPcTap(String pcName) {
    setState(() {
      selectedPc = pcName;

      final selected = docsByPc[pcName.toUpperCase()];
      selectedPcData = selected?['data'] as Map<String, dynamic>?;
      selectedPcDocId = selected?['docId'] as String?;
    });
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
            'Current Class',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text('Room: $selectedRoom'),
          Text('Time: $currentTimeSlot'),
          Text('Subject: $currentSubject'),
          Text('Section: $currentSection'),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Class',
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

  Widget buildPcBox(String pcName) {
    final bool isSelected = selectedPc == pcName;

    final selected = docsByPc[pcName.toUpperCase()];
    final data = selected?['data'] as Map<String, dynamic>?;

    final bool qrCreated = data != null;
    final bool scannedThisClass = isPcScannedDuringCurrentClass(pcName);

    Color boxColor = const Color(0xFFD9D9D9);

    // ONLY green when scanned within the active uploaded class time
    if (scannedThisClass) {
      boxColor = Colors.green;
    } else if (qrCreated) {
      boxColor = Colors.yellow;
    }

    if (isSelected) {
      boxColor = boxColor.withOpacity(0.85);
    }

    return InkWell(
      onTap: () => onPcTap(pcName),
      child: Container(
        width: 82,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: boxColor,
          border: Border.all(
            color: const Color(0xFF15384D),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              pcName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              qrCreated ? 'QR' : '-',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildPcColumn(int start, int end) {
    final List<Widget> rows = [];

    for (int i = start; i <= end; i += 5) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final pcNumber = i + index;
            final pcName = 'PC$pcNumber';

            return Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 14),
              child: buildPcBox(pcName),
            );
          }),
        ),
      );
    }

    return rows;
  }

  Widget buildLegend() {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        item(const Color(0xFFD9D9D9), 'No QR yet'),
        item(Colors.yellow, 'QR created'),
        item(Colors.green, 'Scanned during class'),
      ],
    );
  }

  Widget buildPcDetails() {
    if (selectedPc == null) {
      return const Text(
        'Click a PC box to view details.',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
      );
    }

    final data = selectedPcData;
    final bool qrCreated = data != null;

    // ONLY show attendance data from the active uploaded class time
    final latestAttendance = getLatestCurrentClassAttendance(selectedPc!);
    final attendanceData = latestAttendance?.data();

    final String studentEmail = attendanceData == null
        ? 'N/A'
        : (attendanceData['student_email'] ??
        attendanceData['email'] ??
        attendanceData['studentEmail'] ??
        'N/A')
        .toString();

    final String scanTime = attendanceData == null
        ? 'N/A'
        : formatTimestamp(attendanceData['timestamp']);

    final String attendanceComment = attendanceData == null
        ? 'N/A'
        : (attendanceData['comment'] ??
        attendanceData['remarks'] ??
        attendanceData['issue'] ??
        'N/A')
        .toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PC Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text('PC Name: $selectedPc'),
        const SizedBox(height: 8),
        Text('Room: $selectedRoom'),
        const SizedBox(height: 8),
        Text('QR Code Created: ${qrCreated ? "Yes" : "No"}'),
        const SizedBox(height: 8),
        Text('PC Code: ${selectedPcDocId ?? "N/A"}'),
        const SizedBox(height: 8),
        Text('Status: ${data?['status']?.toString() ?? "N/A"}'),
        const SizedBox(height: 8),
        Text('Current Subject: ${hasOngoingClass ? currentSubject : "N/A"}'),
        const SizedBox(height: 8),
        Text('Current Section: ${hasOngoingClass ? currentSection : "N/A"}'),
        const SizedBox(height: 8),
        Text('Current Time Slot: ${hasOngoingClass ? currentTimeSlot : "N/A"}'),
        const SizedBox(height: 8),
        Text('Student Email: $studentEmail'),
        const SizedBox(height: 8),
        Text('Time of QR Scan / Report: $scanTime'),
        const SizedBox(height: 8),
        Text(
          'Comment: ${attendanceComment != "N/A" ? attendanceComment : (data?['comment']?.toString() ?? "N/A")}',
        ),
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
          'Lab Map',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF4EACF),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendancePage(),
                  ),
                );
              },
              icon: const Icon(Icons.checklist),
              label: const Text("Attendance"),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          selectedPc = null;
                          selectedPcData = null;
                          selectedPcDocId = null;
                          docsByPc.clear();
                          attendanceByPc.clear();
                          currentSubject = '';
                          currentSection = '';
                          currentTimeSlot = '';
                          currentStartTime = '';
                          currentEndTime = '';
                          hasOngoingClass = false;
                        });

                        await refreshAll();
                        _listenToRealtimeUpdates();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildCurrentClassCard(),
              const SizedBox(height: 16),
              buildLegend(),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: buildPcColumn(1, 20)),
                    const SizedBox(width: 100),
                    Column(children: buildPcColumn(21, 40)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: buildPcDetails(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}