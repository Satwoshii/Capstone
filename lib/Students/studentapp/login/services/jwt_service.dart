import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JWTService {
  static const secretKey = "capstone_secret_key";

  static String generateToken(Map<String, dynamic> user) {
    final jwt = JWT(
      {
        "uid": user["uid"],
        "email": user["email"],
        "full_name": user["full_name"] ?? user["name"] ?? "Student",
        "name": user["full_name"] ?? user["name"] ?? "Student",
        "role": user["role"],
        "iat": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      issuer: 'nu-clark-system',
    );

    return jwt.sign(
      SecretKey(secretKey),
      expiresIn: const Duration(days: 7),
      algorithm: JWTAlgorithm.HS256,
    );
  }

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secretKey));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}