// TODO: Define User entity model
class UserEntity {
  final String uid;
  final String username;
  final String email;
  final String? profilePhotoUrl;
  final String role; // 'user' or 'admin'
  final List<String> favoriteStalls;
  final String? fcmToken;
  final DateTime createdAt;

  UserEntity({
    required this.uid,
    required this.username,
    required this.email,
    this.profilePhotoUrl,
    required this.role,
    this.favoriteStalls = const [],
    this.fcmToken,
    required this.createdAt,
  });

  // TODO: Add fromJson, toJson, copyWith methods
}
