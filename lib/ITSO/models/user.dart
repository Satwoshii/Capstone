class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // 'itso' | 'teacher' | 'student'

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isItso => role.toLowerCase() == 'itso';
  bool get isTeacher => role.toLowerCase() == 'teacher';
  bool get isStudent => role.toLowerCase() == 'student';
}