import 'package:flutter/material.dart';

class PeripheralForm extends StatefulWidget {

  final String pcID;

  PeripheralForm({required this.pcID});

  @override
  _PeripheralFormState createState() => _PeripheralFormState();
}

class _PeripheralFormState extends State<PeripheralForm> {

  bool mouse = false;
  bool keyboard = false;
  bool monitor = false;
  bool systemUnit = false;

  final comment = TextEditingController();

  void submit() {

    print("PC: ${widget.pcID}");
    print("Mouse: $mouse");
    print("Keyboard: $keyboard");
    print("Monitor: $monitor");
    print("System Unit: $systemUnit");
    print("Comment: ${comment.text}");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Submitted"),
        content: Text("Peripheral check submitted"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: Text("PC ${widget.pcID}")),

      body: Padding(
        padding: EdgeInsets.all(20),

        child: Column(

          children: [

            CheckboxListTile(
              title: Text("Mouse"),
              value: mouse,
              onChanged: (v) => setState(() => mouse = v!),
            ),

            CheckboxListTile(
              title: Text("Keyboard"),
              value: keyboard,
              onChanged: (v) => setState(() => keyboard = v!),
            ),

            CheckboxListTile(
              title: Text("Monitor"),
              value: monitor,
              onChanged: (v) => setState(() => monitor = v!),
            ),

            CheckboxListTile(
              title: Text("System Unit"),
              value: systemUnit,
              onChanged: (v) => setState(() => systemUnit = v!),
            ),

            TextField(
              controller: comment,
              decoration: InputDecoration(labelText: "Comments"),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: submit,
              child: Text("Submit"),
            )
          ],
        ),
      ),
    );
  }
}