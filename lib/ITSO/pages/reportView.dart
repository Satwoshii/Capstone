import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../widgets/itso_drawer.dart';
import 'pc_history.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

// ══════════════════════════════════════════════════════════════════════════════
// REPORT VIEW PAGE
// ══════════════════════════════════════════════════════════════════════════════
class ReportViewPage extends StatelessWidget {
  final String docId;
  final String lab;
  final String pcLabel;
  final String code;
  final Map<String, bool> status;
  final String comment;
  final String reportedBy;

  const ReportViewPage({
    super.key,
    required this.docId,
    required this.lab,
    required this.pcLabel,
    required this.code,
    required this.status,
    required this.comment,
    required this.reportedBy,
  });

  // ── ORIGINAL logic — untouched ─────────────────────────────────────────────
  Future<void> _deletePcCompletely(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(title: 'Delete PC'),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Delete $pcLabel in room $lab?\n\nThis will also remove related reports and incident reports.',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
              _DialogFooter(
                onCancel: () => Navigator.pop(context, false),
                onConfirm: () => Navigator.pop(context, true),
                confirmLabel: 'Delete',
                isDanger: true,
              ),
            ],
          ),
        ),
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance.collection('pcs').doc(docId).delete();

      final reportsSnap = await FirebaseFirestore.instance
          .collection('reports').where('pc_code', isEqualTo: code).get();
      for (final doc in reportsSnap.docs) await doc.reference.delete();

      final incidentSnap = await FirebaseFirestore.instance
          .collection('incident_reports').where('pc_code', isEqualTo: code).get();
      for (final doc in incidentSnap.docs) await doc.reference.delete();

      if (!context.mounted) return;
      _snack(context, '$pcLabel deleted successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Failed to delete PC: $e');
    }
  }

  void _openIncidentReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentReportPage(
          docId: docId, lab: lab, pcLabel: pcLabel, code: code,
          status: status, existingComment: comment, reportedBy: reportedBy,
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }


  Future<Map<String, dynamic>?> _loadLatestReport() async {
    try {
      final byCode = await FirebaseFirestore.instance
          .collection('reports')
          .where('pc_code', isEqualTo: code)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (byCode.docs.isNotEmpty) {
        return byCode.docs.first.data();
      }
    } catch (_) {
      // fallback below if created_at index is missing
    }

    try {
      final byCodeNoOrder = await FirebaseFirestore.instance
          .collection('reports')
          .where('pc_code', isEqualTo: code)
          .limit(20)
          .get();

      if (byCodeNoOrder.docs.isNotEmpty) {
        final docs = [...byCodeNoOrder.docs];
        docs.sort((a, b) {
          final aTs = a.data()['created_at'];
          final bTs = b.data()['created_at'];
          final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
          final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
          return bMs.compareTo(aMs);
        });
        return docs.first.data();
      }
    } catch (_) {}

    return null;
  }

  String _yesNo(bool value) => value ? 'Yes' : 'No';

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
            _AppBarLogo(),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('REPORT VIEW',
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

            // Banner
            _LabBanner(
              title: '$lab · $pcLabel',
              subtitle: 'PROBLEM REPORT · OPEN ISSUE',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE24B4A)),
                ),
                child: const Text('PROBLEM DETECTED',
                    style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),

            const SizedBox(height: 24),

            // Three-column layout
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── PC Card ─────────────────────────────────────────────────
                  SizedBox(
                    width: 180,
                    child: _NuPanel(
                      dotColor: const Color(0xFFE24B4A),
                      title: 'PC Status',
                      bgColor: const Color(0xFFFCEBEB),
                      borderColor: const Color(0xFFE24B4A),
                      borderWidth: 2,
                      child: Column(
                        children: [
                          Text(pcLabel,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _nuDarkBlue)),
                          const SizedBox(height: 10),
                          Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Center(
                              child: Icon(Icons.desktop_windows_outlined, size: 36,
                                  color: Color(0xFF991B1B)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE24B4A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Problem Detected',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // ── Peripheral Status ────────────────────────────────────────
                  SizedBox(
                    width: 260,
                    child: _NuPanel(
                      dotColor: _nuGold,
                      title: 'Peripheral Status',
                      child: Column(
                        children: status.entries.map((entry) =>
                            _PeriphRow(label: entry.key, ok: entry.value)).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // ── Details + Actions ────────────────────────────────────────
                  Expanded(
                    child: _NuPanel(
                      dotColor: const Color(0xFF185FA5),
                      title: 'Report Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoSection(label: 'ISSUE / COMMENT',
                              text: comment.isEmpty ? 'No comment provided.' : comment),
                          const SizedBox(height: 14),
                          _InfoSection(label: 'REPORTED BY',
                              text: reportedBy.isEmpty ? 'Unknown' : reportedBy),
                          const SizedBox(height: 14),
                          _InfoSection(label: 'PC CODE', text: code, mono: true),
                          const SizedBox(height: 20),

                          // Action buttons
                          _ActionBtn(
                            label: 'Make Incident Report',
                            icon: Icons.assignment_outlined,
                            bg: _nuGold, fg: _nuDarkBlue,
                            onTap: () => _openIncidentReport(context),
                          ),
                          const SizedBox(height: 8),
                          _ActionBtn(
                            label: 'View PC History',
                            icon: Icons.history,
                            bg: _nuDarkBlue, fg: _nuGold,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => PcHistoryPage(
                                    lab: lab, pcLabel: pcLabel, code: code))),
                          ),
                          const SizedBox(height: 8),
                          _ActionBtn(
                            label: 'Delete PC',
                            icon: Icons.delete_forever_outlined,
                            bg: const Color(0xFFFCEBEB),
                            fg: const Color(0xFF791F1F),
                            border: const Color(0xFFF09595),
                            onTap: () => _deletePcCompletely(context),
                          ),
                        ],
                      ),
                    ),
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

// ══════════════════════════════════════════════════════════════════════════════
// INCIDENT REPORT PAGE
// ══════════════════════════════════════════════════════════════════════════════
class IncidentReportPage extends StatefulWidget {
  final String docId, lab, pcLabel, code, existingComment, reportedBy;
  final Map<String, bool> status;

  const IncidentReportPage({
    super.key,
    required this.docId, required this.lab, required this.pcLabel,
    required this.code, required this.status,
    required this.existingComment, required this.reportedBy,
  });

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final _typeCtrl      = TextEditingController();
  final _locationCtrl  = TextEditingController();
  final _narrativeCtrl = TextEditingController();
  final _actionCtrl    = TextEditingController();
  final _repairedByCtrl= TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final broken = widget.status.entries
        .where((e) => e.value == false).map((e) => e.key).toList();
    _typeCtrl.text       = broken.isEmpty ? 'General concern' : broken.join(', ');
    _locationCtrl.text   = '${widget.lab} - ${widget.pcLabel}';
    _narrativeCtrl.text  = widget.existingComment.isEmpty
        ? 'Reported issue on ${widget.pcLabel}.'
        : widget.existingComment;
    _repairedByCtrl.text = widget.reportedBy.isEmpty ? 'ITSO Staff' : widget.reportedBy;
  }

  @override
  void dispose() {
    _typeCtrl.dispose(); _locationCtrl.dispose();
    _narrativeCtrl.dispose(); _actionCtrl.dispose(); _repairedByCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── ORIGINAL logic — untouched ─────────────────────────────────────────────
  Future<void> _writeAuditLog({required String action, required String details}) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': action, 'details': details,
      'pc': widget.pcLabel, 'pc_code': widget.code, 'lab': widget.lab,
      'user': _repairedByCtrl.text.trim().isEmpty ? 'ITSO Staff' : _repairedByCtrl.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _printPdf({required String repairedBy, required String actionTaken}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: PdfColor.fromHex('#F4C400'),
                child: pw.Text('Incident Report',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text('Type Of Incident: ${_typeCtrl.text.trim()}'),
            pw.SizedBox(height: 10),
            pw.Text('Exact Location Of Incident: ${_locationCtrl.text.trim()}'),
            pw.SizedBox(height: 10),
            pw.Text('Narrative Details Of Incident: ${_narrativeCtrl.text.trim()}'),
            pw.SizedBox(height: 10),
            pw.Text('Repaired By: $repairedBy'),
            pw.SizedBox(height: 10),
            pw.Text('Actions Taken: $actionTaken'),
            pw.SizedBox(height: 18),
            pw.Text('Lab: ${widget.lab}'),
            pw.Text('PC: ${widget.pcLabel}'),
            pw.Text('PC Code: ${widget.code}'),
          ],
        ),
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _saveIncidentReport() async {
    if (_saving) return;
    if (_typeCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty ||
        _narrativeCtrl.text.trim().isEmpty || _actionCtrl.text.trim().isEmpty ||
        _repairedByCtrl.text.trim().isEmpty) {
      _snack('Please fill in all incident report fields.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repairedBy  = _repairedByCtrl.text.trim();
      final actionTaken = _actionCtrl.text.trim();

      final reportRef = await FirebaseFirestore.instance.collection('incident_reports').add({
        'pc_doc_id': widget.docId, 'pc_code': widget.code,
        'lab': widget.lab, 'pc': widget.pcLabel,
        'reported_by': widget.reportedBy, 'repaired_by': repairedBy,
        'type_of_incident': _typeCtrl.text.trim(),
        'exact_location': _locationCtrl.text.trim(),
        'narrative_details': _narrativeCtrl.text.trim(),
        'action_taken': actionTaken,
        'peripherals': widget.status,
        'created_at': FieldValue.serverTimestamp(),
        'source': 'itso',
      });

      final matchedReports = await FirebaseFirestore.instance
          .collection('reports').where('pc_code', isEqualTo: widget.code).get();
      for (final doc in matchedReports.docs) {
        await doc.reference.update({
          'action_taken': actionTaken, 'repaired_by': repairedBy,
          'status': 'resolved', 'resolved_at': FieldValue.serverTimestamp(),
          'incident_report_id': reportRef.id,
        });
      }

      await FirebaseFirestore.instance.collection('pcs').doc(widget.docId).update({
        'peripherals': { 'keyboard': true, 'mouse': true, 'monitor': true, 'cables': true, 'system_unit': true },
        'comment': '', 'updated_at': FieldValue.serverTimestamp(),
      });

      await _writeAuditLog(
        action: 'Incident report created',
        details: 'Incident report saved and PC marked resolved.',
      );

      await _printPdf(repairedBy: repairedBy, actionTaken: actionTaken);

      if (!mounted) return;
      _snack('Incident report saved successfully.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to save incident report: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            _AppBarLogo(),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('INCIDENT REPORT',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Banner
            _LabBanner(
              title: 'Incident Report — ${widget.lab} · ${widget.pcLabel}',
              subtitle: 'FILL IN ALL FIELDS BEFORE SUBMITTING',
            ),

            const SizedBox(height: 24),

            // Form panel
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _NuPanel(
                dotColor: _nuGold,
                title: 'Incident Details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Type of incident
                    _FormSection(
                      label: 'TYPE OF INCIDENT',
                      child: SizedBox(
                        width: 320,
                        child: _FormField(controller: _typeCtrl),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location + Narrative (side by side)
                    Row(
                      children: [
                        Expanded(child: _FormSection(
                          label: 'EXACT LOCATION OF INCIDENT',
                          child: _FormField(controller: _locationCtrl),
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _FormSection(
                          label: 'NARRATIVE DETAILS OF INCIDENT',
                          child: _FormField(controller: _narrativeCtrl),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Repaired by
                    _FormSection(
                      label: 'REPAIRED BY',
                      child: SizedBox(
                        width: 320,
                        child: _FormField(controller: _repairedByCtrl),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions taken
                    _FormSection(
                      label: 'ACTIONS TAKEN',
                      child: SizedBox(
                        width: 520,
                        child: _FormField(controller: _actionCtrl, maxLines: 5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveIncidentReport,
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: Text(_saving ? 'Saving…' : 'Save & Print Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _nuDarkBlue,
                          foregroundColor: _nuGold,
                          disabledBackgroundColor: Colors.black12,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _AppBarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: Colors.white,
      border: Border.all(color: _nuGold, width: 2),
    ),
    child: ClipOval(
      child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain),
    ),
  );
}

class _LabBanner extends StatelessWidget {
  final String title, subtitle;
  final Widget? trailing;
  const _LabBanner({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF003087), Color(0xFF001A52)]),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(10), bottomRight: Radius.circular(10),
      ),
      border: const Border(left: BorderSide(color: _nuGold, width: 5)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _nuWhite, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: _nuGold.withOpacity(0.8), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500)),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _NuPanel extends StatelessWidget {
  final Color dotColor;
  final String title;
  final Widget child;
  final Color? bgColor, borderColor;
  final double borderWidth;

  const _NuPanel({
    required this.dotColor, required this.title, required this.child,
    this.bgColor, this.borderColor, this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: bgColor ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? Colors.black.withOpacity(0.07), width: borderWidth),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: bgColor != null ? bgColor!.withOpacity(0.6) : const Color(0xFFF9FAFB),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _nuDarkBlue, letterSpacing: 0.3)),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ],
    ),
  );
}

class _PeriphRow extends StatelessWidget {
  final String label;
  final bool ok;
  const _PeriphRow({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ok ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(ok ? 'OK' : 'Issue',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: ok ? const Color(0xFF27500A) : const Color(0xFF791F1F))),
        ),
      ],
    ),
  );
}

class _InfoSection extends StatelessWidget {
  final String label, text;
  final bool mono;
  const _InfoSection({required this.label, required this.text, this.mono = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8)),
      const SizedBox(height: 5),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(
          fontSize: mono ? 11 : 13,
          fontFamily: mono ? 'monospace' : null,
          color: const Color(0xFF374151),
          wordSpacing: mono ? 1 : null,
        )),
      ),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final Color? border;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label, required this.icon,
    required this.bg, required this.fg,
    required this.onTap, this.border,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: border != null ? BorderSide(color: border!) : BorderSide.none,
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLines;
  const _FormField({required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _nuDarkBlue, width: 1.5),
      ),
    ),
  );
}

class _DialogHeader extends StatelessWidget {
  final String title;
  const _DialogHeader({required this.title});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: const BoxDecoration(
      color: _nuDarkBlue,
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    child: Text(title, style: const TextStyle(color: _nuWhite, fontSize: 15, fontWeight: FontWeight.w700)),
  );
}

class _DialogFooter extends StatelessWidget {
  final VoidCallback onCancel, onConfirm;
  final String confirmLabel;
  final bool isDanger;
  const _DialogFooter({
    required this.onCancel, required this.onConfirm,
    required this.confirmLabel, this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDanger ? const Color(0xFFE24B4A) : _nuDarkBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}