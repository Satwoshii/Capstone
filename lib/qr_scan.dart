import 'package:flutter/material.dart';
// Import the mobile_scanner package for camera access and QR detection
import 'package:mobile_scanner/mobile_scanner.dart';
// Import the form screen to record peripheral data
import 'peripheral_form.dart';

// QRScanner uses the device camera to scan PC identification codes
class QRScanner extends StatelessWidget {

  // Keeps track of the current PC being monitored across screen navigations
  static String? currentPC;

  // Logic to determine if we should switch to a new PC or stay with the current one
  void checkPC(BuildContext context, String scannedPC) {

    // If a different PC was already being monitored, ask for confirmation to switch
    if (currentPC != null && currentPC != scannedPC) {

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Switch PC"),
          content: Text("You are already in $currentPC. Switch to $scannedPC?"),
          actions: [
            // Cancel the switch and stay on the scanner screen
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            // Confirm the switch and navigate to the form for the new PC
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
      // If it's the first scan or the same PC, proceed directly to the form
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

      // The MobileScanner widget handles the camera preview and detection
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          // Retrieve list of barcodes detected by the camera
          final List<Barcode> barcodes = capture.barcodes;

          for (final barcode in barcodes) {
            // Get the raw text value from the QR code (the PC ID)
            final String? code = barcode.rawValue;

            if (code != null) {
              // Once a code is found, trigger the PC check logic
              checkPC(context, code);
              break; // Stop processing after the first valid code is found
            }
          }
        },
      ),
    );
  }
}
