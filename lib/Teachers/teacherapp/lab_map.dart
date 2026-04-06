import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'attendance.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class LabMapPage extends StatefulWidget {
  const LabMapPage({super.key});

  @override
  State<LabMapPage> createState() => _LabMapPageState();
}

class _LabMapPageState extends State<LabMapPage> {
  // ── ORIGINAL state — untouched ─────────────────────────────────────────────
  final List<String> rooms = ['706', '707', '708', '709', '710', '723'];
  String selectedRoom = '706';

  String? selectedPc;
  Map<String, dynamic>? selectedPcData;
  String? selectedPcDocId;

  final Map<String, Map<String, dynamic>> docsByPc = {};

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final dt     = timestamp.toDate();
      final hour   = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:$minute:$second';
    }
    return timestamp.toString();
  }

  Future<void> loadPcsForSelectedRoom() async {
    final allDocs = await FirebaseFirestore.instance.collection('pcs').get();
    final Map<String, Map<String, dynamic>> mapped = {};

    for (int i = 1; i <= 40; i++) {
      final pcName         = 'PC$i';
      final expectedPrefix = '$selectedRoom-$pcName-';

      for (final doc in allDocs.docs) {
        final docId    = doc.id.trim();
        final data     = doc.data();
        final fieldLab = (data['lab'] ?? '').toString().trim();
        final fieldPc  = (data['pc']  ?? '').toString().trim().toUpperCase();

        final bool prefixMatch = docId.startsWith(expectedPrefix);
        final bool fieldMatch  = fieldLab == selectedRoom &&
            fieldPc == pcName.toUpperCase();

        if (prefixMatch || fieldMatch) {
          mapped[pcName.toUpperCase()] = {'docId': doc.id, 'data': data};
          break;
        }
      }
    }

    setState(() {
      docsByPc..clear()..addAll(mapped);
      if (selectedPc != null) {
        final sel      = docsByPc[selectedPc!.toUpperCase()];
        selectedPcData = sel?['data'] as Map<String, dynamic>?;
        selectedPcDocId= sel?['docId'] as String?;
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
      selectedPc      = pcName;
      final sel       = docsByPc[pcName.toUpperCase()];
      selectedPcData  = sel?['data'] as Map<String, dynamic>?;
      selectedPcDocId = sel?['docId'] as String?;
    });
  }

  // ── PC box color logic — untouched ─────────────────────────────────────────
  Color _pcColor(String pcName) {
    final selected = docsByPc[pcName.toUpperCase()];
    final data = selected?['data'] as Map<String, dynamic>?;
    final bool qrCreated = data != null;
    final String reportedBy = (data?['reported_by'] ?? '').toString().trim();
    final bool studentSubmitted = qrCreated &&
        reportedBy.isNotEmpty &&
        reportedBy.toLowerCase() != 'teacher';

    if (studentSubmitted) return const Color(0xFFDCFCE7);  // green
    if (qrCreated)        return const Color(0xFFFEF9C3);  // yellow
    return const Color(0xFFE8EEF8);                        // gray
  }

  Color _pcBorderColor(String pcName) {
    final selected = docsByPc[pcName.toUpperCase()];
    final data = selected?['data'] as Map<String, dynamic>?;
    final bool qrCreated = data != null;
    final String reportedBy = (data?['reported_by'] ?? '').toString().trim();
    final bool studentSubmitted = qrCreated &&
        reportedBy.isNotEmpty &&
        reportedBy.toLowerCase() != 'teacher';

    if (studentSubmitted) return const Color(0xFF86EFAC);
    if (qrCreated)        return const Color(0xFFFBBF24);
    return const Color(0xFFBFCBDC);
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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _nuGold, size: 18),
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
              child: ClipOval(
                child: Image.asset(
                    'assets/Images/NUSchoolLogo.png',
                    fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('LAB MAP',
                    style: TextStyle(color: _nuWhite, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NATIONAL UNIVERSITY CLARK · FACULTY',
                    style: TextStyle(color: _nuGold.withOpacity(0.85),
                        fontSize: 9, fontWeight: FontWeight.w500,
                        letterSpacing: 2)),
              ],
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
              style: TextButton.styleFrom(
                backgroundColor: _nuGold.withOpacity(0.12),
                foregroundColor: _nuGold,
                side: BorderSide(color: _nuGold.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AttendancePage())),
              icon: const Icon(Icons.checklist, size: 16),
              label: const Text('ATTENDANCE',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: RefreshIndicator(
        onRefresh: loadPcsForSelectedRoom,
        color: _nuGold,
        backgroundColor: _nuDarkBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Left: grid + controls ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.07)),
                      ),
                      child: Row(
                        children: [
                          const Text('ROOM',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: _nuDarkBlue, letterSpacing: 0.8)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.black.withOpacity(0.12)),
                            ),
                            child: DropdownButton<String>(
                              value: selectedRoom,
                              underline: const SizedBox(),
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF374151)),
                              items: rooms
                                  .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text('Room $r')))
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() {
                                  selectedRoom    = value;
                                  selectedPc      = null;
                                  selectedPcData  = null;
                                  selectedPcDocId = null;
                                  docsByPc.clear();
                                });
                                await loadPcsForSelectedRoom();
                              },
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.refresh,
                              size: 16, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text('Pull to refresh',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black38)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Legend
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.07)),
                      ),
                      child: Row(
                        children: const [
                          _LegendItem(
                              color: Color(0xFFE8EEF8),
                              border: Color(0xFFBFCBDC),
                              label: 'No QR yet'),
                          SizedBox(width: 20),
                          _LegendItem(
                              color: Color(0xFFFEF9C3),
                              border: Color(0xFFFBBF24),
                              label: 'QR created'),
                          SizedBox(width: 20),
                          _LegendItem(
                              color: Color(0xFFDCFCE7),
                              border: Color(0xFF86EFAC),
                              label: 'Student submitted'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PC grid
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.07)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPcColumn(1, 20),
                            const SizedBox(width: 32),
                            _buildPcColumn(21, 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // ── Right: detail panel ────────────────────────────────────
              SizedBox(
                width: 280,
                child: _buildDetailPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PC grid column ─────────────────────────────────────────────────────────
  Widget _buildPcColumn(int start, int end) {
    final List<Widget> rows = [];
    for (int i = start; i <= end; i += 5) {
      rows.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (idx) {
          final pcName = 'PC${i + idx}';
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 10),
            child: _buildPcBox(pcName),
          );
        }),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildPcBox(String pcName) {
    final bool isSelected = selectedPc == pcName;
    final bg     = _pcColor(pcName);
    final border = _pcBorderColor(pcName);
    final data   = (docsByPc[pcName.toUpperCase()]?['data'])
    as Map<String, dynamic>?;
    final bool qrCreated = data != null;

    return GestureDetector(
      onTap: () => onPcTap(pcName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 74, height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _nuGold : border,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
              color: _nuGold.withOpacity(0.25),
              blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pcName,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
            const SizedBox(height: 3),
            Text(qrCreated ? 'QR' : '—',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  // ── Detail panel ───────────────────────────────────────────────────────────
  Widget _buildDetailPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: _nuGold, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('PC Details',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _nuDarkBlue, letterSpacing: 0.3)),
              ],
            ),
          ),
          selectedPc == null
              ? const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.mouse_outlined,
                    size: 36, color: Colors.black12),
                SizedBox(height: 10),
                Text('Click a PC box to view details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.black38)),
              ],
            ),
          )
              : _buildDetailBody(),
        ],
      ),
    );
  }

  Widget _buildDetailBody() {
    final data    = selectedPcData;
    final bool qrCreated = data != null;
    final String reportedBy = (data?['reported_by'] ?? '').toString().trim();
    final bool studentSubmitted = qrCreated &&
        reportedBy.isNotEmpty &&
        reportedBy.toLowerCase() != 'teacher';

    final String studentEmail = studentSubmitted ? reportedBy : 'N/A';
    final String scanTime     = studentSubmitted
        ? formatTimestamp(data['updated_at'])
        : 'N/A';
    final String status = (data?['status'] ?? 'N/A').toString();
    final String comment= (data?['comment'] ?? 'N/A').toString();
    final String pcCode = selectedPcDocId ?? 'N/A';

    final bool isAvailable =
        status.toLowerCase() == 'available';

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'PC NAME',
              value: selectedPc ?? ''),
          _DetailRow(label: 'ROOM',
              value: selectedRoom),
          _DetailRow(label: 'QR CODE CREATED',
              value: qrCreated ? 'Yes' : 'No'),
          _DetailRowMono(label: 'PC CODE', value: pcCode),
          _DetailRowStatus(label: 'STATUS', status: status,
              isAvailable: isAvailable),
          _DetailRow(label: 'STUDENT EMAIL',
              value: studentEmail),
          _DetailRow(label: 'TIME OF QR SCAN',
              value: scanTime),
          _DetailRow(label: 'COMMENT',
              value: comment.isEmpty ? 'N/A' : comment,
              multiline: true),
        ],
      ),
    );
  }
}

// ── Detail row widgets ────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool multiline;
  const _DetailRow({
    required this.label, required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.black45, letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF374151),
                fontWeight: FontWeight.w500),
            maxLines: multiline ? 3 : 1,
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _DetailRowMono extends StatelessWidget {
  final String label, value;
  const _DetailRowMono({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.black45, letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: Color(0xFF374151)),
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _DetailRowStatus extends StatelessWidget {
  final String label, status;
  final bool isAvailable;
  const _DetailRowStatus({
    required this.label, required this.status,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.black45, letterSpacing: 0.8)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable
                ? const Color(0xFFEAF3DE)
                : const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(status,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isAvailable
                      ? const Color(0xFF27500A)
                      : const Color(0xFF791F1F))),
        ),
      ],
    ),
  );
}

// ── Legend item ───────────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color, border;
  final String label;
  const _LegendItem({
    required this.color, required this.border,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: border, width: 1.5),
        ),
      ),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: Colors.black54)),
    ],
  );
}