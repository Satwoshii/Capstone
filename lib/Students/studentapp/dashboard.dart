import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import the QR scanning screen for navigation
import 'qr_scan.dart';
import 'report_page.dart';
import 'login/screens/login_screen.dart';

// Dashboard is the main screen of the application after logging in.
class Dashboard extends StatelessWidget {

  // Method to clear the session and redirect to the login screen
  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("token"); // Remove the token from local storage
    
    if (context.mounted) {
      // Clear navigation history and send the user back to the LoginScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- DESIGN: APP BAR ---
      appBar: AppBar(title: const Text("Dashboard")),

      // --- DESIGN: SIDE DRAWER ---
      drawer: Drawer(
        child: ListView(
          children: [
            // Side menu Header
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Menu",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),

            // Navigation Links
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text("Contact ITSO"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportPage(),
                  ),
                );
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

      // --- DESIGN: MAIN CONTENT AREA ---
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome to the QR Monitoring System",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan QR Code"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QRScanner()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
