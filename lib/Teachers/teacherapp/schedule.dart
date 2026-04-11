import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // ── ORIGINAL state — untouched ─────────────────────────────────────────────
  final List<String> rooms = ['706', '707', '708', '709', '710', '723'];

  final List<String> days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  final List<String> timeSlots = [
    '7:00 AM - 7:20 AM',  '7:20 AM - 7:40 AM',  '7:40 AM - 8:00 AM',
    '8:00 AM - 8:20 AM',  '8:20 AM - 8:40 AM',  '8:40 AM - 9:00 AM',
    '9:00 AM - 9:20 AM',  '9:20 AM - 9:40 AM',  '9:40 AM - 10:00 AM',
    '10:00 AM - 10:20 AM','10:20 AM - 10:40 AM','10:40 AM - 11:00 AM',
    '11:00 AM - 11:20 AM','11:20 AM - 11:40 AM','11:40 AM - 12:00 PM',
    '12:00 PM - 12:20 PM','12:20 PM - 12:40 PM','12:40 PM - 1:00 PM',
    '1:00 PM - 1:20 PM',  '1:20 PM - 1:40 PM',  '1:40 PM - 2:00 PM',
    '2:00 PM - 2:20 PM',  '2:20 PM - 2:40 PM',  '2:40 PM - 3:00 PM',
    '3:00 PM - 3:20 PM',  '3:20 PM - 3:40 PM',  '3:40 PM - 4:00 PM',
    '4:00 PM - 4:20 PM',  '4:20 PM - 4:40 PM',  '4:40 PM - 5:00 PM',
    '5:00 PM - 5:20 PM',  '5:20 PM - 5:40 PM',  '5:40 PM - 6:00 PM',
    '6:00 PM - 6:20 PM',  '6:20 PM - 6:40 PM',  '6:40 PM - 7:00 PM',
    '7:00 PM - 7:20 PM',  '7:20 PM - 7:40 PM',  '7:40 PM - 8:00 PM',
    '8:00 PM - 8:20 PM',  '8:20 PM - 8:40 PM',  '8:40 PM - 9:00 PM',
  ];

  String  selectedRoom     = '706';
  String? selectedFileName;
  bool    isImporting      = false;
  bool    isLoading        = true;

  // key = "Monday_7:00 AM - 7:20 AM"
  Map<String, Map<String, String>> scheduleMap = {};

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    loadScheduleForRoom();
  }

  String makeKey(String day, String timeSlot) => '${day}_$timeSlot';

  DateTime? parseTimeOnly(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$', caseSensitive: false)
        .firstMatch(normalized);
    if (match == null) return null;
    int hour       = int.parse(match.group(1)!);
    final minute   = int.parse(match.group(2)!);
    final period   = match.group(3)!.toUpperCase();
    if (period == 'AM') { if (hour == 12) hour = 0; }
    else                { if (hour != 12) hour += 12; }
    return DateTime(2000, 1, 1, hour, minute);
  }

  bool slotOverlapsClass({
    required String cellSlot, required String classStart, required String classEnd,
  }) {
    final parts = cellSlot.split(' - ');
    if (parts.length != 2) return false;
    final cellStart = parseTimeOnly(parts[0]);
    final cellEnd   = parseTimeOnly(parts[1]);
    final clsStart  = parseTimeOnly(classStart);
    final clsEnd    = parseTimeOnly(classEnd);
    if (cellStart == null || cellEnd == null || clsStart == null || clsEnd == null) return false;
    return cellStart.isBefore(clsEnd) && cellEnd.isAfter(clsStart);
  }

  String normalizeTimeLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split('-');
    if (parts.length != 2) return trimmed;
    String formatPart(String value, {required bool isEnd}) {
      final bits = value.trim().split(':');
      if (bits.length != 2) return value.trim();
      int hour = int.tryParse(bits[0]) ?? 0;
      final minute = bits[1];
      String period = 'AM';
      if (hour == 12) period = 'PM';
      else if (hour >= 1 && hour <= 6) period = 'PM';
      else if (hour >= 7 && hour <= 11) period = 'AM';
      return '$hour:$minute $period';
    }
    return '${formatPart(parts[0], isEnd: false)} - ${formatPart(parts[1], isEnd: true)}';
  }

  Future<void> loadScheduleForRoom() async {
    setState(() => isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('schedules')
          .where('room', isEqualTo: selectedRoom)
          .get();
      final Map<String, Map<String, String>> loaded = {};
      for (final doc in query.docs) {
        final data      = doc.data();
        final day       = (data['day']        ?? '').toString().trim();
        final startTime = (data['start_time'] ?? '').toString().trim();
        final endTime   = (data['end_time']   ?? '').toString().trim();
        final subject   = (data['subject']    ?? '').toString().trim();
        final section   = (data['section']    ?? '').toString().trim();
        if (day.isEmpty || startTime.isEmpty || endTime.isEmpty) continue;
        final fullClassTime = '$startTime - $endTime';
        for (final slot in timeSlots) {
          if (slotOverlapsClass(cellSlot: slot, classStart: startTime, classEnd: endTime)) {
            loaded[makeKey(day, slot)] = {
              'subject': subject, 'section': section, 'class_time': fullClassTime,
            };
          }
        }
      }
      if (!mounted) return;
      setState(() => scheduleMap = loaded);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to load schedule: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String cellText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  bool isIgnorableCell(String text) {
    final upper = text.toUpperCase();
    return text.isEmpty || upper == 'LUNCH BREAK' || upper == 'TOTAL HOURS' ||
        upper == 'TIME' || upper == 'MONDAY' || upper == 'TUESDAY' ||
        upper == 'WEDNESDAY' || upper == 'THURSDAY' || upper == 'FRIDAY' ||
        upper == 'SATURDAY';
  }

  Future<void> importExcelFile() async {
    try {
      setState(() => isImporting = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true,
      );
      if (result == null || result.files.isEmpty) { setState(() => isImporting = false); return; }
      final file  = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('No file data found.');
      final excel     = ex.Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet     = excel.tables[sheetName];
      if (sheet == null) throw Exception('No sheet found in the Excel file.');

      final oldDocs = await FirebaseFirestore.instance.collection('schedules').where('room', isEqualTo: selectedRoom).get();
      final deleteBatch = FirebaseFirestore.instance.batch();
      for (final doc in oldDocs.docs) deleteBatch.delete(doc.reference);
      await deleteBatch.commit();

      const int firstTimeRow = 23, lastTimeRow = 64, firstDayCol = 2, lastDayCol = 7;
      final List<Map<String, dynamic>> parsedEntries = [];

      for (int col = firstDayCol; col <= lastDayCol; col++) {
        final day = days[col - firstDayCol];
        int row   = firstTimeRow;
        while (row <= lastTimeRow) {
          final rawTime         = cellText(sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1)).value);
          final currentCellText = cellText(sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col - 1, rowIndex: row - 1)).value);
          if (rawTime.isEmpty || isIgnorableCell(currentCellText)) { row++; continue; }
          final subject = currentCellText;
          String section = '';
          int endRow = row;
          if (row + 1 <= lastTimeRow) {
            final nextCellText = cellText(sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col - 1, rowIndex: row)).value);
            if (!isIgnorableCell(nextCellText)) { section = nextCellText; endRow = row + 1; }
          }
          final startRawTime   = cellText(sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1)).value);
          final endRawTime     = cellText(sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: endRow - 1)).value);
          final normalizedStart = normalizeTimeLabel(startRawTime);
          final normalizedEnd   = normalizeTimeLabel(endRawTime);
          final startLabel = normalizedStart.split(' - ').first;
          final endLabel   = normalizedEnd.split(' - ').last;
          parsedEntries.add({
            'room': selectedRoom, 'day': day, 'start_time': startLabel, 'end_time': endLabel,
            'time_slot': '$startLabel - $endLabel', 'subject': subject, 'section': section,
            'source_file': file.name, 'created_at': FieldValue.serverTimestamp(),
          });
          row = endRow + 1;
        }
      }

      final saveBatch = FirebaseFirestore.instance.batch();
      for (final entry in parsedEntries) {
        saveBatch.set(FirebaseFirestore.instance.collection('schedules').doc(), entry);
      }
      await saveBatch.commit();
      if (!mounted) return;
      setState(() => selectedFileName = file.name);
      await loadScheduleForRoom();
      if (!mounted) return;
      _snack(parsedEntries.isEmpty
          ? 'File imported, but no schedule entries were detected.'
          : 'Imported ${parsedEntries.length} schedule entries for Room $selectedRoom.',
          isSuccess: parsedEntries.isNotEmpty);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to import file: $e');
    } finally {
      if (mounted) setState(() => isImporting = false);
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

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: _nuGold, width: 2)),
            child: ClipOval(child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('SCHEDULE', style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('NATIONAL UNIVERSITY CLARK · FACULTY',
                style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 2)),
          ]),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Toolbar ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.07)),
                ),
                child: Row(children: [
                  // Room label + dropdown
                  const Text('ROOM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _nuDarkBlue, letterSpacing: 0.8)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withOpacity(0.12)),
                    ),
                    child: DropdownButton<String>(
                      value: selectedRoom,
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      items: rooms.map((r) =>
                          DropdownMenuItem(value: r, child: Text('Room $r'))).toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() { selectedRoom = value; });
                        await loadScheduleForRoom();
                      },
                    ),
                  ),
                  const Spacer(),
                  // Import button
                  ElevatedButton.icon(
                    onPressed: isImporting ? null : importExcelFile,
                    icon: isImporting
                        ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(color: _nuGold, strokeWidth: 2))
                        : const Icon(Icons.upload_file_outlined, size: 16),
                    label: Text(isImporting ? 'Importing…' : 'Import Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _nuDarkBlue,
                      foregroundColor: _nuGold,
                      disabledBackgroundColor: Colors.black.withOpacity(0.08),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── File status ──────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: selectedFileName == null
                    ? _NoFileBar(key: const ValueKey('none'))
                    : _FileBar(key: const ValueKey('file'), fileName: selectedFileName!),
              ),

              const SizedBox(height: 16),

              // ── Timetable ────────────────────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: _nuDarkBlue))
                    : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.07)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: _buildTimetable(),
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

  // ── Timetable ──────────────────────────────────────────────────────────────
  Widget _buildTimetable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            _TimeHeader(),
            ...days.map((day) => _DayHeader(day: day)),
          ]),
          // Data rows
          ...timeSlots.map((slot) => Row(children: [
            _TimeCell(slot: slot),
            ...days.map((day) => _buildCell(day, slot)),
          ])),
        ],
      ),
    );
  }

  Widget _buildCell(String day, String timeSlot) {
    final entry    = scheduleMap[makeKey(day, timeSlot)];
    final subject  = entry?['subject']    ?? '';
    final section  = entry?['section']    ?? '';
    final classTime= entry?['class_time'] ?? '';
    final isEmpty  = subject.isEmpty && section.isEmpty;

    return Container(
      width: 152,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.white : const Color(0xFFFFF7E0),
        border: Border(
          right:  BorderSide(color: Colors.black.withOpacity(0.08)),
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: isEmpty
          ? const SizedBox()
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(subject,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF001A52))),
        if (section.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(section,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
        ],
        if (classTime.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(classTime,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Colors.black.withOpacity(0.45))),
        ],
      ]),
    );
  }
}

