import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore for database operations
import 'package:bcrypt/bcrypt.dart'; // Import BCrypt for secure password hashing and verification

// Service class to handle authentication logic (register and login)
class AuthService {
  // Reference to the "users" collection in Firestore
  final users = FirebaseFirestore.instance.collection("users");

  // Asynchronous function to register a new user
  Future<void> register(String email, String password) async {
    // 1. Check if a user with the given email already exists in the database
    final existingUser = await users.where("email", isEqualTo: email).get();
    if (existingUser.docs.isNotEmpty) {
      // If a match is found, throw an error to be caught by the UI
      throw "An account with this email already exists.";
    }

    // 2. Hash the user's password using BCrypt with a cost factor of 12 for security
    final String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));

    // 3. Add the new user's document to the "users" collection
    await users.add({
      "email": email, // Store the email
      "password": hashedPassword, // Store the hashed password (never plain text)
      "role": "student", // Assign the default role as "student"
      "createdAt": FieldValue.serverTimestamp(), // Store the creation time using server-side clock
    });
  }

  // Asynchronous function to authenticate a user during login
  Future<Map<String, dynamic>?> login(String email, String password) async {
    // Query Firestore for a user with the matching email
    final result = await users.where("email", isEqualTo: email).get();

    // If no user is found with that email, return null
    if (result.docs.isEmpty) {
      return null;
    }

    // Get the first document matching the query
    final doc = result.docs.first;
    // Extract the user data from the document
    final user = doc.data();

    // Verify if the provided plain-text password matches the stored hashed password
    if (BCrypt.checkpw(password, user["password"])) {
      // If the password is correct, return a map of user data (useful for JWT generation)
      return {
        "uid": doc.id, // Include the Firestore document ID
        "email": user["email"], // Include the email
        "role": user["role"] ?? "student" // Include the role (defaulting to student if missing)
      };
    }
    
    // If the password check fails, return null
    return null;
  }
}
