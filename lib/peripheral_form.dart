import 'package:flutter/material.dart';

// PeripheralForm is a StatefulWidget that allows users to report the status of PC peripherals
class PeripheralForm extends StatefulWidget {
  // The ID of the PC, received after scanning the QR code
  final String pcID;

  PeripheralForm({required this.pcID});

  @override
  _PeripheralFormState createState() => _PeripheralFormState();
}

class _PeripheralFormState extends State<PeripheralForm> {
  // State variables to track whether each peripheral is present or functional
  bool mouse = false;
  bool keyboard = false;
  bool monitor = false;
  bool systemUnit = false;

  // Controller for the optional comments text field
  final comment = TextEditingController();

  // Function called when the user clicks 'Submit'
  void submit() {
    // In a real app, this data would be sent to a database or API
    print("PC: ${widget.pcID}");
    print("Mouse: $mouse");
    print("Keyboard: $keyboard");
    print("Monitor: $monitor");
    print("System Unit: $systemUnit");
    print("Comment: ${comment.text}");

    // Show a confirmation dialog after submission
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Submitted"),
        content: Text("Peripheral check submitted for PC ${widget.pcID}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Display the PC ID in the top bar
      appBar: AppBar(title: Text("PC ${widget.pcID}")),

      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Checkbox for Mouse status
            CheckboxListTile(
              title: Text("Mouse"),
              value: mouse,
              onChanged: (v) => setState(() => mouse = v!),
            ),

            // Checkbox for Keyboard status
            CheckboxListTile(
              title: Text("Keyboard"),
              value: keyboard,
              onChanged: (v) => setState(() => keyboard = v!),
            ),

            // Checkbox for Monitor status
            CheckboxListTile(
              title: Text("Monitor"),
              value: monitor,
              onChanged: (v) => setState(() => monitor = v!),
            ),

            // Checkbox for System Unit status
            CheckboxListTile(
              title: Text("System Unit"),
              value: systemUnit,
              onChanged: (v) => setState(() => systemUnit = v!),
            ),

            // Text input for additional observations or issues
            TextField(
              controller: comment,
              decoration: InputDecoration(
                labelText: "Comments",
                hintText: "Enter any issues or notes here",
              ),
            ),

            SizedBox(height: 20),

            // Submit button to finalize the monitoring report
            ElevatedButton(
              onPressed: submit,
              child: Text("Submit Report"),
            )
          ],
        ),
      ),
    );
  }
}
