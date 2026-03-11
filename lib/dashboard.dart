import 'package:flutter/material.dart';
// Import the QR scanning screen for navigation
import 'qr_scan.dart';

// Dashboard is the main screen of the application after logging in.
// --- FRONTEND DESIGN NOTE ---
// This screen uses a Scaffold with an AppBar, Drawer, and Body.
// To change the overall layout, modify the Scaffold properties.
class Dashboard extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- DESIGN: APP BAR ---
      // This is the top branding area. Modify 'backgroundColor' or 'elevation' here.
      appBar: AppBar(title: Text("Dashboard")),

      // --- DESIGN: SIDE DRAWER ---
      // This is the navigation menu. Change the color in BoxDecoration or fonts in Text styles.
      drawer: Drawer(
        child: ListView(
          children: [
            // Side menu Header - modify background color or add a profile image here
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Menu",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),

            // Navigation Links
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

            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pop(context); // Go back to Login
              },
            ),
          ],
        ),
      ),

      // --- DESIGN: MAIN CONTENT AREA ---
      // The body is centered. You can change the layout to a Padding/ListView if more content is added.
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Headline Text - Modify 'TextStyle' for font size, weight, and color.
            Text(
              "Welcome to the QR Monitoring System",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            // Spacing between elements
            SizedBox(height: 20),

            // --- DESIGN: CALL TO ACTION BUTTON ---
            // This is the primary button. Modify ElevatedButton theme or style here.
            ElevatedButton.icon(
              icon: Icon(Icons.qr_code_scanner),
              label: Text("Scan QR Code"),
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
