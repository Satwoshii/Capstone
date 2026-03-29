import 'package:flutter/material.dart'; // Import Flutter material design components
import '../studentvw_pages/report_form.dart';

// Define a StatefulWidget for the page where students enter a unique code
class EnterCodePage extends StatefulWidget {
  const EnterCodePage({super.key});

  @override
  State<EnterCodePage> createState() => _EnterCodePageState(); // Create the mutable state for this widget
}

// Define the state logic for EnterCodePage
class _EnterCodePageState extends State<EnterCodePage> {

  // Controller to handle the text input for the unique code
  final codeController = TextEditingController();

  // Function called when the user clicks the "Submit" button
  void submitCode() {

    // Check if the input field is empty
    if(codeController.text.isEmpty){
      // Show a snackbar message if no code was entered
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter unique code"))
      );
      return; // Stop execution if validation fails
    }

    // Navigate to the ReportFormPage if the code is provided
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentReportFormPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build the UI for the screen
    return Scaffold(

      // Set the title of the top app bar
      appBar: AppBar(title: const Text("Student View")),

      // Center the main content of the page
      body: Center(
        child: Container(
          width: 300, // Fixed width for the input box container
          padding: const EdgeInsets.all(20), // Internal padding for elements

          // Decorate the container with a white background and rounded corners
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            // Add a subtle shadow around the container
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10)
            ],
          ),

          // Arrange UI elements vertically inside the container
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content height
            children: [

              // Instructional text for the user
              const Text("Enter Code"),

              const SizedBox(height:10), // Space between text and input field

              // Text field for code entry
              TextField(
                controller: codeController, // Connect to the controller
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), // Add an outline border to the field
                ),
              ),

              const SizedBox(height:15), // Space between input field and button

              // Submit button
              ElevatedButton(
                onPressed: submitCode, // Execute submitCode function on click
                child: const Text("Submit"), // Button label
              )

            ],
          ),
        ),
      ),
    );
  }
}
