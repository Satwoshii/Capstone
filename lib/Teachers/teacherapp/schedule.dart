import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final List<String> rooms = ['706', '707', '708', '709', '710', '723'];

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

  String selectedRoom = '706';
  String? selectedFileName;
  bool isImporting = false;
  bool isLoading = true;

  Map<String, Map<String, String>> scheduleMap = {};

  @override
  void initState() {
    super.initState();
    loadScheduleForRoom();
  }

  String makeKey(String day, String timeSlot) => '${day}_$timeSlot';

  DateTime? parseTimeOnly(String value) {
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

  Future<void> loadScheduleForRoom() async {
    setState(() {
      isLoading = true;
    });

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

      setState(() {
        scheduleMap = loaded;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load schedule: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String cellText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String> extractCellLines(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
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

      for (final slot in timeSlots) {
        sheet.appendRow([
          ex.TextCellValue(slot),
          ...List.generate(days.length, (_) => ex.TextCellValue('')),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to generate template');
      }

      if (kIsWeb) {
        final uint8List = Uint8List.fromList(bytes);
        final base64Data = base64Encode(uint8List);

        html.AnchorElement(
          href:
          'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64Data',
        )
          ..download = 'schedule_template.xlsx'
          ..click();
      } else {
        throw Exception('Template export is currently set up for web only.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule template exported successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template export failed: $e')),
      );
    }
  }

  Future<void> importExcelFile() async {
    try {
      setState(() {
        isImporting = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          isImporting = false;
        });
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

      final oldDocs = await FirebaseFirestore.instance
          .collection('schedules')
          .where('room', isEqualTo: selectedRoom)
          .get();

      final deleteBatch = FirebaseFirestore.instance.batch();
      for (final doc in oldDocs.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      final List<Map<String, dynamic>> parsedEntries = [];

      for (int row = 1; row <= timeSlots.length; row++) {
        final rowTime = cellText(
          sheet
              .cell(
            ex.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: row,
            ),
          )
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
          if (lines.length > 1) section = lines[1];
          if (lines.length > 2) fullTime = lines[2];

          if (subject.isEmpty) continue;

          String startTime;
          String endTime;

          if (fullTime.isNotEmpty && fullTime.contains(' - ')) {
            final parts = fullTime.split(' - ');
            startTime = parts.first.trim();
            endTime = parts.last.trim();
          } else {
            final parts = rowTime.split(' - ');
            startTime = parts.first.trim();
            endTime = parts.last.trim();
            fullTime = rowTime;
          }

          parsedEntries.add({
            'room': selectedRoom,
            'day': day,
            'start_time': startTime,
            'end_time': endTime,
            'time_slot': '$startTime - $endTime',
            'subject': subject,
            'section': section,
            'source_file': file.name,
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      }

      // Remove duplicates after parsing
      final unique = <String, Map<String, dynamic>>{};
      for (final entry in parsedEntries) {
        final key =
            '${entry['room']}_${entry['day']}_${entry['start_time']}_${entry['end_time']}_${entry['subject']}_${entry['section']}';
        unique[key] = entry;
      }

      final saveBatch = FirebaseFirestore.instance.batch();
      for (final entry in unique.values) {
        final docRef =
        FirebaseFirestore.instance.collection('schedules').doc();
        saveBatch.set(docRef, entry);
      }

      await saveBatch.commit();

      if (!mounted) return;

      setState(() {
        selectedFileName = file.name;
      });

      await loadScheduleForRoom();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unique.isEmpty
                ? 'File imported, but no schedule entries were detected.'
                : 'Imported ${unique.length} schedule entries for Room $selectedRoom.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import file: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isImporting = false;
        });
      }
    }
  }

  Future<void> showManageScheduleDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 700,
            height: 500,
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Manage Schedule'),
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await showScheduleFormDialog();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Schedule'),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('schedules')
                        .where('room', isEqualTo: selectedRoom)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No schedule entries yet.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();

                          final day = (data['day'] ?? '').toString();
                          final subject = (data['subject'] ?? '').toString();
                          final section = (data['section'] ?? '').toString();
                          final timeSlot = (data['time_slot'] ?? '').toString();

                          return ListTile(
                            title: Text('$subject ${section.isNotEmpty ? "- $section" : ""}'),
                            subtitle: Text('$day | $timeSlot'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
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
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('schedules')
                                        .doc(doc.id)
                                        .delete();
                                  },
                                ),
                              ],
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
        );
      },
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
    final sectionCtrl = TextEditingController(text: initialSection ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(docId == null ? 'Add Schedule' : 'Edit Schedule'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: days
                      .map((day) => DropdownMenuItem(
                    value: day,
                    child: Text(day),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) selectedDay = value;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Start Time (e.g. 1:00 PM)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  decoration: const InputDecoration(
                    labelText: 'End Time (e.g. 2:00 PM)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(labelText: 'Section'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final start = startCtrl.text.trim();
                final end = endCtrl.text.trim();
                final subject = subjectCtrl.text.trim();
                final section = sectionCtrl.text.trim();

                if (start.isEmpty || end.isEmpty || subject.isEmpty) return;

                final data = {
                  'room': selectedRoom,
                  'day': selectedDay,
                  'start_time': start,
                  'end_time': end,
                  'time_slot': '$start - $end',
                  'subject': subject,
                  'section': section,
                  'source_file': docId == null ? 'manual_add' : 'manual_edit',
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

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      docId == null
                          ? 'Schedule added successfully'
                          : 'Schedule updated successfully',
                    ),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget buildRoomDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(10),
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

          await loadScheduleForRoom();
        },
      ),
    );
  }

  Widget buildImportButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF2C300),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: isImporting ? null : importExcelFile,
      icon: const Icon(Icons.upload_file),
      label: Text(
        isImporting ? 'Importing...' : 'Import Excel File',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildTemplateButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDBEAFE),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: exportScheduleTemplate,
      icon: const Icon(Icons.download),
      label: const Text(
        'Export Schedule Template',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildEditButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDDF4D7),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: showManageScheduleDialog,
      icon: const Icon(Icons.edit_calendar),
      label: const Text(
        'Edit Sched',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildCell(String day, String timeSlot) {
    final entry = scheduleMap[makeKey(day, timeSlot)];
    final subject = entry?['subject'] ?? '';
    final section = entry?['section'] ?? '';
    final classTime = entry?['class_time'] ?? '';

    return Container(
      width: 160,
      height: 60,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: subject.isEmpty && section.isEmpty
            ? Colors.white
            : const Color(0xFFF8F3D6),
        border: Border.all(color: Colors.black26),
      ),
      child: Center(
        child: (subject.isEmpty && section.isEmpty)
            ? const SizedBox()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              subject,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (section.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                section,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ],
            if (classTime.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                classTime,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildTimetable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 140,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E9F3),
                  border: Border.all(color: Colors.black26),
                ),
                child: const Text(
                  'Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...days.map((day) {
                return Container(
                  width: 160,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E9F3),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
          ),
          ...timeSlots.map((timeSlot) {
            return Row(
              children: [
                Container(
                  width: 140,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      timeSlot,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ...days.map((day) => buildCell(day, timeSlot)),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E5A97),
        title: const Text(
          'Schedule',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Room:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      buildRoomDropdown(),
                    ],
                  ),
                  buildImportButton(),
                  buildTemplateButton(),
                  buildEditButton(),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectedFileName == null
                      ? 'No file imported yet.'
                      : 'Imported file: $selectedFileName',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: buildTimetable(),
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
}