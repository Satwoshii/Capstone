import 'package:flutter/material.dart';

// --- FRONTEND DESIGN NOTE ---
// PeripheralForm allows users to report the status of PC peripherals.
// It uses a simple ListView/Column of CheckboxListTiles for input.
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

    // --- DESIGN: SUBMISSION DIALOG ---
    // Modify the AlertDialog style here for confirmation feedback.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Submitted"),
        content: Text("Peripheral check submitted for PC ${widget.pcID}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- DESIGN: APP BAR ---
      // Display the PC ID in the top bar. Modify colors or elevation here.
      appBar: AppBar(title: Text("PC ${widget.pcID}")),

      // --- DESIGN: PAGE LAYOUT ---
      // Adjust padding or use a ListView if the form grows longer.
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- DESIGN: CHECKBOX LIST ITEMS ---
              // You can style the active color or text style of these tiles.
              CheckboxListTile(
                title: const Text("Mouse"),
                value: mouse,
                onChanged: (v) => setState(() => mouse = v!),
              ),

              CheckboxListTile(
                title: const Text("Keyboard"),
                value: keyboard,
                onChanged: (v) => setState(() => keyboard = v!),
              ),

              CheckboxListTile(
                title: const Text("Monitor"),
                value: monitor,
                onChanged: (v) => setState(() => monitor = v!),
              ),

              CheckboxListTile(
                title: const Text("System Unit"),
                value: systemUnit,
                onChanged: (v) => setState(() => systemUnit = v!),
              ),

              const SizedBox(height: 20),

              // --- DESIGN: COMMENTS INPUT ---
              // Modify 'InputDecoration' for borders, labels, and hint text.
              TextField(
                controller: comment,
                decoration: const InputDecoration(
                  labelText: "Comments",
                  hintText: "Enter any issues or notes here",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 30),

              // --- DESIGN: SUBMIT BUTTON ---
              // Style this button using ElevatedButton.styleFrom.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submit,
                  child: const Text("Submit Report"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
