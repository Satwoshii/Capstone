import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class AuthService {

  final users = FirebaseFirestore.instance.collection("users");

  Future register(String email, String password) async {

    String hashedPassword =
    BCrypt.hashpw(password, BCrypt.gensalt());

    await users.add({
      "email": email,
      "password": hashedPassword
    });
  }

  Future<bool> login(String email, String password) async {

    var result =
    await users.where("email", isEqualTo: email).get();

    if (result.docs.isEmpty) {
      return false;
    }

    var user = result.docs.first.data();

    return BCrypt.checkpw(password, user["password"]);
  }
}