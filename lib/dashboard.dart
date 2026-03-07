import 'package:flutter/material.dart';
// Import the QR scanning screen for navigation
import 'qr_scan.dart';

// Dashboard is the main screen of the application after logging in
class Dashboard extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top application bar with the screen title
      appBar: AppBar(title: Text("Dashboard")),

      // Side menu for additional navigation and actions
      drawer: Drawer(
        child: ListView(
          children: [
            // Header for the side menu
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Menu",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),

            // Option to display contact information
            ListTile(
              leading: Icon(Icons.contact_support),
              title: Text("Contact ITSO"),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text("Contact ITSO"),
                    content: Text("Email: itso@school.edu"),
                  ),
                );
              },
            ),

            // Option to log out and return to the login screen
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: () {
                // Pop the drawer and the current dashboard screen
                Navigator.pop(context); // Close drawer
                Navigator.pop(context); // Go back to Login
              },
            ),
          ],
        ),
      ),

      // Main body content
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome to the QR Monitoring System",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            // Button to initiate the QR code scanner
            ElevatedButton.icon(
              icon: Icon(Icons.qr_code_scanner),
              label: Text("Scan QR Code"),
              onPressed: () {
                // Navigate to the QRScanner screen
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
