import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JWTService {

  static const secretKey = "capstone_secret_key";

  static String generateToken(String email) {

    final jwt = JWT({
      "email": email,
      "time": DateTime.now().toString()
    });

    return jwt.sign(SecretKey(secretKey));
  }
}