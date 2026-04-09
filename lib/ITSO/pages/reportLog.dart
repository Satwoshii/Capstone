import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class ReportLogPage extends StatefulWidget {
  const ReportLogPage({super.key});

  @override
  State<ReportLogPage> createState() => _ReportLogPageState();
}

class _ReportLogPageState extends State<ReportLogPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
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

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    return [
      (data['lab']         ?? '').toString(),
      (data['pc']          ?? '').toString(),
      (data['pc_code']     ?? '').toString(),
      (data['comment']     ?? '').toString(),
      (data['status']      ?? '').toString(),
      (data['reported_by'] ?? '').toString(),
      (data['repaired_by'] ?? '').toString(),
      (data['action_taken']?? '').toString(),
      (data['final_report_text'] ?? '').toString(),
      (data['ai_attempt_summary'] ?? '').toString(),
      (data['ai_student_tip'] ?? '').toString(),
      (data['ai_itso_action'] ?? '').toString(),
      ((data['ai_attempted_fix'] ?? false) == true ? 'yes true attempted fix' : 'no false no attempted fix'),
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

  void _showDetails(BuildContext context, String docId, Map<String, dynamic> data) {
    final status     = (data['status']      ?? 'unknown').toString();
    final lab        = (data['lab']         ?? '').toString();
    final pc         = (data['pc']          ?? '').toString();
    final code       = (data['pc_code']     ?? '').toString();
    final comment    = (data['comment']     ?? '').toString();
    final reportedBy = (data['reported_by'] ?? 'Unknown').toString();
    final repairedBy = (data['repaired_by'] ?? 'Not recorded').toString();
    final actionTaken= (data['action_taken']?? 'No action recorded').toString();
    final finalReportText = (data['final_report_text'] ?? '').toString();
    final aiAttemptSummary = (data['ai_attempt_summary'] ?? '').toString();
    final aiAttemptedFix = (data['ai_attempted_fix'] ?? false) == true;
    final timestamp  = _formatDate(data['timestamp']);
    final resolvedAt = _formatDate(data['resolved_at']);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                color: _nuDarkBlue,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Report Details',
                        style: TextStyle(color: _nuWhite, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
              ),

              // ── Modal body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailGrid(items: [
                        _DetailItem('Lab',          lab),
                        _DetailItem('PC',           pc),
                        _DetailItem('Unique Code',  code),
                        _DetailItem('Reported By',  reportedBy),
                        _DetailItem('Repaired By',  repairedBy),
                        _DetailItem('AI Attempted Fix', aiAttemptedFix ? 'Yes' : 'No'),
                        _DetailItem('Date Reported',timestamp),
                        _DetailItem('Date Resolved',resolvedAt),
                      ]),
                      const SizedBox(height: 20),
                      _DetailSection(label: 'Issue / Comment', text: comment.isEmpty ? 'No comment provided.' : comment),
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
                        text: aiAttemptSummary.isEmpty ? 'No AI attempt summary recorded.' : aiAttemptSummary,
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(label: 'Action Taken', text: actionTaken),
                    ],
                  ),
                ),
              ),

              // ── Modal footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                      const SizedBox(width: 8),
                      _ModalPrimaryButton(
                        label: 'Mark Resolved',
                        onTap: () async {
                          Navigator.pop(context);
                          await _updateStatus(docId, 'resolved');
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: const ItsoDrawer(),

      // ── AppBar ──────────────────────────────────────────────────────────────
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
            Container(
              width: 38, height: 38,
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
                  'REPORT LOG',
                  style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
                Text(
                  'NATIONAL UNIVERSITY CLARK · ITSO',
                  style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [

            // ── Toolbar ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search lab, PC, code, comment…',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black38),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () { _searchCtrl.clear(); setState(() {}); },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status filter chips
                  Text('Status:', style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'All',      value: 'all',      current: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Pending',  value: 'pending',  current: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Resolved', value: 'resolved', current: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Table ────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('reports').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: _nuDarkBlue));
                  }

                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aTs = a.data()['timestamp'];
                      final bTs = b.data()['timestamp'];
                      final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(2000);
                      final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(2000);
                      return bDate.compareTo(aDate);
                    });

                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    return _matchesSearch(data, _searchCtrl.text) && _matchesStatus(data);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
                          const SizedBox(height: 12),
                          const Text('No reports found.', style: TextStyle(color: Colors.black38, fontSize: 15)),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.07)),
                    ),
                    child: Column(
                      children: [
                        // ── Header row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                          child: Row(
                            children: const [
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

                        // ── Data rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            itemBuilder: (context, index) {
                              final doc    = filtered[index];
                              final data   = doc.data();
                              final lab    = (data['lab']      ?? '').toString();
                              final pc     = (data['pc']       ?? '').toString();
                              final code   = (data['pc_code']  ?? '').toString();
                              final comment= (data['comment']  ?? '').toString();
                              final finalReportText = (data['final_report_text'] ?? '').toString();
                              final aiAttemptedFix = (data['ai_attempted_fix'] ?? false) == true;
                              final status = (data['status']   ?? 'unknown').toString();
                              final date   = _formatDate(data['timestamp']);

                              return _TableRow(
                                key: ValueKey(doc.id),
                                lab:     lab,
                                pc:      pc,
                                code:    code,
                                comment: finalReportText.isEmpty
                                    ? (comment.isEmpty ? 'No comment' : comment)
                                    : finalReportText,
                                aiAttemptedFix: aiAttemptedFix,
                                status:  status,
                                date:    date,
                                onView:  () => _showDetails(context, doc.id, data),
                                onResolve: status.toLowerCase() != 'resolved'
                                    ? () => _updateStatus(doc.id, 'resolved')
                                    : null,
                              );
                            },
                          ),
                        ),

                        // ── Footer count
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${filtered.length} report${filtered.length != 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table Row ─────────────────────────────────────────────────────────────────
class _TableRow extends StatefulWidget {
  final String lab, pc, code, comment, status, date;
  final bool aiAttemptedFix;
  final VoidCallback onView;
  final VoidCallback? onResolve;

  const _TableRow({
    super.key,
    required this.lab, required this.pc, required this.code,
    required this.comment, required this.aiAttemptedFix, required this.status, required this.date,
    required this.onView, this.onResolve,
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
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  widget.code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
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
                      style: const TextStyle(fontSize: 13, color: Color(0xFF111827), height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.aiAttemptedFix ? const Color(0xFFEAF3DE) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.aiAttemptedFix ? const Color(0xFF97C459) : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        'AI attempted fix: ' + (widget.aiAttemptedFix ? 'Yes' : 'No'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.aiAttemptedFix ? const Color(0xFF27500A) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusBadge(status: widget.status),
              ),
            ),
            _BodyCell(flex: 3, text: widget.date),
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

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPending  = status.toLowerCase() == 'pending';
    final isResolved = status.toLowerCase() == 'resolved';
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label, required this.value,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    Color bg, border, fg;
    if (!active) {
      bg = Colors.white; border = Colors.black12; fg = Colors.black54;
    } else if (value == 'all') {
      bg = _nuDarkBlue; border = _nuDarkBlue; fg = Colors.white;
    } else if (value == 'pending') {
      bg = const Color(0xFFFAEEDA); border = const Color(0xFFEF9F27); fg = const Color(0xFF633806);
    } else {
      bg = const Color(0xFFEAF3DE); border = const Color(0xFF639922); fg = const Color(0xFF27500A);
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
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ),
      ),
    );
  }
}

// ── Row Button ────────────────────────────────────────────────────────────────
class _RowButton extends StatefulWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;
  const _RowButton({required this.label, required this.outlined, required this.onTap});

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
                ? (_h ? _nuDarkBlue : Colors.white.withOpacity(0))
                : (_h ? _nuBlue    : _nuDarkBlue),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _nuDarkBlue, width: 1.5),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.outlined
                  ? (_h ? _nuGold  : _nuDarkBlue)
                  : _nuGold,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modal helpers ─────────────────────────────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final List<_DetailItem> items;
  const _DetailGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: items.map((item) => SizedBox(
        width: 230,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            children: [
              TextSpan(text: '${item.label}:  ', style: const TextStyle(fontWeight: FontWeight.w700, color: _nuDarkBlue)),
              TextSpan(text: item.value.isEmpty ? '—' : item.value),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _DetailItem {
  final String label, value;
  const _DetailItem(this.label, this.value);
}

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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.6)),
        ),
      ],
    );
  }
}

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
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Table cell helpers ────────────────────────────────────────────────────────
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
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final int flex;
  final String text;
  final int maxLines;
  const _BodyCell({required this.flex, required this.text, this.maxLines = 1});

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
