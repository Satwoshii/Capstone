import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class PcHistoryPage extends StatelessWidget {
  final String lab;
  final String pcLabel;
  final String code;

  const PcHistoryPage({
    super.key,
    required this.lab,
    required this.pcLabel,
    required this.code,
  });

  // ── ORIGINAL logic — untouched ─────────────────────────────────────────────
  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }
    return 'No date';
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: const ItsoDrawer(),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _nuGold, size: 26),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: _nuGold, width: 2),
              ),
              child: ClipOval(
                child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('PC HISTORY',
                    style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NATIONAL UNIVERSITY CLARK · ITSO',
                    style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2)),
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
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Banner ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF003087), Color(0xFF001A52)]),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: const Border(left: BorderSide(color: _nuGold, width: 5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$lab · $pcLabel',
                          style: const TextStyle(
                              color: _nuWhite, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text('REPAIR & INCIDENT HISTORY',
                          style: TextStyle(
                              color: _nuGold.withOpacity(0.8),
                              fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  // PC code badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _nuGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _nuGold.withOpacity(0.35)),
                    ),
                    child: Text(code,
                        style: const TextStyle(
                            color: _nuGold, fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── History Table ─────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .where('pc_code', isEqualTo: code)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: _nuDarkBlue));
                  }

                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aTs = a.data()['timestamp'];
                      final bTs = b.data()['timestamp'];
                      final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(2000);
                      final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(2000);
                      return bDate.compareTo(aDate);
                    });

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 56, color: Colors.black12),
                          const SizedBox(height: 12),
                          const Text('No history records found for this PC.',
                              style: TextStyle(color: Colors.black38, fontSize: 15)),
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
                        // ── Table header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 13),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius:
                            BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                          child: const Row(
                            children: [
                              _HeaderCell(flex: 2, text: 'DATE REPORTED'),
                              _HeaderCell(flex: 2, text: 'REPAIRED BY'),
                              _HeaderCell(flex: 4, text: 'REPORTED ISSUE'),
                              _HeaderCell(flex: 4, text: 'ACTION TAKEN'),
                            ],
                          ),
                        ),

                        // ── Table rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final date       = _formatDate(data['timestamp']);
                              final repairedBy = (data['repaired_by']  ?? 'Not recorded').toString();
                              final issue      = (data['comment']       ?? 'No issue recorded').toString();
                              final action     = (data['action_taken']  ?? 'No action recorded').toString();
                              final status     = (data['status']        ?? '').toString().toLowerCase();

                              return _HistoryRow(
                                date:       date,
                                repairedBy: repairedBy,
                                issue:      issue,
                                action:     action,
                                status:     status,
                              );
                            },
                          ),
                        ),

                        // ── Footer count
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
                                '${docs.length} record${docs.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w500),
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

// ── History Row ───────────────────────────────────────────────────────────────
class _HistoryRow extends StatefulWidget {
  final String date, repairedBy, issue, action, status;
  const _HistoryRow({
    required this.date, required this.repairedBy,
    required this.issue, required this.action, required this.status,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? const Color(0xFFFAFBFF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Date
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.calendar_today_outlined,
                        size: 13, color: _nuDarkBlue),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.date,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                ],
              ),
            ),

            // Repaired by
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(widget.repairedBy,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ),

            // Issue
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(widget.issue,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ),

            // Action taken
            Expanded(
              flex: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(widget.action,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 10),
                  // Status badge
                  _StatusBadge(status: widget.status),
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
    final isResolved = status == 'resolved';
    final isPending  = status == 'pending';

    final bg   = isResolved ? const Color(0xFFEAF3DE)
        : isPending  ? const Color(0xFFFAEEDA)
        : const Color(0xFFF3F4F6);
    final dot  = isResolved ? const Color(0xFF639922)
        : isPending  ? const Color(0xFFEF9F27)
        : Colors.grey;
    final fg   = isResolved ? const Color(0xFF27500A)
        : isPending  ? const Color(0xFF633806)
        : Colors.black54;
    final label= isResolved ? 'Resolved'
        : isPending  ? 'Pending'
        : status.isEmpty ? '—' : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
        ],
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