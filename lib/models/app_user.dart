import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, ngo, admin }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final UserRole role;
  final String? ngoName;
  final String? ngoAddress;
  final bool isVerified;
  final GeoPoint? location;
  final List<String> emergencyContacts;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.role,
    this.ngoName,
    this.ngoAddress,
    this.isVerified = false,
    this.location,
    this.emergencyContacts = const [],
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      role: UserRole.values.firstWhere(
        (e) => e.name == (map['role'] ?? 'user'),
        orElse: () => UserRole.user,
      ),
      ngoName: map['ngoName'],
      ngoAddress: map['ngoAddress'],
      isVerified: map['isVerified'] ?? false,
      location: map['location'],
      emergencyContacts: List<String>.from(map['emergencyContacts'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role.name,
      'ngoName': ngoName,
      'ngoAddress': ngoAddress,
      'isVerified': isVerified,
      'location': location,
      'emergencyContacts': emergencyContacts,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? photoUrl,
    UserRole? role,
    String? ngoName,
    String? ngoAddress,
    bool? isVerified,
    GeoPoint? location,
    List<String>? emergencyContacts,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      ngoName: ngoName ?? this.ngoName,
      ngoAddress: ngoAddress ?? this.ngoAddress,
      isVerified: isVerified ?? this.isVerified,
      location: location ?? this.location,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      createdAt: createdAt,
    );
  }
}