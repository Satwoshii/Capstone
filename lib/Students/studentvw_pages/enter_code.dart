import 'package:flutter/material.dart';
import 'report_form.dart';

class EnterCodePage extends StatefulWidget {
  const EnterCodePage({super.key});

  @override
  State<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends State<EnterCodePage> {

  final codeController = TextEditingController();

  void submitCode() {

    if(codeController.text.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter unique code"))
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportFormPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: const Text("Student View")),

      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10)
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Text("Enter Code"),

              const SizedBox(height:10),

              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height:15),

              ElevatedButton(
                onPressed: submitCode,
                child: const Text("Submit"),
              )

            ],
          ),
        ),
      ),
    );
  }
}