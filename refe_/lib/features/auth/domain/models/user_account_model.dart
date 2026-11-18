class UserAccountModel {
  final String id;
  final String username;
  final String password;
  final String displayName;
  final String role;
  final DateTime createdAt;

  const UserAccountModel({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    this.role = 'Engenharia Estrutural & BIM',
    required this.createdAt,
  });

  factory UserAccountModel.fromMap(Map<String, dynamic> map) {
    return UserAccountModel(
      id: map['id'] as String? ?? 'usr-default',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Engenheiro BIM',
      role: map['role'] as String? ?? 'Engenharia Estrutural & BIM',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime(2026, 1, 1)
          : DateTime(2026, 1, 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'displayName': displayName,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
