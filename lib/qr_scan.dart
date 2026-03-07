import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'peripheral_form.dart';

class QRScanner extends StatelessWidget {

  static String? currentPC;

  void checkPC(BuildContext context, String scannedPC) {

    if (currentPC != null && currentPC != scannedPC) {

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Switch PC"),
          content: Text("You are already in $currentPC. Switch to $scannedPC?"),
          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),

            TextButton(
              onPressed: () {
                currentPC = scannedPC;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PeripheralForm(pcID: scannedPC),
                  ),
                );
              },
              child: const Text("Yes"),
            )
          ],
        ),
      );

    } else {

      currentPC = scannedPC;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PeripheralForm(pcID: scannedPC),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR")),

      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {

          final List<Barcode> barcodes = capture.barcodes;

          for (final barcode in barcodes) {

            final String? code = barcode.rawValue;

            if (code != null) {
              checkPC(context, code);
              break;
            }

          }
        },
      ),
    );
  }
}