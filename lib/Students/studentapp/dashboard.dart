import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../studentvw_pages/report_form.dart';
import 'login/screens/login_screen.dart';
import 'login/services/jwt_service.dart';
import 'report_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool scanLocked = false;
  final TextEditingController uniqueCodeController = TextEditingController();

  String userName = 'Student';
  String userEmail = 'No email';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      await _logout(context);
      return;
    }

    final payload = JWTService.verifyToken(token);

    if (payload == null) {
      await _logout(context);
      return;
    }

    if (!mounted) return;

    setState(() {
      userName =
          (payload['full_name'] ?? payload['name'] ?? 'Student').toString();
      userEmail = (payload['email'] ?? 'No email').toString();
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  String? parsePC(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      final String? code = uri.queryParameters['code'];

      if (code == null && !qrData.contains('://')) {
        return qrData.trim();
      }

      if (code != null && code.isNotEmpty) {
        return code.trim();
      }
    } catch (_) {
      if (qrData.trim().isNotEmpty) {
        return qrData.trim();
      }
    }
    return null;
  }

  void navigateToReport(String scannedPC) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentReportFormPage(
          pcCode: scannedPC,
          initialStudentName: userName,
          initialStudentEmail: userEmail,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          scanLocked = false;
        });
      }
    });
  }

  void _openUniqueCodeDialog() {
    uniqueCodeController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Enter Unique Code"),
          content: TextField(
            controller: uniqueCodeController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Enter code here",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String code = uniqueCodeController.text.trim();

                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a unique code"),
                    ),
                  );
                  return;
                }

                final uri = Uri.tryParse(code);
                if (uri != null && uri.queryParameters.containsKey('code')) {
                  code = uri.queryParameters['code']!.trim();
                }

                Navigator.pop(dialogContext);
                navigateToReport(code);
              },
              child: const Text("Proceed"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    uniqueCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Scanner"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF3F51B5),
              ),
              accountName: Text(
                userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                userEmail,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Color(0xFFD9CCF5),
                child: Icon(
                  Icons.person,
                  size: 38,
                  color: Color(0xFF5A3E9B),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text("Scan / Enter Code"),
              onTap: () {
                Navigator.pop(context);
                _openUniqueCodeDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () => _logout(context),
            ),
          ],
        ),
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
                  final parsedCode = parsePC(raw);

                  if (parsedCode != null) {
                    navigateToReport(parsedCode);
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text(
                          "Invalid QR",
                          style: TextStyle(color: Colors.red),
                        ),
                        content: const Text(
                          "This QR code is not recognized by the system.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (mounted) {
                                setState(() {
                                  scanLocked = false;
                                });
                              }
                            },
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 4),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align QR code within the frame",
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openUniqueCodeDialog,
                icon: const Icon(Icons.password),
                label: const Text("Enter Unique Code"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}