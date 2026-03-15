import 'package:flutter/material.dart';
import 'success_page.dart';

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key});

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {

  final mouse = TextEditingController();
  final keyboard = TextEditingController();
  final monitor = TextEditingController();
  final cables = TextEditingController();
  final system = TextEditingController();

  void submitReport(){

    showDialog(
      context: context,
      builder: (context) => AlertDialog(

        title: const Text("Submit Report"),

        content: const Text("Are you sure you want to submit?"),

        actions: [

          TextButton(
            onPressed: (){
              Navigator.pop(context);
            },
            child: const Text("No"),
          ),

          TextButton(
            onPressed: (){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context)=>const SuccessPage(),
                ),
              );
            },
            child: const Text("Yes"),
          )

        ],
      ),
    );
  }

  Widget buildField(String label, TextEditingController controller){

    return Padding(
      padding: const EdgeInsets.only(bottom:10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Student View")),

      body: Center(

        child: Container(
          width: 350,
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: Colors.indigo,
            borderRadius: BorderRadius.circular(10),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              buildField("Mouse", mouse),
              buildField("Keyboard", keyboard),
              buildField("Monitor", monitor),
              buildField("Cables", cables),
              buildField("System Unit", system),

              const SizedBox(height:20),

              ElevatedButton(
                onPressed: submitReport,
                child: const Text("Submit"),
              )

            ],
          ),
        ),
      ),
    );
  }
}