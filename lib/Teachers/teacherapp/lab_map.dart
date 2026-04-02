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
        final fieldPc = (data['pc'] ?? '').toString().trim().toUpperCase();

        final bool prefixMatch = docId.startsWith(expectedPrefix);
        final bool fieldMatch =
            fieldLab == selectedRoom && fieldPc == pcName.toUpperCase();

        if (prefixMatch || fieldMatch) {
          mapped[pcName.toUpperCase()] = {
            'docId': doc.id,
            'data': data,
          };

          debugPrint(
            'MATCH FOUND -> room: $selectedRoom, pc: $pcName, docId: ${doc.id}',
          );
          break;
        }
      }
    }

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

  @override
  void initState() {
    super.initState();
    loadPcsForSelectedRoom();
  }

  void onPcTap(String pcName) {
    setState(() {
      selectedPc = pcName;

      final selected = docsByPc[pcName.toUpperCase()];
      selectedPcData = selected?['data'] as Map<String, dynamic>?;
      selectedPcDocId = selected?['docId'] as String?;
    });
  }

  Widget buildPcBox(String pcName) {
    final bool isSelected = selectedPc == pcName;

    final selected = docsByPc[pcName.toUpperCase()];
    final data = selected?['data'] as Map<String, dynamic>?;

    final bool qrCreated = data != null;

    final String reportedBy = (data?['reported_by'] ?? '').toString().trim();
    final bool studentSubmitted =
        qrCreated &&
            reportedBy.isNotEmpty &&
            reportedBy.toLowerCase() != 'teacher';

    Color boxColor = const Color(0xFFD9D9D9); // gray = no QR

    if (studentSubmitted) {
      boxColor = Colors.green; // green = student submitted
    } else if (qrCreated) {
      boxColor = Colors.yellow; // yellow = QR created
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
        item(Colors.green, 'Student submitted'),
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

    final String reportedBy = (data?['reported_by'] ?? '').toString().trim();
    final bool studentSubmitted =
        qrCreated &&
            reportedBy.isNotEmpty &&
            reportedBy.toLowerCase() != 'teacher';

    final String studentEmail = studentSubmitted ? reportedBy : 'N/A';
    final String scanTime =
    studentSubmitted ? formatTimestamp(data['updated_at']) : 'N/A';

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
        Text(
          'PC Name: $selectedPc',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Room: $selectedRoom',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'QR Code Created: ${qrCreated ? "Yes" : "No"}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'PC Code: ${selectedPcDocId ?? "N/A"}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Status: ${data?['status']?.toString() ?? "N/A"}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Student Email: $studentEmail',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Time of QR Scan / Report: $scanTime',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Comment: ${data?['comment']?.toString() ?? "N/A"}',
          style: const TextStyle(fontSize: 16),
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
        onRefresh: loadPcsForSelectedRoom,
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
                        });

                        await loadPcsForSelectedRoom();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildLegend(),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: buildPcColumn(1, 20),
                    ),
                    const SizedBox(width: 100),
                    Column(
                      children: buildPcColumn(21, 40),
                    ),
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