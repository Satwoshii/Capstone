import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class AuthService {
  final users = FirebaseFirestore.instance.collection("users");

  Future<void> register(String fullName, String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim();

    if (normalizedName.isEmpty) {
      throw "Full name is required.";
    }

    final existingUser = await users.where("email", isEqualTo: normalizedEmail).get();
    if (existingUser.docs.isNotEmpty) {
      throw "An account with this email already exists.";
    }

    final String hashedPassword = BCrypt.hashpw(
      password,
      BCrypt.gensalt(logRounds: 12),
    );

    await users.add({
      "full_name": normalizedName,
      "name": normalizedName,
      "email": normalizedEmail,
      "password": hashedPassword,
      "role": "student",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final result = await users.where("email", isEqualTo: normalizedEmail).get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final user = doc.data();

    if (BCrypt.checkpw(password, user["password"])) {
      final fullName = (user["full_name"] ?? user["name"] ?? "Student").toString();
      return {
        "uid": doc.id,
        "email": user["email"],
        "full_name": fullName,
        "name": fullName,
        "role": user["role"] ?? "student",
      };
    }

    return null;
  }
}