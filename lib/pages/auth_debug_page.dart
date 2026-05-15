import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

class AuthDebugPage extends StatelessWidget {
  const AuthDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Auth Debug"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user == null ? "PA GEN USER KONEKTE" : "USER KONEKTE",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("uid: ${user?.uid ?? ''}"),
                  Text("email: ${user?.email ?? ''}"),
                  Text("displayName: ${user?.displayName ?? ''}"),
                  Text("isAnonymous: ${user?.isAnonymous ?? ''}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (user != null)
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .get(),
              builder: (context, snap) {
                final data = snap.data?.data();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "USER DOC users/{currentUid}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (snap.connectionState == ConnectionState.waiting)
                          const CircularProgressIndicator()
                        else if (snap.hasError)
                          Text("Er: ${snap.error}")
                        else if (data == null)
                          const Text("Doc sa a pa egziste.")
                        else ...[
                          Text("uid: ${(data["uid"] ?? "-").toString()}"),
                          Text("role: ${(data["role"] ?? "-").toString()}"),
                          Text("email: ${(data["email"] ?? "-").toString()}"),
                          Text(
                              "displayName: ${(data["displayName"] ?? data["fullName"] ?? "-").toString()}"),
                          Text(
                              "enterpriseId: ${(data["enterpriseId"] ?? "-").toString()}"),
                          Text(
                              "enterpriseName: ${(data["enterpriseName"] ?? "-").toString()}"),
                          Text(
                              "isActive: ${(data["isActive"] ?? "-").toString()}"),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
