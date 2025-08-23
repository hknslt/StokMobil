// lib/core/models/user.dart
class UserModel {
  final String uid;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String role;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: (data['email'] ?? '') as String,
      username: (data['username'] ?? '') as String,
      firstName: (data['firstName'] ?? '') as String,
      lastName: (data['lastName'] ?? '') as String,
      role: (data['role'] ?? 'user') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
    };
  }
}
