enum UserRole { admin, teacher, assistant, student }

enum UserStatus { pending, active, inactive, blocked }

class Profile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final DateTime? birthDate;
  final String? avatarUrl;
  final String? bio;
  final String? rejectionReason;
  final UserRole role;
  final UserStatus status;
  final Map<String, dynamic>? notificationPreferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.birthDate,
    this.avatarUrl,
    this.bio,
    this.rejectionReason,
    required this.role,
    required this.status,
    this.notificationPreferences,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      role: UserRole.values.byName(json['role'] as String),
      status: UserStatus.values.byName(json['status'] as String),
      notificationPreferences:
          json['notification_preferences'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'avatar_url': avatarUrl,
      'bio': bio,
      'rejection_reason': rejectionReason,
      'role': role.name,
      'status': status.name,
      'notification_preferences': notificationPreferences,
    };
  }

  Profile copyWith({
    String? fullName,
    String? phone,
    DateTime? birthDate,
    String? avatarUrl,
    String? bio,
    Map<String, dynamic>? notificationPreferences,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      rejectionReason: rejectionReason,
      role: role,
      status: status,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  bool get isActive => status == UserStatus.active;
  bool get pushEnabled =>
      (notificationPreferences?['push'] as bool?) ?? true;
  bool get emailEnabled =>
      (notificationPreferences?['email'] as bool?) ?? true;
  bool get communityNotifications =>
      (notificationPreferences?['community'] as bool?) ?? true;
}
