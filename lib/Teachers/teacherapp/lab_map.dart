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
  Map<String, dynamic>? selectedPcDetails;

  void onPcTap(String pcName) {
    setState(() {
      selectedPc = pcName;
      selectedPcDetails = {
        'pcName': pcName,
        'room': selectedRoom,
        'status': 'Available',
        'assignedTo': 'No student assigned',
        'condition': 'Good',
      };
    });
  }

  Widget buildPcBox(String pcName) {
    final bool isSelected = selectedPc == pcName;

    return InkWell(
      onTap: () => onPcTap(pcName),
      child: Container(
        width: 82,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4EACF) : const Color(0xFFD9D9D9),
          border: Border.all(
            color: const Color(0xFF15384D),
            width: 2,
          ),
        ),
        child: Text(
          pcName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<Widget> buildPcColumn(int start, int end) {
    List<Widget> rows = [];

    for (int i = start; i <= end; i += 5) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final pcNumber = i + index;
            return Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 14),
              child: buildPcBox('PC$pcNumber'),
            );
          }),
        ),
      );
    }

    return rows;
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
      body: SingleChildScrollView(
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
                        selectedPcDetails = null;
                      });
                    },
                  ),
                ),
              ],
            ),
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
              child: selectedPcDetails == null
                  ? const Text(
                'Click a PC box to view details.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              )
                  : Column(
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
                    'PC Name: ${selectedPcDetails!['pcName']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Room: ${selectedPcDetails!['room']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${selectedPcDetails!['status']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assigned To: ${selectedPcDetails!['assignedTo']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Condition: ${selectedPcDetails!['condition']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}