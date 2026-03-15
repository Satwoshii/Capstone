import 'package:flutter/material.dart';
import 'dashboardweb.dart';

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: Card(

          child: Padding(
            padding: const EdgeInsets.all(30),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Text(
                  "Report Sent",
                  style: TextStyle(fontSize: 22),
                ),

                const SizedBox(height:10),

                const Text("Current Status"),

                const SizedBox(height:20),

                ElevatedButton(
                  onPressed: (){
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context)=>const DashboardPage(),
                      ),
                    );
                  },
                  child: const Text("Close"),
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}