// ── Timetable header cells ────────────────────────────────────────────────────
class _TimeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 130, height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _nuDarkBlue,
      border: Border(
        right:  BorderSide(color: _nuGold.withOpacity(0.3)),
        bottom: BorderSide(color: _nuGold.withOpacity(0.3)),
      ),
    ),
    child: const Text('TIME',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFFFFD700), letterSpacing: 1)),
  );
}

class _DayHeader extends StatelessWidget {
  final String day;
  const _DayHeader({required this.day});

  @override
  Widget build(BuildContext context) => Container(
    width: 152, height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _nuDarkBlue,
      border: Border(
        right:  BorderSide(color: _nuGold.withOpacity(0.3)),
        bottom: BorderSide(color: _nuGold.withOpacity(0.3)),
      ),
    ),
    child: Text(day,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: _nuWhite, letterSpacing: 0.5)),
  );
}

class _TimeCell extends StatelessWidget {
  final String slot;
  const _TimeCell({required this.slot});

  @override
  Widget build(BuildContext context) => Container(
    width: 130, height: 58,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F8),
      border: Border(
        right:  BorderSide(color: Colors.black.withOpacity(0.1)),
        bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
    ),
    child: Text(slot,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: Color(0xFF374151))),
  );
}

// ── File status bars ──────────────────────────────────────────────────────────
class _NoFileBar extends StatelessWidget {
  const _NoFileBar({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black.withOpacity(0.08)),
    ),
    child: Row(children: [
      Icon(Icons.insert_drive_file_outlined, size: 15, color: Colors.black38),
      const SizedBox(width: 8),
      const Text('No file imported yet.',
          style: TextStyle(fontSize: 12, color: Colors.black38)),
    ]),
  );
}

class _FileBar extends StatelessWidget {
  final String fileName;
  const _FileBar({super.key, required this.fileName});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3DE),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF97C459)),
    ),
    child: Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF3B6D11).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF3B6D11)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('File imported',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: Color(0xFF3B6D11), letterSpacing: 0.5)),
        Text(fileName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF27500A)),
            overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}