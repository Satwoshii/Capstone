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

  void onPcTap(String pcName, Map<String, dynamic>? data, String? docId) {
    setState(() {
      selectedPc = pcName;
      selectedPcData = data;
      selectedPcDocId = docId;
    });
  }

  Widget buildPcBox(
      String pcName,
      Map<String, dynamic>? data,
      String? docId,
      ) {
    final bool isSelected = selectedPc == pcName;

    final bool qrCreated = data != null;
    final bool hasStudentSubmission =
        data != null &&
            data['reported_by'] != null &&
            data['reported_by'].toString().trim().isNotEmpty &&
            data['updated_at'] != null;

    Color boxColor = const Color(0xFFD9D9D9);

    if (hasStudentSubmission) {
      boxColor = Colors.green;
    } else if (isSelected) {
      boxColor = const Color(0xFFF4EACF);
    }

    return InkWell(
      onTap: () => onPcTap(pcName, data, docId),
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

  List<Widget> buildPcColumn(
      int start,
      int end,
      Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docsByPc,
      ) {
    List<Widget> rows = [];

    for (int i = start; i <= end; i += 5) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final pcNumber = i + index;
            final pcName = 'PC$pcNumber';

            final doc = docsByPc[pcName];
            final data = doc?.data();

            return Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 14),
              child: buildPcBox(pcName, data, doc?.id),
            );
          }),
        ),
      );
    }

    return rows;
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
    final String studentEmail =
    data?['reported_by']?.toString().trim().isNotEmpty == true
        ? data!['reported_by'].toString()
        : 'N/A';

    final String scanTime = formatTimestamp(data?['updated_at']);

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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pcs')
            .where('lab', isEqualTo: selectedRoom)
            .snapshots(),
        builder: (context, snapshot) {
          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docsByPc = {};

          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              final data = doc.data();
              final pcName = (data['pc'] ?? '').toString();
              if (pcName.isNotEmpty) {
                docsByPc[pcName] = doc;
              }
            }

            if (selectedPc != null) {
              final selectedDoc = docsByPc[selectedPc!];
              selectedPcData = selectedDoc?.data();
              selectedPcDocId = selectedDoc?.id;
            }
          }

          return SingleChildScrollView(
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
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedRoom = value;
                            selectedPc = null;
                            selectedPcData = null;
                            selectedPcDocId = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: buildPcColumn(1, 20, docsByPc),
                        ),
                        const SizedBox(width: 100),
                        Column(
                          children: buildPcColumn(21, 40, docsByPc),
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
          );
        },
      ),
    );
  }
}