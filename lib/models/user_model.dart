// TODO: Define User Model for shared use
class UserModel {
  final String uid;
  final String username;
  final String email;
  final String? profilePhotoUrl;
  final String role;
  final List<String> favoriteStalls;
  final String? fcmToken;
  final DateTime createdAt;

  UserModel({
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
  factory UserModel.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
  }

  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}
