import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enter_code.dart';
import 'login/screens/login_screen.dart';
import 'login/services/jwt_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userName = 'Student';
  String userEmail = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token != null) {
      final payload = JWTService.verifyToken(token);
      if (payload != null) {
        setState(() {
          userName = (payload['full_name'] ?? payload['name'] ?? 'Student').toString();
          userEmail = (payload['email'] ?? 'No email').toString();
        });
        return;
      }
    }

    _logout();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    if (mounted) {
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
      appBar: AppBar(title: const Text("National University")),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              accountName: Text(userName),
              accountEmail: Text(userEmail),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.dashboard),
              title: Text("Dashboard"),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text("Scan / Enter Code"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EnterCodePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(userEmail, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              child: const Text("Scan / Enter Code"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EnterCodePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}