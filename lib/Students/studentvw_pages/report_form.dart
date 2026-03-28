import 'package:flutter/material.dart'; // Flutter's core UI components
import 'package:shared_preferences/shared_preferences.dart'; // To persist data locally like tokens
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase database integration
import 'login/services/jwt_service.dart'; // Custom service for JWT verification
import 'success_page.dart'; // Page to show after successful submission
import 'login/screens/login_screen.dart'; // Fallback page if authentication fails

// StatefulWidget for the report form where students log hardware issues
class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key});

  @override
  State<ReportFormPage> createState() => _ReportFormPageState(); // Initialize state
}

// State management for ReportFormPage
class _ReportFormPageState extends State<ReportFormPage> {
  // Controllers to store user input for different hardware components
  final mouse = TextEditingController();
  final keyboard = TextEditingController();
  final monitor = TextEditingController();
  final cables = TextEditingController();
  final system = TextEditingController();
  
  // Variable to store the student's email extracted from the JWT token
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _checkAuth(); // Verify if the user is logged in as soon as the page loads
  }

  // Helper method to verify the user's authentication token
  _checkAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance(); // Access shared preferences
    String? token = prefs.getString("token"); // Retrieve the stored JWT token
    
    if (token != null) {
      var payload = JWTService.verifyToken(token); // Validate the token using the JWT service
      if (payload != null) {
        setState(() {
          userEmail = payload['email']; // Extract email from payload and update UI state
        });
        return; // Token is valid, continue
      }
    }
    
    // If no valid token is found, redirect user to the login screen
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()), // Use LoginScreen as target
        (route) => false, // Remove all previous routes from stack
      );
    }
  }

  // Function to handle the form submission to Firestore
  void submitReport() async {
    if (userEmail == null) return; // Guard clause if user isn't identified

    // Show a confirmation dialog before sending data
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Submit Report"), // Dialog title
        content: const Text("Are you sure you want to submit?"), // Dialog message
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog without action
            child: const Text("No"),
          ),
          // Confirm button
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              
              // Save the report data to the "reports" collection in Firestore
              await FirebaseFirestore.instance.collection("reports").add({
                "student_email": userEmail, // Email obtained from the JWT
                "mouse": mouse.text, // Input from mouse field
                "keyboard": keyboard.text, // Input from keyboard field
                "monitor": monitor.text, // Input from monitor field
                "cables": cables.text, // Input from cables field
                "system_unit": system.text, // Input from system unit field
                "timestamp": FieldValue.serverTimestamp(), // Firestore server-side timestamp
              });

              // Navigate to the SuccessPage if the widget is still active
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SuccessPage(),
                  ),
                );
              }
            },
            child: const Text("Yes"),
          )
        ],
      ),
    );
  }

  // Reusable widget builder for the text input fields
  Widget buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // Space between fields
      child: TextField(
        controller: controller, // Link the controller
        decoration: InputDecoration(
          labelText: label, // Field label
          filled: true, // Use a solid background color
          fillColor: Colors.white, // Background color of the text field
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build the main UI layout
    return Scaffold(
      appBar: AppBar(title: const Text("Student View")), // Page title
      body: Center(
        child: SingleChildScrollView( // Allow scrolling if content overflows
          child: Container(
            width: 350, // Fixed width for the form container
            padding: const EdgeInsets.all(20), // Internal spacing
            decoration: BoxDecoration(
              color: Colors.indigo, // Dark blue background for the form area
              borderRadius: BorderRadius.circular(10), // Rounded edges
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Shrink column to fit its contents
              children: [
                // Display the current user's email or a loading state
                Text(
                  "Reporting as: ${userEmail ?? 'Loading...'}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10), // Vertical spacing
                // Build the input fields for each component
                buildField("Mouse", mouse),
                buildField("Keyboard", keyboard),
                buildField("Monitor", monitor),
                buildField("Cables", cables),
                buildField("System Unit", system),
                const SizedBox(height: 20), // Spacing before button
                // Submit button, disabled if userEmail isn't loaded yet
                ElevatedButton(
                  onPressed: userEmail == null ? null : submitReport,
                  child: const Text("Submit"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
