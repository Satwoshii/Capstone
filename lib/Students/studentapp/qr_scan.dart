import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../studentvw_pages/report_form.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  /// Prevents multiple scans
  bool scanLocked = false;

  /// Validate and parse QR
  String? parsePC(String qrData) {
    try {
      Uri uri = Uri.parse(qrData);

      /// Extract unique code from the 'code' query parameter
      String? code = uri.queryParameters['code'];

      // If the QR is just the raw code (not a URL), use it directly
      if (code == null && !qrData.contains("://")) {
        return qrData;
      }

      if (code != null && code.isNotEmpty) {
        return code;
      }
    } catch (_) {
      // If parsing fails, treat the raw string as the code
      if (qrData.isNotEmpty) return qrData;
    }
    return null;
  }

  void navigateToReport(String scannedPC) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentReportFormPage(pcCode: scannedPC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
            ),
            onDetect: (BarcodeCapture capture) {
              if (scanLocked) return;

              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null) {
                  scanLocked = true;
                  String? parsedCode = parsePC(raw);

                  if (parsedCode != null) {
                    navigateToReport(parsedCode);
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Invalid QR", style: TextStyle(color: Colors.red)),
                        content: const Text("This QR code is not recognized by the system."),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => scanLocked = false);
                            },
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  }
                  break;
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align QR code within the frame",
                style: TextStyle(color: Colors.white, backgroundColor: Colors.black54),
              ),
            ),
          )
        ],
      ),
    );
  }
}
