import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { sos, childHelp, animalRescue }

enum ReportStatus { pending, accepted, inProgress, resolved, rejected }

class ReportModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final ReportType type;
  final ReportStatus status;
  final String description;
  final GeoPoint location;
  final String address;
  final List<String> imageUrls;
  final String? assignedNgoId;
  final String? assignedNgoName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminNotes;
  final String? ngoNotes;

  ReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.type,
    required this.status,
    required this.description,
    required this.location,
    required this.address,
    this.imageUrls = const [],
    this.assignedNgoId,
    this.assignedNgoName,
    required this.createdAt,
    this.updatedAt,
    this.adminNotes,
    this.ngoNotes,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'sos'),
        orElse: () => ReportType.sos,
      ),
      status: ReportStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => ReportStatus.pending,
      ),
      description: map['description'] ?? '',
      location: map['location'] ?? const GeoPoint(0, 0),
      address: map['address'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      assignedNgoId: map['assignedNgoId'],
      assignedNgoName: map['assignedNgoName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      adminNotes: map['adminNotes'],
      ngoNotes: map['ngoNotes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'type': type.name,
      'status': status.name,
      'description': description,
      'location': location,
      'address': address,
      'imageUrls': imageUrls,
      'assignedNgoId': assignedNgoId,
      'assignedNgoName': assignedNgoName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'adminNotes': adminNotes,
      'ngoNotes': ngoNotes,
    };
  }

  ReportModel copyWith({
    ReportStatus? status,
    String? assignedNgoId,
    String? assignedNgoName,
    String? adminNotes,
    String? ngoNotes,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id,
      userId: userId,
      userName: userName,
      userPhone: userPhone,
      type: type,
      status: status ?? this.status,
      description: description,
      location: location,
      address: address,
      imageUrls: imageUrls,
      assignedNgoId: assignedNgoId ?? this.assignedNgoId,
      assignedNgoName: assignedNgoName ?? this.assignedNgoName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      ngoNotes: ngoNotes ?? this.ngoNotes,
    );
  }

  String get typeLabel {
    switch (type) {
      case ReportType.sos:
        return 'SOS Emergency';
      case ReportType.childHelp:
        return 'Child Help';
      case ReportType.animalRescue:
        return 'Animal Rescue';
    }
  }

  String get statusLabel {
    switch (status) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.accepted:
        return 'Accepted';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }
}