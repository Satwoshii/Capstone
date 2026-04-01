import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart'; // Import the JWT library for token operations

class JWTService { // Define a service class for JWT-related functionality

  static const secretKey = "capstone_secret_key"; // Define a secret key used for signing and verifying tokens

  // Define a method to generate a JWT from a user's data map
  static String generateToken(Map<String, dynamic> user) {

    final jwt = JWT({ // Create a new JWT instance with a payload
      "uid": user["uid"], // Store the user's unique ID in the token
      "email": user["email"], // Store the user's email address in the token
      "role": user["role"], // Store the user's assigned role in the token
      "iat": DateTime.now().millisecondsSinceEpoch ~/ 1000, // Add an "issued at" timestamp in seconds
    },
      issuer: 'nu-clark-system', // Identify the entity that issued the token
    );

    // Return the signed token as a string
    return jwt.sign(
        SecretKey(secretKey), // Use the secret key for HMAC SHA-256 signing
        expiresIn: const Duration(days: 7), // Set the token expiration time to 7 days
        algorithm: JWTAlgorithm.HS256 // Use the industry-standard HS256 algorithm
    );
  }

  // Define a method to verify a JWT and extract its payload
  static Map<String, dynamic>? verifyToken(String token) {
    try { // Use a try-catch block to handle potential verification errors
      final jwt = JWT.verify(token, SecretKey(secretKey)); // Verify the token's signature using the secret key
      return jwt.payload as Map<String, dynamic>; // Return the decoded payload data if successful
    } catch (e) { // Catch any errors, such as an expired or invalid token
      return null; // Return null if the token cannot be verified
    }
  }
}