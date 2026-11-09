import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  client,
  trainer,
  admin;

  String toFirestore() {
    switch (this) {
      case UserRole.client:
        return 'CLIENT';
      case UserRole.trainer:
        return 'TRAINER';
      case UserRole.admin:
        return 'ADMIN';
    }
  }

  static UserRole? fromFirestore(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim().toUpperCase();
    if (str == 'CLIENT') return UserRole.client;
    if (str == 'TRAINER') return UserRole.trainer;
    if (str == 'ADMIN') return UserRole.admin;
    return null;
  }
}

enum Gender {
  male,
  female;

  String toFirestore() {
    switch (this) {
      case Gender.male:
        return 'MALE';
      case Gender.female:
        return 'FEMALE';
    }
  }

  static Gender? fromFirestore(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim().toUpperCase();
    if (str == 'MALE') return Gender.male;
    if (str == 'FEMALE') return Gender.female;
    return null;
  }
}

enum UserStatus {
  active,
  suspended;

  String toFirestore() => name.toUpperCase();

  static UserStatus fromFirestore(dynamic val) {
    if (val == null) return UserStatus.active;
    final str = val.toString().trim().toUpperCase();
    return str == 'SUSPENDED' ? UserStatus.suspended : UserStatus.active;
  }
}

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole? role;
  final Gender? gender;
  final UserStatus status;
  final bool isEmailVerified;
  final bool isOnboarded;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.role,
    this.gender,
    this.status = UserStatus.active,
    this.isEmailVerified = false,
    this.isOnboarded = false,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  bool get isClient => role == UserRole.client;
  bool get isTrainer => role == UserRole.trainer;
  bool get isAdmin => role == UserRole.admin;
  bool get isActive => status == UserStatus.active;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'role': role?.toFirestore(),
      'gender': gender?.toFirestore(),
      'status': status.toFirestore(),
      'isEmailVerified': isEmailVerified,
      'onboarded': isOnboarded,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? map['name'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: UserRole.fromFirestore(map['role']),
      gender: Gender.fromFirestore(map['gender']),
      status: UserStatus.fromFirestore(map['status']),
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
      isOnboarded: map['onboarded'] as bool? ?? false,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      lastLoginAt: parseTimestamp(map['lastLoginAt']),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, uid: doc.id);
  }

  UserModel copyWith({
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    UserRole? role,
    Gender? gender,
    UserStatus? status,
    bool? isEmailVerified,
    bool? isOnboarded,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

