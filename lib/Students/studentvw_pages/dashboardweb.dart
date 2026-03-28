import 'package:flutter/material.dart'; // Import Flutter's material design library
import 'package:shared_preferences/shared_preferences.dart'; // Import to handle local storage of session data
import 'enter_code.dart'; // Import the page to enter unique codes
import 'login/screens/login_screen.dart'; // Import the login screen for redirection
import 'login/services/jwt_service.dart'; // Import the JWT service to verify the user's session

// Define a StatefulWidget for the main dashboard of the web/app view
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState(); // Create state for the dashboard
}

// State management class for DashboardPage
class _DashboardPageState extends State<DashboardPage> {
  // Variable to store the current user's email, initialized with a loading state
  String userEmail = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadUserInfo(); // Load user information when the dashboard is first initialized
  }

  // Asynchronous method to retrieve user info from the stored JWT token
  _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance(); // Open shared preferences
    String? token = prefs.getString("token"); // Try to get the saved token
    
    if (token != null) {
      var payload = JWTService.verifyToken(token); // Verify the token's validity
      if (payload != null) {
        setState(() {
          // If valid, update the email from the token's payload
          userEmail = payload['email'] ?? "Unknown User";
        });
      } else {
        _logout(); // If token is invalid/expired, force logout
      }
    } else {
      _logout(); // If no token exists, force logout
    }
  }

  // Method to clear the session and redirect to the login screen
  _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("token"); // Remove the token from local storage
    if (mounted) {
      // Clear navigation history and send the user back to the LoginScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the visual layout of the dashboard
    return Scaffold(
      appBar: AppBar(
        title: const Text("National University"), // Main header title
      ),
      // Side menu (Drawer) for navigation
      drawer: Drawer(
        child: ListView(
          children: [
            // Header of the drawer showing the user's email
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Text(
                userEmail,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            // Menu item for Dashboard (current view)
            const ListTile(
              leading: Icon(Icons.dashboard),
              title: Text("Dashboard"),
            ),
            // Menu item for Report functionality
            const ListTile(
              leading: Icon(Icons.report),
              title: Text("Report"),
            ),
            // Menu item for Logout action
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout, // Trigger logout when tapped
            ),
          ],
        ),
      ),
      // Main content area of the dashboard
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center items vertically
          children: [
            // Display the user's email on the screen
            Text("Logged in as: $userEmail", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20), // Vertical spacing
            // Button to navigate to the code entry page
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
