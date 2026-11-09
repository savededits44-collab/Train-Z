import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformSettingsModel {
  final String id;
  final int minCancellationHours; // 12
  final int sessionDurationMinutes; // 60
  final int platformFeePercent; // e.g. 15
  final String supportEmail;
  final String appVersionMin;
  final bool isMaintenanceMode;
  final DateTime? updatedAt;

  const PlatformSettingsModel({
    this.id = 'general',
    this.minCancellationHours = 12,
    this.sessionDurationMinutes = 60,
    this.platformFeePercent = 15,
    this.supportEmail = 'support@trainz.app',
    this.appVersionMin = '1.0.0',
    this.isMaintenanceMode = false,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'minCancellationHours': minCancellationHours,
      'sessionDurationMinutes': sessionDurationMinutes,
      'platformFeePercent': platformFeePercent,
      'supportEmail': supportEmail,
      'appVersionMin': appVersionMin,
      'isMaintenanceMode': isMaintenanceMode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PlatformSettingsModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PlatformSettingsModel(
      id: id,
      minCancellationHours: (map['minCancellationHours'] as num?)?.toInt() ?? 12,
      sessionDurationMinutes: (map['sessionDurationMinutes'] as num?)?.toInt() ?? 60,
      platformFeePercent: (map['platformFeePercent'] as num?)?.toInt() ?? 15,
      supportEmail: map['supportEmail'] as String? ?? 'support@trainz.app',
      appVersionMin: map['appVersionMin'] as String? ?? '1.0.0',
      isMaintenanceMode: map['isMaintenanceMode'] as bool? ?? false,
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory PlatformSettingsModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PlatformSettingsModel.fromMap(data, id: doc.id);
  }
}

