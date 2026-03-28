import 'package:flutter/material.dart'; // Import Flutter's material design library
import 'dashboardweb.dart'; // Import the dashboard page for navigation

// Define a StatelessWidget for the Success Page
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Build the visual layout of the success message screen
    return Scaffold(
      // Center the content on the screen
      body: Center(
        // Use a Card widget to create a elevated, box-like container
        child: Card(
          // Add padding inside the card
          child: Padding(
            padding: const EdgeInsets.all(30),
            // Arrange text and buttons vertically
            child: Column(
              mainAxisSize: MainAxisSize.min, // Shrink the column to fit its contents
              children: [
                // Main success message
                const Text(
                  "Report Sent",
                  style: TextStyle(fontSize: 22),
                ),

                const SizedBox(height:10), // Vertical spacing

                // Additional status information text
                const Text("Current Status"),

                const SizedBox(height:20), // Vertical spacing

                // Button to return to the dashboard
                ElevatedButton(
                  onPressed: (){
                    // Replace the current screen with the DashboardPage
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context)=>const DashboardPage(),
                      ),
                    );
                  },
                  child: const Text("Close"), // Label for the button
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}
