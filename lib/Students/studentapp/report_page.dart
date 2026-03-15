import 'package:flutter/material.dart';

// --- FRONTEND DESIGN NOTE ---
// ReportPage allows users to send a formal report to ITSO.
// It uses a centered "Card" design with a dark blue background and white input fields.
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  // Controllers to capture the user's input for ID and Comments
  final TextEditingController idController = TextEditingController();
  final TextEditingController commentController = TextEditingController();

  // Logic to handle sending the report
  void sendReport() {
    String id = idController.text;
    String comment = commentController.text;

    // Basic validation to ensure fields aren't empty
    if (id.isEmpty || comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete the form")),
      );
      return;
    }

    // --- DESIGN: SUCCESS FEEDBACK ---
    // Modify the SnackBar appearance here for successful submission feedback.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Report sent to ITSO")),
    );

    // Clear the form after a successful "send"
    idController.clear();
    commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- DESIGN: APP BAR ---
      // Branding color is currently 0xFF3F4A96 (Dark Blue).
      appBar: AppBar(
        title: const Text("Contact ITSO"),
        backgroundColor: const Color(0xFF3F4A96),
      ),

      // --- DESIGN: PAGE BACKGROUND ---
      // Using a light grey background to make the report card stand out.
      body: Container(
        color: Colors.grey[300],
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              // --- DESIGN: REPORT CARD ---
              // Modify the width, padding, and background color of this container.
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF3F4A96), // Report card background color
                borderRadius: BorderRadius.circular(25), // Rounded corners
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- DESIGN: SECTION TITLE ---
                  const Text(
                    "Report",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- DESIGN: ID FIELD LABEL ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Id:",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // --- DESIGN: ID INPUT FIELD ---
                  // Modify the border and fillColor here.
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // --- DESIGN: COMMENTS FIELD LABEL ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Comments:",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // --- DESIGN: COMMENTS INPUT FIELD ---
                  // 'maxLines' controls the height of the comment area.
                  TextField(
                    controller: commentController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- DESIGN: SEND BUTTON ---
                  // Alignment is set to the right. Style the button with 'backgroundColor' and 'foregroundColor'.
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber, // Accent color for the button
                        foregroundColor: Colors.black, // Text color on the button
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: sendReport,
                      child: const Text("Send"),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
