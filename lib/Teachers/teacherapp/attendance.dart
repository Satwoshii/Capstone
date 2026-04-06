import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  Map<String, Map<String, dynamic>> groupAttendanceByEmail(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final doc in docs) {
      final data  = doc.data();
      final email = (data['student_email'] ?? '').toString().trim();
      if (email.isEmpty) continue;

      if (!grouped.containsKey(email)) {
        grouped[email] = {'present': 0.0, 'late': 0.0, 'dates': <String>[]};
      }

      grouped[email]!['present'] +=
          (data['present'] as num?)?.toDouble() ?? 0.0;
      grouped[email]!['late'] +=
          (data['late'] as num?)?.toDouble() ?? 0.0;

      final date = (data['date'] ?? '').toString().trim();
      if (date.isNotEmpty) {
        final dates = grouped[email]!['dates'] as List<String>;
        if (!dates.contains(date)) dates.add(date);
      }
    }
    return grouped;
  }

  Future<void> exportToExcel(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    try {
      final grouped = groupAttendanceByEmail(docs);
      final excel   = ex.Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet   = excel[sheetName];

      sheet.appendRow(
          ['Email', 'Present', 'Late', 'Attendance Score', 'Date Scanned']);

      for (final entry in grouped.entries) {
        final email   = entry.key;
        final present = entry.value['present'] as double;
        final late    = entry.value['late'] as double;
        final score   = present + late;
        final dates   = (entry.value['dates'] as List<String>).join(', ');
        sheet.appendRow([email, present.toString(), late.toString(),
          score.toString(), dates]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      if (kIsWeb) {
        final uint8List  = Uint8List.fromList(bytes);
        final base64Data = base64Encode(uint8List);
        html.AnchorElement(
          href: 'data:application/vnd.openxmlformats-officedocument'
              '.spreadsheetml.sheet;base64,$base64Data',
        )
          ..download = 'attendance.xlsx'
          ..click();
      } else {
        throw Exception(
            'This export code is currently set up for web only.');
      }

      if (!mounted) return;
      _snack('Excel exported successfully', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Export failed: $e');
    }
  }

  void showAttendanceDates(
      BuildContext context,
      String email,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final userDocs =
    docs.where((d) => (d.data()['student_email'] ?? '') == email).toList();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 16),
                decoration: const BoxDecoration(
                  color: _nuDarkBlue,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance Dates',
                        style: TextStyle(
                            color: _nuWhite, fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(email,
                        style: TextStyle(
                            color: _nuGold.withOpacity(0.8),
                            fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // Date list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: userDocs.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No attendance records found.',
                      style: TextStyle(color: Colors.black38)),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: userDocs.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1,
                      color: Color(0xFFF3F4F6)),
                  itemBuilder: (_, i) {
                    final data  = userDocs[i].data();
                    final date  = (data['date'] ?? 'No date').toString();
                    final present = (data['present'] as num?)
                        ?.toDouble() ??
                        0.0;
                    final late =
                        (data['late'] as num?)?.toDouble() ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF8),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.calendar_today_outlined,
                                size: 15, color: _nuDarkBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(date,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                        FontWeight.w600,
                                        color:
                                        Color(0xFF374151))),
                                Text(
                                    'Present: $present  ·  Late: $late',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black45)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _nuDarkBlue,
                      side: BorderSide(
                          color: Colors.black.withOpacity(0.15)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isSuccess ? const Color(0xFF3B6D11) : _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ));
  }

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
                const Text('ATTENDANCE',
                    style: TextStyle(color: _nuWhite, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NATIONAL UNIVERSITY CLARK · FACULTY',
                    style: TextStyle(
                        color: _nuGold.withOpacity(0.85),
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
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _nuDarkBlue),
            );
          }

          final docs    = snapshot.data!.docs;
          final grouped = groupAttendanceByEmail(docs);
          final emails  = grouped.keys.toList();

          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Toolbar ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.black.withOpacity(0.07)),
                  ),
                  child: Row(
                    children: [
                      // Record count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline,
                                size: 15, color: _nuDarkBlue),
                            const SizedBox(width: 6),
                            Text('${emails.length} student${emails.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _nuDarkBlue)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Export button
                      ElevatedButton.icon(
                        onPressed: () => exportToExcel(docs),
                        icon: const Icon(Icons.download_outlined,
                            size: 16),
                        label: const Text('Export Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _nuDarkBlue,
                          foregroundColor: _nuGold,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Table ──────────────────────────────────────────────
                Expanded(
                  child: emails.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 52, color: Colors.black12),
                        const SizedBox(height: 12),
                        const Text(
                            'No attendance records yet.',
                            style: TextStyle(
                                fontSize: 15,
                                color: Colors.black38)),
                      ],
                    ),
                  )
                      : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.black.withOpacity(0.07)),
                    ),
                    child: Column(
                      children: [

                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 13),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12)),
                            border: Border(
                                bottom: BorderSide(
                                    color: Color(0xFFE5E7EB))),
                          ),
                          child: const Row(
                            children: [
                              _HeaderCell(flex: 4, text: 'EMAIL'),
                              _HeaderCell(flex: 1,
                                  text: 'PRESENT'),
                              _HeaderCell(flex: 1, text: 'LATE'),
                              _HeaderCell(flex: 2,
                                  text: 'SCORE'),
                              _HeaderCell(flex: 2,
                                  text: 'ACTIONS'),
                            ],
                          ),
                        ),

                        // Table rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: emails.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1,
                                color: Color(0xFFF3F4F6)),
                            itemBuilder: (context, index) {
                              final email   = emails[index];
                              final present = grouped[email]![
                              'present'] as double;
                              final late    = grouped[email]![
                              'late'] as double;
                              final score   = present + late;

                              return _AttendanceRow(
                                email:   email,
                                present: present,
                                late:    late,
                                score:   score,
                                onDetails: () =>
                                    showAttendanceDates(
                                        context, email, docs),
                              );
                            },
                          ),
                        ),

                        // Footer
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            border: Border(
                                top: BorderSide(
                                    color: Color(0xFFE5E7EB))),
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12)),
                          ),
                          child: Text(
                              '${emails.length} record${emails.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Attendance Row ────────────────────────────────────────────────────────────
class _AttendanceRow extends StatefulWidget {
  final String email;
  final double present, late, score;
  final VoidCallback onDetails;

  const _AttendanceRow({
    required this.email, required this.present,
    required this.late, required this.score,
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
        : const Color(0xFF791F1F);
    final scoreBg = widget.score >= 1.0
        ? const Color(0xFFEAF3DE)
        : const Color(0xFFFCEBEB);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered
            ? const Color(0xFFF8FAFF)
            : Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Email
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
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
                            color: _nuDarkBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.email,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151)),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

            // Present
            Expanded(
              flex: 1,
              child: Text(widget.present.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
            ),

            // Late
            Expanded(
              flex: 1,
              child: Text(widget.late.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
            ),

            // Score badge - FIXED WIDTH & ALIGNMENT
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      color: scoreBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scoreColor.withOpacity(0.2))
                  ),
                  child: Text(widget.score.toStringAsFixed(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: scoreColor)),
                ),
              ),
            ),

            // Details button - ALIGNED
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _DetailsBtn(onTap: widget.onDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Details button ────────────────────────────────────────────────────────────
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
      onExit:  (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _h ? _nuDarkBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _h
                  ? _nuDarkBlue
                  : Colors.black.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Text('Details',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _h ? _nuGold : _nuDarkBlue)),
        ),
      ),
    );
  }
}

// ── Header Cell ───────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final int flex;
  final String text;
  const _HeaderCell({required this.flex, required this.text});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.black45, letterSpacing: 0.8)),
  );
}
