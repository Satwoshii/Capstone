import 'package:flutter/material.dart';
import 'enter_code.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("National University"),
      ),

      drawer: Drawer(
        child: ListView(
          children: const [

            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text(
                "Student Name",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),

            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text("Dashboard"),
            ),

            ListTile(
              leading: Icon(Icons.report),
              title: Text("Report"),
            ),

            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
            ),

          ],
        ),
      ),

      body: Center(
        child: ElevatedButton(
          child: const Text("Scan / Enter Code"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EnterCodePage()),
            );
          },
        ),
      ),
    );
  }
}