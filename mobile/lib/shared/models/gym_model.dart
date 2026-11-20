import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of commercial gym partnership with TRAIN Z platform
enum GymPartnershipStatus {
  active,
  pending,
  inactive;

  static GymPartnershipStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return GymPartnershipStatus.active;
      case 'pending':
        return GymPartnershipStatus.pending;
      case 'inactive':
      default:
        return GymPartnershipStatus.inactive;
    }
  }

  String get value {
    switch (this) {
      case GymPartnershipStatus.active:
        return 'active';
      case GymPartnershipStatus.pending:
        return 'pending';
      case GymPartnershipStatus.inactive:
        return 'inactive';
    }
  }
}

/// Represents a verified commercial gym facility where TRAIN Z sessions can take place.
class GymModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String? mapsUrl;
  final GymPartnershipStatus partnershipStatus;
  final double compensationPerSession; // INR compensation per hosted session
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GymModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.mapsUrl,
    this.partnershipStatus = GymPartnershipStatus.active,
    this.compensationPerSession = 150.0,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPartner => partnershipStatus == GymPartnershipStatus.active;

  /// Google Maps query link constructed from coordinates or name+address
  String get googleMapsUrl {
    if (mapsUrl != null && mapsUrl!.isNotEmpty) return mapsUrl!;
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'mapsUrl': mapsUrl,
      'partnershipStatus': partnershipStatus.value,
      'compensationPerSession': compensationPerSession,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory GymModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return GymModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Commercial Gym',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? 'Pune',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 18.5204,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 73.8567,
      mapsUrl: map['mapsUrl'] as String?,
      partnershipStatus: GymPartnershipStatus.fromString(map['partnershipStatus'] as String?),
      compensationPerSession: (map['compensationPerSession'] as num?)?.toDouble() ?? 150.0,
      contactPerson: map['contactPerson'] as String?,
      contactPhone: map['contactPhone'] as String?,
      contactEmail: map['contactEmail'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory GymModel.fromDocument(DocumentSnapshot doc) {
    return GymModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, id: doc.id);
  }

  GymModel copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    GymPartnershipStatus? partnershipStatus,
    double? compensationPerSession,
    String? contactPerson,
    String? contactPhone,
    String? contactEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GymModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapsUrl: mapsUrl ?? this.mapsUrl,
      partnershipStatus: partnershipStatus ?? this.partnershipStatus,
      compensationPerSession: compensationPerSession ?? this.compensationPerSession,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an aggregated gym compensation settlement record.
class GymSettlementModel {
  final String id;
  final String gymId;
  final String gymName;
  final int totalSessions;
  final double totalCompensation;
  final String settlementCycle; // e.g. "2026-W11", "2026-M03"
  final String status; // 'pending', 'processing', 'settled'
  final String? payoutTransactionId;
  final DateTime? createdAt;
  final DateTime? settledAt;

  const GymSettlementModel({
    required this.id,
    required this.gymId,
    required this.gymName,
    required this.totalSessions,
    required this.totalCompensation,
    required this.settlementCycle,
    this.status = 'pending',
    this.payoutTransactionId,
    this.createdAt,
    this.settledAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gymId': gymId,
      'gymName': gymName,
      'totalSessions': totalSessions,
      'totalCompensation': totalCompensation,
      'settlementCycle': settlementCycle,
      'status': status,
      'payoutTransactionId': payoutTransactionId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
    };
  }

  factory GymSettlementModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return GymSettlementModel(
      id: id ?? map['id'] as String? ?? '',
      gymId: map['gymId'] as String? ?? '',
      gymName: map['gymName'] as String? ?? '',
      totalSessions: (map['totalSessions'] as num?)?.toInt() ?? 0,
      totalCompensation: (map['totalCompensation'] as num?)?.toDouble() ?? 0.0,
      settlementCycle: map['settlementCycle'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      payoutTransactionId: map['payoutTransactionId'] as String?,
      createdAt: parseDate(map['createdAt']),
      settledAt: parseDate(map['settledAt']),
    );
  }

  factory GymSettlementModel.fromDocument(DocumentSnapshot doc) {
    return GymSettlementModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, id: doc.id);
  }
}
