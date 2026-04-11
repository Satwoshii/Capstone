import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../widgets/itso_drawer.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class QrManagementPage extends StatefulWidget {
  const QrManagementPage({super.key});

  @override
  State<QrManagementPage> createState() => _QrManagementPageState();
}

class _QrManagementPageState extends State<QrManagementPage> {
  final _scaffoldKey  = GlobalKey<ScaffoldState>();
  final _pcCtrl       = TextEditingController();
  final _bulkCtrl     = TextEditingController();

  String? _selectedLab;
  String? _qrData;
  String? _uniqueCode;
  String? _pcLabel;
  String? _logoDataUrlCache;

  bool _loadingNext     = false;
  bool _saving          = false;
  bool _bulkGenerating  = false;
  bool _bulkPrinting    = false;

  final Set<String> _expandedRooms = {};

  @override
  void dispose() {
    _pcCtrl.dispose();
    _bulkCtrl.dispose();
    super.dispose();
  }

  // ── Helpers (ALL ORIGINAL — UNTOUCHED) ──────────────────────────────────────
  int _extractPcNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }

  String _generateUniqueCode(String lab, String pc) {
    final rand = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(16)
        .substring(8)
        .toUpperCase();
    return "$lab-PC$pc-$rand";
  }

  String _buildQrUrl(String code) =>
      "https://test-1fc5d.web.app/scan?code=$code";

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<void> _nextPc() async {
    final lab = _selectedLab;
    if (lab == null || lab.isEmpty) { _snack('Please select a room first'); return; }
    setState(() => _loadingNext = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pcs').where('lab', isEqualTo: lab).get();
      int highest = 0;
      for (final doc in snapshot.docs) {
        final num = _extractPcNumber((doc.data()['pc'] ?? '').toString());
        if (num > highest) highest = num;
      }
      _pcCtrl.text = '${highest + 1}';
    } catch (e) {
      _snack('Failed to get next PC number: $e');
    } finally {
      if (mounted) setState(() => _loadingNext = false);
    }
  }

  Future<void> _generatePreview() async {
    final app = AppStateScope.of(context);
    final lab = _selectedLab ?? '';
    final pc  = _pcCtrl.text.trim();
    if (lab.isEmpty)  { _snack('Please select a Lab Room'); return; }
    if (pc.isEmpty || int.tryParse(pc) == null || int.parse(pc) <= 0) {
      _snack('Enter a valid PC number'); return;
    }
    if (!app.isValidLab(lab)) { _snack('Invalid Lab Room'); return; }
    final uniqueCode = _generateUniqueCode(lab, pc);
    setState(() { _pcLabel = 'PC $pc'; _uniqueCode = uniqueCode; _qrData = _buildQrUrl(uniqueCode); });
  }

  Future<void> _saveSingleQr() async {
    final app = AppStateScope.of(context);
    final lab = _selectedLab ?? '';
    final pc  = _pcCtrl.text.trim();
    if (lab.isEmpty)  { _snack('Please select a Lab Room'); return; }
    if (pc.isEmpty || int.tryParse(pc) == null || int.parse(pc) <= 0) {
      _snack('Enter a valid PC number'); return;
    }
    if (!app.isValidLab(lab)) { _snack('Invalid Lab Room'); return; }
    setState(() => _saving = true);
    try {
      final existingPc = await FirebaseFirestore.instance
          .collection('pcs')
          .where('lab', isEqualTo: lab)
          .where('pc', isEqualTo: 'PC $pc')
          .get();
      if (existingPc.docs.isNotEmpty) {
        final d = existingPc.docs.first.data();
        final existingCode    = (d['code']    ?? '').toString();
        final existingQrData  = (d['qr_data'] ?? '').toString();
        setState(() {
          _pcLabel    = 'PC $pc';
          _uniqueCode = existingCode;
          _qrData     = existingQrData.isNotEmpty ? existingQrData : _buildQrUrl(existingCode);
        });
        _snack('PC $pc already exists in $lab');
        return;
      }
      final uniqueCode = _generateUniqueCode(lab, pc);
      final url        = _buildQrUrl(uniqueCode);
      await FirebaseFirestore.instance.collection('pcs').doc(uniqueCode).set({
        'lab': lab, 'pc': 'PC $pc', 'code': uniqueCode, 'qr_data': url,
        'status': 'available', 'comment': '', 'reported_by': '',
        'reported_by_name': '', 'reported_by_email': '',
        'created_at': Timestamp.now(), 'updated_at': FieldValue.serverTimestamp(),
        'peripherals': { 'keyboard': true, 'mouse': true, 'monitor': true, 'cables': true, 'system_unit': true },
      });
      setState(() { _pcLabel = 'PC $pc'; _uniqueCode = uniqueCode; _qrData = url; });
      _snack('QR generated and saved successfully');
    } catch (e) {
      _snack('Failed to save QR: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateAllForLab() async {
    final app   = AppStateScope.of(context);
    final lab   = _selectedLab ?? '';
    final count = int.tryParse(_bulkCtrl.text.trim());
    if (lab.isEmpty)             { _snack('Please select a Lab Room'); return; }
    if (!app.isValidLab(lab))    { _snack('Invalid Lab Room'); return; }
    if (count == null || count <= 0) { _snack('Enter a valid total PC count'); return; }
    setState(() => _bulkGenerating = true);
    try {
      final existingSnapshot = await FirebaseFirestore.instance
          .collection('pcs').where('lab', isEqualTo: lab).get();
      final existingPcLabels = existingSnapshot.docs
          .map((doc) => (doc.data()['pc'] ?? '').toString()).toSet();
      final batch = FirebaseFirestore.instance.batch();
      int createdCount = 0;
      for (int i = 1; i <= count; i++) {
        final pcLabel = 'PC $i';
        if (existingPcLabels.contains(pcLabel)) continue;
        final uniqueCode = _generateUniqueCode(lab, '$i');
        final url        = _buildQrUrl(uniqueCode);
        final docRef     = FirebaseFirestore.instance.collection('pcs').doc(uniqueCode);
        batch.set(docRef, {
          'lab': lab, 'pc': pcLabel, 'code': uniqueCode, 'qr_data': url,
          'status': 'available', 'comment': '', 'reported_by': '',
          'reported_by_name': '', 'reported_by_email': '',
          'created_at': Timestamp.now(), 'updated_at': FieldValue.serverTimestamp(),
          'peripherals': { 'keyboard': true, 'mouse': true, 'monitor': true, 'cables': true, 'system_unit': true },
        });
        createdCount++;
      }
      if (createdCount > 0) await batch.commit();
      if (!mounted) return;
      _snack(createdCount == 0
          ? 'All PCs already exist in room $lab'
          : 'Generated $createdCount new QR codes for room $lab');
    } catch (e) {
      _snack('Failed to generate all QRs: $e');
    } finally {
      if (mounted) setState(() => _bulkGenerating = false);
    }
  }

  Future<String> _loadLogoDataUrl() async {
    if (_logoDataUrlCache != null) return _logoDataUrlCache!;
    for (final path in ['assets/Image/NUSchoolLogo.png', 'assets/Images/NUSchoolLogo.png', 'assets/Images/nu_logo.png']) {
      try {
        final bytes = await rootBundle.load(path);
        final b64   = base64Encode(bytes.buffer.asUint8List());
        _logoDataUrlCache = 'data:image/png;base64,$b64';
        return _logoDataUrlCache!;
      } catch (_) {}
    }
    _logoDataUrlCache = '';
    return _logoDataUrlCache!;
  }

  Future<String> _qrToBase64(String data) async {
    final painter = QrPainter(
      data: data, version: QrVersions.auto, gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );
    final picData = await painter.toImageData(800, format: ui.ImageByteFormat.png);
    if (picData == null) throw Exception('Failed to render QR image');
    return 'data:image/png;base64,${base64Encode(Uint8List.view(picData.buffer))}';
  }

  Future<void> _printSingleQr() async {
    if (_qrData == null) return;
    final qrBase64   = await _qrToBase64(_qrData!);
    final logoDataUrl= await _loadLogoDataUrl();
    final logoHtml   = logoDataUrl.isEmpty ? '' :
    '<div class="logo-bg"></div><img class="logo" src="$logoDataUrl">';
    final htmlContent = '''<!DOCTYPE html><html><head><meta charset="utf-8"><title>Print QR</title>
<style>body{margin:0;display:flex;align-items:center;justify-content:center;height:100vh;background:white;font-family:Arial,sans-serif}
.wrap{text-align:center}.frame{padding:24px;border:24px solid #FFD700;display:inline-block;background:white}
.qrwrap{position:relative}.qr{width:512px;height:512px;display:block}
.logo-bg{position:absolute;top:50%;left:50%;width:120px;height:120px;transform:translate(-50%,-50%);background:white;border-radius:12px}
.logo{position:absolute;top:50%;left:50%;width:96px;height:96px;transform:translate(-50%,-50%)}
.meta{margin-top:14px;font-weight:bold}.code{margin-top:6px;font-size:14px}</style></head>
<body><div class="wrap"><div class="frame"><div class="qrwrap"><img class="qr" src="$qrBase64">$logoHtml</div></div>
<div class="meta">${_selectedLab ?? ''} - ${_pcLabel ?? ''}</div>
<div class="code">${_uniqueCode ?? ''}</div></div>
<script>window.onload=function(){setTimeout(function(){window.print();},300)};window.onafterprint=function(){window.close()}</script>
</body></html>''';
    final pageUrl = html.Url.createObjectUrlFromBlob(html.Blob([htmlContent], 'text/html'));
    html.window.open(pageUrl, '_blank');
  }

  Future<void> _bulkPrint() async {
    final lab = _selectedLab;
    if (lab == null || lab.isEmpty) { _snack('Please select a room'); return; }
    setState(() => _bulkPrinting = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pcs').where('lab', isEqualTo: lab).get();
      final docs = snapshot.docs.toList()
        ..sort((a, b) => _extractPcNumber((a.data()['pc'] ?? '').toString())
            .compareTo(_extractPcNumber((b.data()['pc'] ?? '').toString())));
      if (docs.isEmpty) { _snack('No saved QRs in this room'); return; }
      final logoDataUrl = await _loadLogoDataUrl();
      final cards = <String>[];
      for (final doc in docs) {
        final data    = doc.data();
        final qrData  = (data['qr_data'] ?? '').toString();
        final code    = (data['code']    ?? '').toString();
        final room    = (data['lab']     ?? '').toString();
        final pc      = (data['pc']      ?? '').toString();
        if (qrData.isEmpty) continue;
        final qrBase64 = await _qrToBase64(qrData);
        final logoHtml = logoDataUrl.isEmpty ? '' :
        '<div class="logo-bg"></div><img class="logo" src="$logoDataUrl">';
        cards.add('<div class="card"><div class="frame"><div class="qrwrap"><img class="qr" src="$qrBase64">$logoHtml</div></div><div class="meta">$room - $pc</div><div class="code">$code</div></div>');
      }
      final htmlContent = '''<!DOCTYPE html><html><head><meta charset="utf-8"><title>Bulk Print</title>
<style>body{font-family:Arial,sans-serif;padding:20px;background:white}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}
.card{border:1px solid #ccc;padding:12px;text-align:center;break-inside:avoid;page-break-inside:avoid}
.frame{padding:12px;border:12px solid #FFD700;display:inline-block;background:white}
.qrwrap{position:relative}.qr{width:180px;height:180px;display:block}
.logo-bg{position:absolute;top:50%;left:50%;width:44px;height:44px;transform:translate(-50%,-50%);background:white;border-radius:8px}
.logo{position:absolute;top:50%;left:50%;width:34px;height:34px;transform:translate(-50%,-50%)}
.meta{margin-top:8px;font-weight:bold}.code{font-size:12px;margin-top:4px;word-break:break-word}</style></head>
<body><div class="grid">${cards.join()}</div>
<script>window.onload=function(){setTimeout(function(){window.print();},300)}</script></body></html>''';
      final blob = html.Blob([htmlContent], 'text/html');
      html.window.open(html.Url.createObjectUrlFromBlob(blob), '_blank');
    } catch (e) {
      _snack('Failed to bulk print: $e');
    } finally {
      if (mounted) setState(() => _bulkPrinting = false);
    }
  }

  Future<void> _deletePcCompletely({
    required String docId, required String lab,
    required String pcLabel, required String code,
  }) async {
    final confirmed = await _confirmDialog(
      title: 'Delete PC',
      message: 'Delete $pcLabel in room $lab?\n\nThis will also remove related reports and incident reports.',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      await FirebaseFirestore.instance.collection('pcs').doc(docId).delete();
      for (final col in ['reports', 'incident_reports']) {
        final snap = await FirebaseFirestore.instance
            .collection(col).where('pc_code', isEqualTo: code).get();
        for (final doc in snap.docs) await doc.reference.delete();
      }
      if (!mounted) return;
      if (_uniqueCode == code) setState(() { _pcCtrl.clear(); _pcLabel = null; _uniqueCode = null; _qrData = null; });
      _snack('$pcLabel deleted successfully');
    } catch (e) {
      _snack('Failed to delete PC: $e');
    }
  }

  Future<void> _deleteAllInRoom() async {
    final lab = _selectedLab;
    if (lab == null || lab.isEmpty) { _snack('Select a room first'); return; }
    final confirmed = await _confirmDialog(
      title: 'Delete All PCs',
      message: 'Delete ALL PCs in room $lab?\n\nThis will also delete related reports and incident reports.\n\nThis cannot be undone.',
      confirmLabel: 'Delete All',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      final pcSnap = await FirebaseFirestore.instance
          .collection('pcs').where('lab', isEqualTo: lab).get();
      if (pcSnap.docs.isEmpty) { _snack('No PCs found in room $lab'); return; }
      final codes = pcSnap.docs.map((doc) => (doc.data()['code'] ?? doc.id).toString()).toList();
      for (final doc in pcSnap.docs) await doc.reference.delete();
      for (final code in codes) {
        for (final col in ['reports', 'incident_reports']) {
          final snap = await FirebaseFirestore.instance
              .collection(col).where('pc_code', isEqualTo: code).get();
          for (final doc in snap.docs) await doc.reference.delete();
        }
      }
      if (!mounted) return;
      setState(() { _pcCtrl.clear(); _bulkCtrl.clear(); _pcLabel = null; _uniqueCode = null; _qrData = null; });
      _snack('All PCs in room $lab deleted successfully');
    } catch (e) {
      _snack('Failed to delete all PCs: $e');
    }
  }

  Future<bool> _confirmDialog({
    required String title, required String message,
    required String confirmLabel, bool isDanger = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: _nuDarkBlue,
                width: double.infinity,
                child: Text(title, style: const TextStyle(color: _nuWhite, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, style: const TextStyle(fontSize: 14, height: 1.6)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDanger ? const Color(0xFFE24B4A) : _nuDarkBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  void _loadSavedQr(Map<String, dynamic> data) {
    final pcLabel  = (data['pc'] ?? '').toString();
    final pcNumber = _extractPcNumber(pcLabel);
    setState(() {
      _selectedLab = (data['lab']     ?? '').toString();
      _pcCtrl.text = pcNumber > 0 ? '$pcNumber' : '';
      _pcLabel     = pcLabel;
      _uniqueCode  = (data['code']    ?? '').toString();
      _qrData      = (data['qr_data'] ?? '').toString();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);

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
                const Text('QR MANAGEMENT',
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── LEFT COLUMN: Controls ─────────────────────────────────────────
            SizedBox(
              width: 280,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Single QR panel
                    _NuPanel(
                      dotColor: _nuGold,
                      title: 'Single QR Generator',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('LAB ROOM'),
                          DropdownButtonFormField<String>(
                            value: app.labs.contains(_selectedLab) ? _selectedLab : null,
                            items: app.labs.map((lab) =>
                                DropdownMenuItem(value: lab, child: Text(lab))).toList(),
                            onChanged: (v) => setState(() => _selectedLab = v),
                            decoration: _inputDeco(),
                          ),
                          const SizedBox(height: 14),
                          _FieldLabel('PC NUMBER'),
                          TextField(
                            controller: _pcCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco(hint: 'e.g. 12'),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _OutlineBtn(
                                label: _loadingNext ? 'Loading…' : 'Next PC',
                                onTap: _loadingNext ? null : _nextPc,
                                icon: Icons.skip_next,
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: _GoldBtn(
                                label: 'Preview',
                                onTap: _generatePreview,
                                icon: Icons.qr_code,
                              )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _DangerBtn(
                            label: 'Delete All in Room',
                            onTap: _selectedLab == null ? null : _deleteAllInRoom,
                            icon: Icons.delete_forever_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bulk panel
                    _NuPanel(
                      dotColor: const Color(0xFFE24B4A),
                      title: 'Bulk Generator',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('TOTAL PCs IN LAB'),
                          TextField(
                            controller: _bulkCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco(hint: 'e.g. 40'),
                          ),
                          const SizedBox(height: 14),
                          _NavyBtn(
                            label: _bulkGenerating ? 'Generating…' : 'Generate All QRs',
                            onTap: _bulkGenerating ? null : _generateAllForLab,
                            icon: Icons.auto_awesome_outlined,
                          ),
                          const SizedBox(height: 6),
                          _OutlineBtn(
                            label: _bulkPrinting ? 'Preparing…' : 'Bulk Print',
                            onTap: _bulkPrinting ? null : _bulkPrint,
                            icon: Icons.print_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20),

            // ── CENTER: QR Preview ────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _NuPanel(
                dotColor: const Color(0xFF639922),
                title: 'QR Preview',
                child: _qrData == null
                    ? SizedBox(
                  height: 360,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2, size: 56, color: Colors.black12),
                        const SizedBox(height: 12),
                        const Text('Generate or load a QR to preview',
                            style: TextStyle(color: Colors.black38, fontSize: 14)),
                      ],
                    ),
                  ),
                )
                    : Column(
                  children: [
                    // Unique code badge
                    if (_uniqueCode != null) ...[
                      const SizedBox(height: 8),
                      _SectionLabel('UNIQUE CODE'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _uniqueCode!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            letterSpacing: 1.5, color: _nuDarkBlue,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // QR frame
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: _nuGold, width: 16),
                          color: Colors.white,
                        ),
                        child: QrImageView(
                          data: _qrData!,
                          size: 260,
                          embeddedImage: const AssetImage('assets/Images/NUSchoolLogo.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(56, 56)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Labels
                    Text(
                      '${_selectedLab ?? ''} · ${_pcLabel ?? ''}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _nuDarkBlue),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _qrData!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NavyBtn(
                          label: _saving ? 'Saving…' : 'Save QR',
                          onTap: _saving ? null : _saveSingleQr,
                          icon: Icons.save_outlined,
                          fullWidth: false,
                        ),
                        const SizedBox(width: 12),
                        _NavyBtn(
                          label: 'Print QR',
                          onTap: _printSingleQr,
                          icon: Icons.print_outlined,
                          fullWidth: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20),

            // ── RIGHT COLUMN: Saved QRs ───────────────────────────────────────
            SizedBox(
              width: 320,
              child: _NuPanel(
                dotColor: const Color(0xFF185FA5),
                title: 'Saved QR Codes by Room',
                child: SizedBox(
                  height: 580,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: _nuDarkBlue));
                      }

                      final docs = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final labCmp = (a.data()['lab'] ?? '').toString()
                              .compareTo((b.data()['lab'] ?? '').toString());
                          if (labCmp != 0) return labCmp;
                          return _extractPcNumber((a.data()['pc'] ?? '').toString())
                              .compareTo(_extractPcNumber((b.data()['pc'] ?? '').toString()));
                        });

                      if (docs.isEmpty) {
                        return const Center(
                            child: Text('No saved QR codes yet',
                                style: TextStyle(color: Colors.black38)));
                      }

                      // Group by lab
                      final grouped = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                      for (final doc in docs) {
                        final lab = (doc.data()['lab'] ?? 'Unknown Room').toString();
                        grouped.putIfAbsent(lab, () => []).add(doc);
                      }
                      final roomNames = grouped.keys.toList()..sort();

                      return ListView.builder(
                        itemCount: roomNames.length,
                        itemBuilder: (context, i) {
                          final room     = roomNames[i];
                          final roomDocs = grouped[room]!
                            ..sort((a, b) => _extractPcNumber((a.data()['pc'] ?? '').toString())
                                .compareTo(_extractPcNumber((b.data()['pc'] ?? '').toString())));
                          final isExpanded = _expandedRooms.contains(room);

                          return Column(
                            children: [
                              // Room header
                              InkWell(
                                onTap: () => setState(() {
                                  if (isExpanded) _expandedRooms.remove(room);
                                  else            _expandedRooms.add(room);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isExpanded ? const Color(0xFFF0F4FF) : Colors.transparent,
                                    border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8EEF8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.meeting_room_outlined, size: 16, color: _nuDarkBlue),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(room, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                                            Text('${roomDocs.length} PC${roomDocs.length != 1 ? 's' : ''}',
                                                style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                          ],
                                        ),
                                      ),
                                      // Delete all button for room
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedLab = room);
                                          _deleteAllInRoom();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFCEBEB),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFF09595)),
                                          ),
                                          child: const Text('Delete All',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF791F1F))),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedRotation(
                                        turns: isExpanded ? 0 : -0.25,
                                        duration: const Duration(milliseconds: 200),
                                        child: const Icon(Icons.expand_more, size: 18, color: Colors.black38),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // PC rows
                              if (isExpanded)
                                ...roomDocs.map((doc) {
                                  final data = doc.data();
                                  final pc   = (data['pc']   ?? '').toString();
                                  final code = (data['code'] ?? '').toString();
                                  return Container(
                                    padding: const EdgeInsets.fromLTRB(58, 10, 16, 10),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Color(0xFFF9FAFB))),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(pc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                              Text(code, style: const TextStyle(fontSize: 10, color: Colors.black45, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Load button
                                        _MiniBtn(label: 'Load', isGold: true, onTap: () => _loadSavedQr(data)),
                                        const SizedBox(width: 6),
                                        // Delete button
                                        _MiniBtn(
                                          label: 'Delete',
                                          isDanger: true,
                                          onTap: () => _deletePcCompletely(
                                            docId: doc.id,
                                            lab: (data['lab'] ?? '').toString(),
                                            pcLabel: pc, code: code,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}

// ── Shared UI Widgets ─────────────────────────────────────────────────────────

class _NuPanel extends StatelessWidget {
  final Color dotColor;
  final String title;
  final Widget child;
  const _NuPanel({required this.dotColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _nuDarkBlue, letterSpacing: 0.3)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8)),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.8));
}

class _NavyBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool fullWidth;
  const _NavyBtn({required this.label, this.onTap, this.icon, this.fullWidth = true});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: fullWidth ? double.infinity : null,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _nuDarkBlue,
        foregroundColor: _nuGold,
        disabledBackgroundColor: Colors.black12,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const _GoldBtn({required this.label, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _nuGold,
        foregroundColor: _nuDarkBlue,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const _OutlineBtn({required this.label, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _nuDarkBlue,
        side: const BorderSide(color: _nuDarkBlue, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _DangerBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const _DangerBtn({required this.label, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFCEBEB),
        foregroundColor: const Color(0xFF791F1F),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFF09595)),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isGold;
  final bool isDanger;
  const _MiniBtn({required this.label, required this.onTap, this.isGold = false, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    final bg   = isGold   ? _nuGold                   : isDanger ? const Color(0xFFFCEBEB) : Colors.transparent;
    final fg   = isGold   ? _nuDarkBlue               : isDanger ? const Color(0xFF791F1F) : _nuDarkBlue;
    final side = isDanger ? const Color(0xFFF09595)   : _nuDarkBlue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: side, width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}
