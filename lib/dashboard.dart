import 'package:flutter/material.dart';
import 'qr_scan.dart';

class Dashboard extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: Text("Dashboard")),

      drawer: Drawer(
        child: ListView(
          children: [

            DrawerHeader(
              child: Text("Menu"),
            ),

            ListTile(
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
              title: Text("Logout"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),

      body: Center(
        child: ElevatedButton(
          child: Text("Scan QR Code"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QRScanner()),
            );
          },
        ),
      ),
    );
  }
}