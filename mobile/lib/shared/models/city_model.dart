import 'package:cloud_firestore/cloud_firestore.dart';

class CityModel {
  final String id;
  final String name;
  final String state;
  final String country;
  final bool isActive;
  final DateTime? launchDate;
  final double? latitude;
  final double? longitude;

  const CityModel({
    required this.id,
    required this.name,
    required this.state,
    this.country = 'India',
    this.isActive = true,
    this.launchDate,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'country': country,
      'isActive': isActive,
      'launchDate': launchDate != null ? Timestamp.fromDate(launchDate!) : FieldValue.serverTimestamp(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory CityModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CityModel(
      id: id,
      name: map['name'] as String? ?? '',
      state: map['state'] as String? ?? '',
      country: map['country'] as String? ?? 'India',
      isActive: map['isActive'] as bool? ?? true,
      launchDate: parseTimestamp(map['launchDate']),
      latitude: (map['latitude'] as num?)?.toDouble() ?? (map['lat'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble() ?? (map['lng'] as num?)?.toDouble(),
    );
  }

  factory CityModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CityModel.fromMap(data, id: doc.id);
  }
}

