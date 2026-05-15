import 'package:flutter/material.dart';

class SoldePage extends StatelessWidget {
  const SoldePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Solde"),
        backgroundColor: const Color(0xFF2CA7A5),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12,blurRadius:6)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Solde",
                    style: TextStyle(fontSize:22,fontWeight:FontWeight.bold),
                  ),

                  const SizedBox(height:20),

                  const TextField(
                    decoration: InputDecoration(
                      labelText: "Tlphone",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height:15),

                  const TextField(
                    decoration: InputDecoration(
                      labelText: "Montant",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height:20),

                  ElevatedButton(
                    onPressed: (){},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6FB7C5),
                      padding: const EdgeInsets.symmetric(horizontal:30,vertical:15),
                    ),
                    child: const Text("Envoyer"),
                  ),

                ],
              ),
            )

          ],
        ),
      ),
    );
  }
}

