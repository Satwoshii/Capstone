import '../models/user.dart';

abstract class AuthRepository {
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();
}

class MockAuthRepository implements AuthRepository {
  AppUser? _current;

  static final Map<String, AppUser> _users = {
    'admin@nu-clark.edu.ph': const AppUser(
        uid: 'admin1', name: 'Admin ITSO', email: 'admin@nu-clark.edu.ph', role: 'itso'),
    'itso@nu-clark.edu.ph': const AppUser(
        uid: 'u1', name: 'ITSO Personnel', email: 'itso@nu-clark.edu.ph', role: 'itso'),
    'teacher@nu-clark.edu.ph': const AppUser(
        uid: 'u2', name: 'Teacher One', email: 'teacher@nu-clark.edu.ph', role: 'teacher'),
    'student@nu-clark.edu.ph': const AppUser(
        uid: 'u3', name: 'Student One', email: 'student@nu-clark.edu.ph', role: 'student'),
  };

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final key = email.trim().toLowerCase();
    final user = _users[key];
    if (user == null) {
      throw Exception('Invalid credentials or unauthorized.');
    }
    // Mock mode: password not enforced for demo accounts
    _current = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }
}