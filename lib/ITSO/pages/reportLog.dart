import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuGoldMuted = Color(0xFFE6C200);
const Color _nuWhite    = Color(0xFFF8F9FF);
const Color _nuSurface  = Color(0xFFEFF1F8);

class ReportLogPage extends StatefulWidget {
  const ReportLogPage({super.key});

  @override
  State<ReportLogPage> createState() => _ReportLogPageState();
}

class _ReportLogPageState extends State<ReportLogPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _statusFilter = 'all';
  int? _selectedMonth;
  int? _selectedYear;

  static const List<String> _monthNames = [
    '',
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear  = now.year;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d    = value.toDate();
      final hour = d.hour == 0 ? 12 : d.hour > 12 ? d.hour - 12 : d.hour;
      final min  = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '${d.month}/${d.day}/${d.year}  $hour:$min $ampm';
    }
    return 'No date';
  }

  DateTime? _extractDate(Map<String, dynamic> data) {
    for (final value in [
      data['timestamp'], data['created_at'], data['resolved_at'], data['date'],
    ]) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  bool _matchesMonthYear(Map<String, dynamic> data) {
    final date = _extractDate(data);
    if (date == null) return _selectedMonth == null && _selectedYear == null;
    if (_selectedMonth != null && date.month != _selectedMonth) return false;
    if (_selectedYear  != null && date.year  != _selectedYear)  return false;
    return true;
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    return [
      (data['lab']               ?? '').toString(),
      (data['pc']                ?? '').toString(),
      (data['pc_code']           ?? '').toString(),
      (data['comment']           ?? '').toString(),
      (data['status']            ?? '').toString(),
      (data['reported_by']       ?? '').toString(),
      (data['repaired_by']       ?? '').toString(),
      (data['action_taken']      ?? '').toString(),
      (data['final_report_text'] ?? '').toString(),
      (data['ai_attempt_summary']?? '').toString(),
      (data['ai_itso_action']    ?? '').toString(),
      ((data['ai_attempted_fix'] ?? false) == true
          ? 'yes true attempted fix'
          : 'no false no attempted fix'),
    ].any((v) => v.toLowerCase().contains(q));
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    if (_statusFilter == 'all') return true;
    return (data['status'] ?? '').toString().toLowerCase() == _statusFilter;
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': newStatus,
      if (newStatus == 'resolved') 'resolved_at': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report marked as $newStatus'),
        backgroundColor: _nuDarkBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _clearDateFilter() => setState(() {
    _selectedMonth = null;
    _selectedYear  = null;
  });

  List<int> _buildAvailableYears(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final years = <int>{};
    for (final doc in docs) {
      final date = _extractDate(doc.data());
      if (date != null) years.add(date.year);
    }
    if (years.isEmpty) years.add(DateTime.now().year);
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  // ── Detail Modal ─────────────────────────────────────────────────────────────
  void _showDetails(BuildContext context, String docId, Map<String, dynamic> data) {
    final status          = (data['status']            ?? 'unknown').toString();
    final lab             = (data['lab']               ?? '').toString();
    final pc              = (data['pc']                ?? '').toString();
    final code            = (data['pc_code']           ?? '').toString();
    final comment         = (data['comment']           ?? '').toString();
    final reportedBy      = (data['reported_by']       ?? 'Unknown').toString();
    final repairedBy      = (data['repaired_by']       ?? 'Not recorded').toString();
    final actionTaken     = (data['action_taken']      ?? 'No action recorded').toString();
    final finalReportText = (data['final_report_text'] ?? '').toString();
    final aiAttemptSummary= (data['ai_attempt_summary']?? '').toString();
    final aiAttemptedFix  = (data['ai_attempted_fix']  ?? false) == true;
    final timestamp       = _formatDate(data['timestamp'] ?? data['created_at']);
    final resolvedAt      = _formatDate(data['resolved_at']);

    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: min(580, screenWidth * 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                color: _nuDarkBlue,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Report Details',
                        style: TextStyle(
                          color: _nuWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
              ),
              // ── Gold divider ──
              Container(height: 2, color: _nuGold),
              // ── Body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailGrid(items: [
                        _DetailItem('Lab',              lab),
                        _DetailItem('PC',               pc),
                        _DetailItem('Unique Code',      code),
                        _DetailItem('Reported By',      reportedBy),
                        _DetailItem('Repaired By',      repairedBy),
                        _DetailItem('AI Attempted Fix', aiAttemptedFix ? 'Yes' : 'No'),
                        _DetailItem('Date Reported',    timestamp),
                        _DetailItem('Date Resolved',    resolvedAt),
                      ]),
                      const SizedBox(height: 20),
                      _DetailSection(
                        label: 'Issue / Comment',
                        text: comment.isEmpty ? 'No comment provided.' : comment,
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(
                        label: 'Final Report Text',
                        text: finalReportText.isEmpty
                            ? (comment.isEmpty ? 'No final report text recorded.' : comment)
                            : finalReportText,
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(
                        label: 'AI Attempt Summary',
                        text: aiAttemptSummary.isEmpty
                            ? 'No AI attempt summary recorded.'
                            : aiAttemptSummary,
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(label: 'Action Taken', text: actionTaken),
                    ],
                  ),
                ),
              ),
              // ── Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (status.toLowerCase() != 'pending')
                      _ModalTextButton(
                        label: 'Mark Pending',
                        onTap: () async {
                          Navigator.pop(context);
                          await _updateStatus(docId, 'pending');
                        },
                      ),
                    if (status.toLowerCase() != 'resolved') ...[
                      _ModalPrimaryButton(
                        label: 'Mark Resolved',
                        onTap: () async {
                          Navigator.pop(context);
                          await _updateStatus(docId, 'resolved');
                        },
                      ),
                    ],
                    _ModalTextButton(
                      label: 'Close',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Month filter chips ────────────────────────────────────────────────────────
  Widget _buildMonthFilterChips() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: List.generate(12, (index) {
        final month  = index + 1;
        final active = _selectedMonth == month;
        return GestureDetector(
          onTap: () => setState(() => _selectedMonth = month),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color:  active ? _nuDarkBlue : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? _nuDarkBlue : Colors.black12,
                width: 1.5,
              ),
            ),
            child: Text(
              _monthNames[month],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? _nuGold : Colors.black54,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 850;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _nuSurface,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _nuGold, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            // Logo ring
            Container(
              width: 38,
              height: 38,
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
            if (screenWidth > 400)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'REPORT LOG',
                    style: TextStyle(
                      color: _nuWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  if (screenWidth > 600)
                    Text(
                      'NATIONAL UNIVERSITY CLARK · ITSO',
                      style: TextStyle(
                        color: _nuGold.withOpacity(0.85),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                ],
              ),
          ],
        ),
        // Gold accent strip
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
        actions: [
          // Back button — ghost style
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 13, color: _nuGold),
              label: Text(
                screenWidth > 500 ? 'Back' : '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _nuGold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _nuGold.withOpacity(0.45), width: 1.5),
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 500 ? 14 : 8, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isNarrow ? 12 : 24),
        child: Column(
          children: [
            // ── Filter card ──────────────────────────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('reports').snapshots(),
              builder: (context, snapshot) {
                final docs           = snapshot.data?.docs.toList() ?? [];
                final availableYears = _buildAvailableYears(docs);
                if (_selectedYear != null &&
                    !availableYears.contains(_selectedYear)) {
                  _selectedYear = availableYears.isNotEmpty
                      ? availableYears.first
                      : DateTime.now().year;
                }

                return _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audit Report Search',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _nuDarkBlue,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Click a month to show only reports from that month.',
                        style: TextStyle(fontSize: 12.5, color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Year dropdown
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<int>(
                              value: _selectedYear,
                              decoration: InputDecoration(
                                labelText: 'Year',
                                labelStyle: const TextStyle(
                                  fontSize: 12, color: Colors.black45,
                                ),
                                filled: true,
                                fillColor: _nuSurface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.black.withOpacity(0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.black.withOpacity(0.1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: _nuBlue, width: 1.5),
                                ),
                              ),
                              items: availableYears
                                  .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text(
                                  y.toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _nuDarkBlue,
                                  ),
                                ),
                              ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedYear = v),
                            ),
                          ),
                          // Clear month filter
                          OutlinedButton.icon(
                            onPressed: _clearDateFilter,
                            icon: const Icon(
                                Icons.filter_alt_off_outlined, size: 16),
                            label: const Text('Clear Month Filter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _nuDarkBlue,
                              side: const BorderSide(
                                  color: _nuDarkBlue, width: 1.5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          // Active filter badge
                          if (_selectedMonth != null || _selectedYear != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7DB),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                Border.all(color: _nuGold, width: 1.5),
                              ),
                              child: Text(
                                '${_selectedMonth == null ? 'All Months' : _monthNames[_selectedMonth!]} ${_selectedYear ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _nuDarkBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildMonthFilterChips(),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // ── Search & status row ──────────────────────────────────────────
            _SurfaceCard(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search field
                  SizedBox(
                    width: isNarrow ? double.infinity : 400,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _nuSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.1), width: 1.5),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1a1a2e)),
                        decoration: InputDecoration(
                          hintText: 'Search lab, PC, code, comment…',
                          hintStyle: const TextStyle(
                              color: Colors.black38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Colors.black38),
                          border: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Status:',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _FilterChip(
                              label: 'All',
                              value: 'all',
                              current: _statusFilter,
                              onTap: (v) => setState(() => _statusFilter = v),
                            ),
                            _FilterChip(
                              label: 'Pending',
                              value: 'pending',
                              current: _statusFilter,
                              onTap: (v) => setState(() => _statusFilter = v),
                            ),
                            _FilterChip(
                              label: 'Resolved',
                              value: 'resolved',
                              current: _statusFilter,
                              onTap: (v) => setState(() => _statusFilter = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Table / List ──────────────────────────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _nuDarkBlue),
                  );
                }

                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aDate =
                        _extractDate(a.data()) ?? DateTime(2000);
                    final bDate =
                        _extractDate(b.data()) ?? DateTime(2000);
                    return bDate.compareTo(aDate);
                  });

                final filtered = docs.where((doc) {
                  final data = doc.data();
                  return _matchesSearch(data, _searchCtrl.text) &&
                      _matchesStatus(data) &&
                      _matchesMonthYear(data);
                }).toList();

                if (filtered.isEmpty) {
                  return _SurfaceCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.black26),
                            const SizedBox(height: 12),
                            Text(
                              _selectedMonth == null &&
                                  _selectedYear == null
                                  ? 'No reports found.'
                                  : 'No reports found for '
                                  '${_selectedMonth == null ? 'selected filters' : _monthNames[_selectedMonth!]}'
                                  ' ${_selectedYear ?? ''}.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.black38, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (isNarrow) {
                  // Narrow view: List of cards
                  return Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc  = filtered[index];
                          final data = doc.data();
                          return _ReportMobileCard(
                            data: data,
                            docId: doc.id,
                            formatDate: _formatDate,
                            onView: () => _showDetails(context, doc.id, data),
                            onResolve: (data['status']?.toString().toLowerCase() != 'resolved')
                                ? () => _updateStatus(doc.id, 'resolved')
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${filtered.length} report${filtered.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }

                // Wide view: Table
                return Container(
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
                            horizontal: 20, vertical: 12),
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
                            _HeaderCell(flex: 1, text: 'LAB'),
                            _HeaderCell(flex: 1, text: 'PC'),
                            _HeaderCell(flex: 2, text: 'CODE'),
                            _HeaderCell(flex: 5, text: 'FINAL REPORT / AI'),
                            _HeaderCell(flex: 2, text: 'STATUS'),
                            _HeaderCell(flex: 3, text: 'DATE REPORTED'),
                            _HeaderCell(flex: 2, text: 'ACTIONS'),
                          ],
                        ),
                      ),
                      // Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final doc  = filtered[index];
                          final data = doc.data();
                          final lab             = (data['lab']               ?? '').toString();
                          final pc              = (data['pc']                ?? '').toString();
                          final code            = (data['pc_code']           ?? '').toString();
                          final comment         = (data['comment']           ?? '').toString();
                          final finalReportText = (data['final_report_text'] ?? '').toString();
                          final aiAttemptedFix  = (data['ai_attempted_fix']  ?? false) == true;
                          final status          = (data['status']            ?? 'unknown').toString();
                          final date = _formatDate(
                              data['timestamp'] ?? data['created_at']);

                          return _TableRow(
                            key: ValueKey(doc.id),
                            lab: lab,
                            pc: pc,
                            code: code,
                            comment: finalReportText.isEmpty
                                ? (comment.isEmpty
                                ? 'No comment'
                                : comment)
                                : finalReportText,
                            aiAttemptedFix: aiAttemptedFix,
                            status: status,
                            date: date,
                            onView: () =>
                                _showDetails(context, doc.id, data),
                            onResolve: status.toLowerCase() != 'resolved'
                                ? () => _updateStatus(doc.id, 'resolved')
                                : null,
                          );
                        },
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9FAFB),
                          border: Border(
                              top: BorderSide(color: Color(0xFFE5E7EB))),
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} report${filtered.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile Card Widget ────────────────────────────────────────────────────────
class _ReportMobileCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String Function(dynamic) formatDate;
  final VoidCallback onView;
  final VoidCallback? onResolve;

  const _ReportMobileCard({
    required this.data,
    required this.docId,
    required this.formatDate,
    required this.onView,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final lab = (data['lab'] ?? '').toString();
    final pc = (data['pc'] ?? '').toString();
    final code = (data['pc_code'] ?? '').toString();
    final status = (data['status'] ?? 'unknown').toString();
    final date = formatDate(data['timestamp'] ?? data['created_at']);
    final comment = (data['final_report_text'] ?? data['comment'] ?? 'No comment').toString();
    final aiAttemptedFix = (data['ai_attempted_fix'] ?? false) == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Lab/PC + Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lab $lab - PC $pc',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _nuDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body: Comment + Date
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                _AiPill(attempted: aiAttemptedFix),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.black38),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _RowButton(label: 'View Details', outlined: true, onTap: onView),
                if (onResolve != null) ...[
                  const SizedBox(width: 8),
                  _RowButton(label: 'Resolve', outlined: false, onTap: onResolve!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared surface card ────────────────────────────────────────────────────────
class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: child,
    );
  }
}

// ── Table row ──────────────────────────────────────────────────────────────────
class _TableRow extends StatefulWidget {
  final String lab, pc, code, comment, status, date;
  final bool aiAttemptedFix;
  final VoidCallback onView;
  final VoidCallback? onResolve;

  const _TableRow({
    super.key,
    required this.lab,
    required this.pc,
    required this.code,
    required this.comment,
    required this.aiAttemptedFix,
    required this.status,
    required this.date,
    required this.onView,
    this.onResolve,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? const Color(0xFFF8FAFF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _BodyCell(flex: 1, text: widget.lab),
            _BodyCell(flex: 1, text: widget.pc),
            // Monospace code
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  widget.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF374151),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Comment + AI pill
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AiPill(attempted: widget.aiAttemptedFix),
                  ],
                ),
              ),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusBadge(status: widget.status),
              ),
            ),
            // Date
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  widget.date,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _RowButton(
                    label: 'View',
                    outlined: true,
                    onTap: widget.onView,
                  ),
                  if (widget.onResolve != null) ...[
                    const SizedBox(width: 6),
                    _RowButton(
                      label: 'Resolve',
                      outlined: false,
                      onTap: widget.onResolve!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI pill ───────────────────────────────────────────────────────────────────
class _AiPill extends StatelessWidget {
  final bool attempted;
  const _AiPill({required this.attempted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: attempted
            ? const Color(0xFFEAF3DE)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: attempted
              ? const Color(0xFF97C459)
              : const Color(0xFFD1D5DB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: attempted
                  ? const Color(0xFF639922)
                  : Colors.black26,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'AI attempted fix: ${attempted ? 'Yes' : 'No'}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: attempted
                    ? const Color(0xFF27500A)
                    : const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s          = status.isEmpty ? 'unknown' : status;
    final lower      = s.toLowerCase();
    final isPending  = lower == 'pending';
    final isResolved = lower == 'resolved';
    final bg   = isPending  ? const Color(0xFFFAEEDA)
        : isResolved ? const Color(0xFFEAF3DE)
        : const Color(0xFFF3F4F6);
    final dot  = isPending  ? const Color(0xFFEF9F27)
        : isResolved ? const Color(0xFF639922)
        : Colors.grey;
    final text = isPending  ? const Color(0xFF633806)
        : isResolved ? const Color(0xFF27500A)
        : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            s[0].toUpperCase() + s.substring(1),
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: text),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    final Color bg, border, fg;

    if (!active) {
      bg = Colors.white; border = Colors.black12; fg = Colors.black54;
    } else if (value == 'all') {
      bg = _nuDarkBlue; border = _nuDarkBlue; fg = Colors.white;
    } else if (value == 'pending') {
      bg = const Color(0xFFFAEEDA);
      border = const Color(0xFFEF9F27);
      fg = const Color(0xFF633806);
    } else {
      bg = const Color(0xFFEAF3DE);
      border = const Color(0xFF639922);
      fg = const Color(0xFF27500A);
    }

    return GestureDetector(
      onTap: () => onTap(value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }
}

// ── Row button ────────────────────────────────────────────────────────────────
class _RowButton extends StatefulWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;

  const _RowButton({
    required this.label,
    required this.outlined,
    required this.onTap,
  });

  @override
  State<_RowButton> createState() => _RowButtonState();
}

class _RowButtonState extends State<_RowButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.outlined
                ? (_h ? _nuDarkBlue : Colors.transparent)
                : (_h ? _nuBlue    : _nuDarkBlue),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _nuDarkBlue, width: 1.5),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: widget.outlined
                  ? (_h ? _nuGold : _nuDarkBlue)
                  : _nuGold,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detail grid ───────────────────────────────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final List<_DetailItem> items;
  const _DetailGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: items.map((item) {
        return SizedBox(
          width: 230,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _nuDarkBlue,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value.isEmpty ? '—' : item.value,
                style: const TextStyle(
                    fontSize: 13.5, color: Color(0xFF374151)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DetailItem {
  final String label, value;
  const _DetailItem(this.label, this.value);
}

// ── Detail section ────────────────────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final String label, text;
  const _DetailSection({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Colors.black45,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 13.5, color: Color(0xFF374151), height: 1.65),
          ),
        ),
      ],
    );
  }
}

// ── Modal buttons ─────────────────────────────────────────────────────────────
class _ModalTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ModalTextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _nuDarkBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _ModalPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ModalPrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _nuDarkBlue,
        foregroundColor: _nuGold,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Table header cell ─────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final int flex;
  final String text;
  const _HeaderCell({required this.flex, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Colors.black45,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Table body cell ───────────────────────────────────────────────────────────
class _BodyCell extends StatelessWidget {
  final int flex;
  final String text;
  final int maxLines;
  const _BodyCell({
    required this.flex,
    required this.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      ),
    );
  }
}
