import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../widgets/itso_drawer.dart';
import '../landingITso.dart';

class QrManagementPage extends StatefulWidget {
  const QrManagementPage({super.key});

  @override
  State<QrManagementPage> createState() => _QrManagementPageState();
}

class _QrManagementPageState extends State<QrManagementPage> {

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _pcCtrl = TextEditingController();

  String? _selectedLab;
  String? _qrData;
  String? _uniqueCode;
  String? _logoDataUrlCache;

  @override
  void dispose() {
    _pcCtrl.dispose();
    super.dispose();
  }

  // UNIQUE CODE GENERATOR
  String _generateUniqueCode(String lab, String pc) {

    final rand = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(16)
        .substring(8)
        .toUpperCase();

    return "$lab-PC$pc-$rand";
  }

  void _generate() {

    final app = AppStateScope.of(context);
    final lab = _selectedLab ?? '';
    final pc = _pcCtrl.text.trim();

    if (lab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Lab Room'))
      );
      return;
    }

    if (pc.isEmpty || int.tryParse(pc) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid PC number'))
      );
      return;
    }

    if (!app.isValidLab(lab)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Lab Room'))
      );
      return;
    }

    final uniqueCode = _generateUniqueCode(lab, pc);

    final url = "https://test-1fc5d.web.app/scan?code=$uniqueCode";

    setState(() {
      _uniqueCode = uniqueCode;
      _qrData = url;
    });
  }

  Future<String> _loadLogoDataUrl() async {

    if (_logoDataUrlCache != null) {
      return _logoDataUrlCache!;
    }

    final bytes = await rootBundle.load('assets/nu_logo.png');
    final b64 = base64Encode(bytes.buffer.asUint8List());

    _logoDataUrlCache = 'data:image/png;base64,$b64';

    return _logoDataUrlCache!;
  }

  Future<void> _printQr() async {

    if (_qrData == null) return;

    final painter = QrPainter(
      data: _qrData!,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );

    const double size = 1024;

    final qrByteData =
    await painter.toImageData(size, format: ui.ImageByteFormat.png);

    if (qrByteData == null) return;

    final png = Uint8List.view(qrByteData.buffer);

    final qrUrl =
    html.Url.createObjectUrlFromBlob(html.Blob([png], 'image/png'));

    final logoDataUrl = await _loadLogoDataUrl();

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
}

.frame{
padding:24px;
border:24px solid #FFC107;
}

.qrwrap{
position:relative;
}

.qr{
width:512px;
height:512px;
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

</style>
</head>

<body>

<div class="frame">
<div class="qrwrap">
<img class="qr" src="$qrUrl">
<div class="logo-bg"></div>
<img class="logo" src="$logoDataUrl">
</div>
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
          child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Select Lab Room"),
                  const SizedBox(height: 6),

                  DropdownButtonFormField<String>(
                    value: _selectedLab,
                    items: app.labs
                        .map(
                          (lab) => DropdownMenuItem(
                        value: lab,
                        child: Text(lab),
                      ),
                    )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLab = v),
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

                  ElevatedButton(
                    onPressed: _generate,
                    child: const Text("Generate QR"),
                  ),

                ],
              ),
            ),

            const SizedBox(width: 40),

            Expanded(
              child: Column(
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

                  if (_qrData != null)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.amber, width: 18),
                        color: Colors.white,
                      ),
                      child: QrImageView(
                        data: _qrData!,
                        size: 360,
                        embeddedImage:
                        const AssetImage('assets/nu_logo.png'),
                        embeddedImageStyle:
                        const QrEmbeddedImageStyle(size: Size(64, 64)),
                      ),
                    ),

                  const SizedBox(height: 20),

                  if (_qrData != null)
                    ElevatedButton(
                      onPressed: _printQr,
                      child: const Text("Print QR"),
                    ),

                ],
              ),
            )

          ],
        ),
      ),
    );
  }
}