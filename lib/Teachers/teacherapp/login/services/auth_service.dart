import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class TeacherAuthService {
  final users = FirebaseFirestore.instance.collection("users");

  Future<void> register(String email, String password) async {
    final existingUser = await users.where("email", isEqualTo: email).get();

    if (existingUser.docs.isNotEmpty) {
      throw "An account with this email already exists.";
    }

    final hashedPassword =
    BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));

    await users.add({
      "email": email,
      "password": hashedPassword,
      "role": "Teacher",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final result = await users.where("email", isEqualTo: email).get();

    if (result.docs.isEmpty) return null;

    final doc = result.docs.first;
    final user = doc.data();

    if (user["role"] != "Teacher") return null;

    if (BCrypt.checkpw(password, user["password"])) {
      return {
        "uid": doc.id,
        "email": user["email"],
        "role": user["role"],
      };
    }

    return null;
  }
}