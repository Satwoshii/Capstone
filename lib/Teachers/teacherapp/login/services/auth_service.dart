import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class TeacherAuthService {
  final users = FirebaseFirestore.instance.collection("users");

  Future<void> register(String email, String password) async {
    final cleanEmail = email.trim();

    final existingUser =
    await users.where("email", isEqualTo: cleanEmail).limit(1).get();

    if (existingUser.docs.isNotEmpty) {
      throw "An account with this email already exists.";
    }

    final hashedPassword =
    BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));

    await users.add({
      "email": cleanEmail,
      "password": hashedPassword,
      "role": "Teacher",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim();

    final result =
    await users.where("email", isEqualTo: cleanEmail).limit(1).get();

    if (result.docs.isEmpty) {
      return {
        "success": false,
        "message": "Account not found.",
      };
    }

    final doc = result.docs.first;
    final user = doc.data();

    final role = (user["role"] ?? "").toString().trim();
    final storedPassword = (user["password"] ?? "").toString();

    if (role.toLowerCase() != "teacher") {
      return {
        "success": false,
        "message": "Access denied. This portal is for Teacher accounts only.",
      };
    }

    if (!BCrypt.checkpw(password, storedPassword)) {
      return {
        "success": false,
        "message": "Invalid password.",
      };
    }

    return {
      "success": true,
      "message": "Login successful.",
      "user": {
        "uid": doc.id,
        "email": user["email"],
        "role": role,
      }
    };
  }
}