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

class QrManagementPage extends StatefulWidget {
  const QrManagementPage({super.key});

  @override
  State<QrManagementPage> createState() => _QrManagementPageState();
}

class _QrManagementPageState extends State<QrManagementPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _pcCtrl = TextEditingController();
  final TextEditingController _bulkCtrl = TextEditingController();

  String? _selectedLab;
  String? _qrData;
  String? _uniqueCode;
  String? _pcLabel;
  String? _logoDataUrlCache;

  bool _loadingNext = false;
  bool _saving = false;
  bool _bulkGenerating = false;
  bool _bulkPrinting = false;

  @override
  void dispose() {
    _pcCtrl.dispose();
    _bulkCtrl.dispose();
    super.dispose();
  }

  int _extractPcNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }

  // KEEP OLD UNIQUE CODE STYLE
  String _generateUniqueCode(String lab, String pc) {
    final rand = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(16)
        .substring(8)
        .toUpperCase();

    return "$lab-PC$pc-$rand";
  }

  String _buildQrUrl(String code) {
    return "https://test-1fc5d.web.app/scan?code=$code";
  }

  Future<void> _nextPc() async {
    final lab = _selectedLab;
    if (lab == null || lab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room first')),
      );
      return;
    }

    setState(() => _loadingNext = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pcs')
          .where('lab', isEqualTo: lab)
          .get();

      int highest = 0;
      for (final doc in snapshot.docs) {
        final pc = (doc.data()['pc'] ?? '').toString();
        final num = _extractPcNumber(pc);
        if (num > highest) highest = num;
      }

      _pcCtrl.text = '${highest + 1}';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get next PC number: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingNext = false);
    }
  }

  Future<void> _generatePreview() async {
    final app = AppStateScope.of(context);
    final lab = _selectedLab ?? '';
    final pc = _pcCtrl.text.trim();

    if (lab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Lab Room')),
      );
      return;
    }

    if (pc.isEmpty || int.tryParse(pc) == null || int.parse(pc) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid PC number')),
      );
      return;
    }

    if (!app.isValidLab(lab)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Lab Room')),
      );
      return;
    }

    final uniqueCode = _generateUniqueCode(lab, pc);
    final url = _buildQrUrl(uniqueCode);

    setState(() {
      _pcLabel = 'PC $pc';
      _uniqueCode = uniqueCode;
      _qrData = url;
    });
  }

  Future<void> _saveSingleQr() async {
    final app = AppStateScope.of(context);
    final lab = _selectedLab ?? '';
    final pc = _pcCtrl.text.trim();

    if (lab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Lab Room')),
      );
      return;
    }

    if (pc.isEmpty || int.tryParse(pc) == null || int.parse(pc) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid PC number')),
      );
      return;
    }

    if (!app.isValidLab(lab)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Lab Room')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final existingPc = await FirebaseFirestore.instance
          .collection('pcs')
          .where('lab', isEqualTo: lab)
          .where('pc', isEqualTo: 'PC $pc')
          .get();

      if (existingPc.docs.isNotEmpty) {
        final existingData = existingPc.docs.first.data();
        final existingCode = (existingData['code'] ?? '').toString();
        final existingQrData = (existingData['qr_data'] ?? '').toString();

        setState(() {
          _pcLabel = 'PC $pc';
          _uniqueCode = existingCode;
          _qrData = existingQrData.isNotEmpty
              ? existingQrData
              : _buildQrUrl(existingCode);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PC $pc already exists in $lab')),
        );
        return;
      }

      final uniqueCode = _generateUniqueCode(lab, pc);
      final url = _buildQrUrl(uniqueCode);

      await FirebaseFirestore.instance.collection('pcs').doc(uniqueCode).set({
        'lab': lab,
        'pc': 'PC $pc',
        'code': uniqueCode,
        'qr_data': url,
        'status': 'available',
        'comment': '',
        'reported_by': '',
        'created_at': Timestamp.now(),
        'updated_at': FieldValue.serverTimestamp(),
        'peripherals': {
          'keyboard': true,
          'mouse': true,
          'monitor': true,
          'cables': true,
          'system_unit': true,
        },
      });

      setState(() {
        _pcLabel = 'PC $pc';
        _uniqueCode = uniqueCode;
        _qrData = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Generated and saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save QR: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateAllForLab() async {
    final app = AppStateScope.of(context);
    final lab = _selectedLab ?? '';
    final count = int.tryParse(_bulkCtrl.text.trim());

    if (lab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Lab Room')),
      );
      return;
    }

    if (!app.isValidLab(lab)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Lab Room')),
      );
      return;
    }

    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid total PC count')),
      );
      return;
    }

    setState(() => _bulkGenerating = true);

    try {
      final existingSnapshot = await FirebaseFirestore.instance
          .collection('pcs')
          .where('lab', isEqualTo: lab)
          .get();

      final existingPcLabels = existingSnapshot.docs
          .map((doc) => (doc.data()['pc'] ?? '').toString())
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      int createdCount = 0;

      for (int i = 1; i <= count; i++) {
        final pcLabel = 'PC $i';

        if (existingPcLabels.contains(pcLabel)) {
          continue;
        }

        final uniqueCode = _generateUniqueCode(lab, '$i');
        final url = _buildQrUrl(uniqueCode);

        final docRef =
        FirebaseFirestore.instance.collection('pcs').doc(uniqueCode);

        batch.set(docRef, {
          'lab': lab,
          'pc': pcLabel,
          'code': uniqueCode,
          'qr_data': url,
          'status': 'available',
          'comment': '',
          'reported_by': '',
          'created_at': Timestamp.now(),
          'updated_at': FieldValue.serverTimestamp(),
          'peripherals': {
            'keyboard': true,
            'mouse': true,
            'monitor': true,
            'cables': true,
            'system_unit': true,
          },
        });

        createdCount++;
      }

      if (createdCount > 0) {
        await batch.commit();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            createdCount == 0
                ? 'All PCs already exist in room $lab'
                : 'Generated $createdCount new QR codes for room $lab',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate all QRs: $e')),
      );
    } finally {
      if (mounted) setState(() => _bulkGenerating = false);
    }
  }

  Future<String> _loadLogoDataUrl() async {
    if (_logoDataUrlCache != null) {
      return _logoDataUrlCache!;
    }

    try {
      final bytes = await rootBundle.load('assets/Image/NUSchoolLogo.png');
      final b64 = base64Encode(bytes.buffer.asUint8List());
      _logoDataUrlCache = 'data:image/png;base64,$b64';
      return _logoDataUrlCache!;
    } catch (_) {
      try {
        final bytes = await rootBundle.load('assets/Images/nu_logo.png');
        final b64 = base64Encode(bytes.buffer.asUint8List());
        _logoDataUrlCache = 'data:image/png;base64,$b64';
        return _logoDataUrlCache!;
      } catch (_) {
        _logoDataUrlCache = '';
        return _logoDataUrlCache!;
      }
    }
  }

  Future<String> _qrToBase64(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );

    final picData = await painter.toImageData(
      800,
      format: ui.ImageByteFormat.png,
    );

    if (picData == null) {
      throw Exception('Failed to render QR image');
    }

    final bytes = Uint8List.view(picData.buffer);
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  Future<void> _printSingleQr() async {
    if (_qrData == null) return;

    final qrBase64 = await _qrToBase64(_qrData!);
    final logoDataUrl = await _loadLogoDataUrl();

    final logoHtml = logoDataUrl.isEmpty
        ? ''
        : '''
<div class="logo-bg"></div>
<img class="logo" src="$logoDataUrl">
''';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Print QR</title>
<style>
body{
margin:0;
display:flex;
align-items:center;
justify-content:center;
height:100vh;
background:white;
font-family: Arial, sans-serif;
}
.wrap{
text-align:center;
}
.frame{
padding:24px;
border:24px solid #FFC107;
display:inline-block;
background:white;
}
.qrwrap{
position:relative;
}
.qr{
width:512px;
height:512px;
display:block;
}
.logo-bg{
position:absolute;
top:50%;
left:50%;
width:120px;
height:120px;
transform:translate(-50%,-50%);
background:white;
border-radius:12px;
}
.logo{
position:absolute;
top:50%;
left:50%;
width:96px;
height:96px;
transform:translate(-50%,-50%);
}
.meta{
margin-top:14px;
font-weight:bold;
}
.code{
margin-top:6px;
font-size:14px;
}
</style>
</head>
<body>
<div class="wrap">
<div class="frame">
<div class="qrwrap">
<img class="qr" src="$qrBase64">
$logoHtml
</div>
</div>
<div class="meta">${_selectedLab ?? ''} - ${_pcLabel ?? ''}</div>
<div class="code">${_uniqueCode ?? ''}</div>
</div>
<script>
window.onload=function(){
setTimeout(function(){
window.print();
},300);
};
window.onafterprint=function(){
window.close();
};
</script>
</body>
</html>
''';

    final pageUrl =
    html.Url.createObjectUrlFromBlob(html.Blob([htmlContent], 'text/html'));

    html.window.open(pageUrl, '_blank');
  }

  Future<void> _bulkPrint() async {
    final lab = _selectedLab;
    if (lab == null || lab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room')),
      );
      return;
    }

    setState(() => _bulkPrinting = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pcs')
          .where('lab', isEqualTo: lab)
          .get();

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aPc = _extractPcNumber((a.data()['pc'] ?? '').toString());
          final bPc = _extractPcNumber((b.data()['pc'] ?? '').toString());
          return aPc.compareTo(bPc);
        });

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved QRs in this room')),
        );
        return;
      }

      final logoDataUrl = await _loadLogoDataUrl();
      final cards = <String>[];

      for (final doc in docs) {
        final data = doc.data();
        final qrData = (data['qr_data'] ?? '').toString();
        final code = (data['code'] ?? '').toString();
        final room = (data['lab'] ?? '').toString();
        final pc = (data['pc'] ?? '').toString();

        if (qrData.isEmpty) continue;

        final qrBase64 = await _qrToBase64(qrData);

        final logoHtml = logoDataUrl.isEmpty
            ? ''
            : '''
<div class="logo-bg"></div>
<img class="logo" src="$logoDataUrl">
''';

        cards.add('''
<div class="card">
  <div class="frame">
    <div class="qrwrap">
      <img class="qr" src="$qrBase64" />
      $logoHtml
    </div>
  </div>
  <div class="meta">$room - $pc</div>
  <div class="code">$code</div>
</div>
''');
      }

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Bulk Print</title>
<style>
body {
  font-family: Arial, sans-serif;
  padding: 20px;
  background: white;
}
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 18px;
}
.card {
  border: 1px solid #ccc;
  padding: 12px;
  text-align: center;
  break-inside: avoid;
  page-break-inside: avoid;
}
.frame{
  padding:12px;
  border:12px solid #FFC107;
  display:inline-block;
  background:white;
}
.qrwrap{
  position:relative;
}
.qr{
  width:180px;
  height:180px;
  display:block;
}
.logo-bg{
  position:absolute;
  top:50%;
  left:50%;
  width:44px;
  height:44px;
  transform:translate(-50%,-50%);
  background:white;
  border-radius:8px;
}
.logo{
  position:absolute;
  top:50%;
  left:50%;
  width:34px;
  height:34px;
  transform:translate(-50%,-50%);
}
.meta {
  margin-top: 8px;
  font-weight: bold;
}
.code {
  font-size: 12px;
  margin-top: 4px;
  word-break: break-word;
}
</style>
</head>
<body>
  <div class="grid">
    ${cards.join()}
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 300);
    };
  </script>
</body>
</html>
''';

      final blob = html.Blob([htmlContent], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to bulk print: $e')),
      );
    } finally {
      if (mounted) setState(() => _bulkPrinting = false);
    }
  }

  void _loadSavedQr(Map<String, dynamic> data) {
    final pcLabel = (data['pc'] ?? '').toString();
    final pcNumber = _extractPcNumber(pcLabel);

    setState(() {
      _selectedLab = (data['lab'] ?? '').toString();
      _pcCtrl.text = pcNumber > 0 ? '$pcNumber' : '';
      _pcLabel = pcLabel;
      _uniqueCode = (data['code'] ?? '').toString();
      _qrData = (data['qr_data'] ?? '').toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final app = AppStateScope.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        backgroundColor: color.primary,
        title: const Text(
          "ITSO View",
          style: TextStyle(color: Colors.white),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: ColoredBox(color: Colors.amber),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Single QR",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text("Select Lab Room"),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: app.labs.contains(_selectedLab) ? _selectedLab : null,
                        items: app.labs
                            .map(
                              (lab) => DropdownMenuItem(
                            value: lab,
                            child: Text(lab),
                          ),
                        )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedLab = v),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pcCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Input PC Number",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loadingNext ? null : _nextPc,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_loadingNext ? 'Loading...' : 'Next PC'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _generatePreview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text("Generate Preview"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveSingleQr,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_saving ? 'Saving...' : 'Save QR'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        "Auto Generate Whole Lab",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bulkCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total PCs',
                          border: OutlineInputBorder(),
                          hintText: 'ex. 40',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _bulkGenerating ? null : _generateAllForLab,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _bulkGenerating
                                ? 'Generating...'
                                : 'Generate All QRs',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _bulkPrinting ? null : _bulkPrint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _bulkPrinting ? 'Preparing...' : 'Bulk Print',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    const Text(
                      'QR Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_qrData == null)
                      const Expanded(
                        child: Center(
                          child: Text('Generate or load a QR to preview'),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_uniqueCode != null)
                              Column(
                                children: [
                                  const Text(
                                    "Unique Code",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black26),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SelectableText(
                                      _uniqueCode!,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.amber, width: 18),
                                color: Colors.white,
                              ),
                              child: QrImageView(
                                data: _qrData!,
                                size: 300,
                                embeddedImage: const AssetImage(
                                  'assets/Images/nu_logo.png',
                                ),
                                embeddedImageStyle:
                                const QrEmbeddedImageStyle(size: Size(64, 64)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_selectedLab ?? ''} - ${_pcLabel ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_qrData != null)
                              SelectableText(
                                _qrData!,
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _printSingleQr,
                              child: const Text("Print QR"),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved QR Codes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs.toList();

                          if (docs.isEmpty) {
                            return const Center(
                              child: Text('No saved QR codes yet'),
                            );
                          }

                          docs.sort((a, b) {
                            final aLab = (a.data()['lab'] ?? '').toString();
                            final bLab = (b.data()['lab'] ?? '').toString();
                            final labCompare = aLab.compareTo(bLab);
                            if (labCompare != 0) return labCompare;

                            final aPc =
                            _extractPcNumber((a.data()['pc'] ?? '').toString());
                            final bPc =
                            _extractPcNumber((b.data()['pc'] ?? '').toString());
                            return aPc.compareTo(bPc);
                          });

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final lab = (data['lab'] ?? '').toString();
                              final pc = (data['pc'] ?? '').toString();
                              final code = (data['code'] ?? '').toString();

                              return ListTile(
                                leading: const Icon(Icons.qr_code),
                                title: Text('$lab - $pc'),
                                subtitle: Text(code),
                                trailing: ElevatedButton(
                                  onPressed: () => _loadSavedQr(data),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Load'),
                                ),
                              );
                            },
                          );
                        },
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