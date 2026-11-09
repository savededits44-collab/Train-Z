import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlot {
  final String start; // e.g. "06:00"
  final String end;   // e.g. "07:00"
  final bool isBooked;

  const TimeSlot({
    required this.start,
    required this.end,
    this.isBooked = false,
  });

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
        'isBooked': isBooked,
      };

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: map['start'] as String? ?? '06:00',
      end: map['end'] as String? ?? '07:00',
      isBooked: map['isBooked'] as bool? ?? false,
    );
  }
}

class TrainerAvailabilityModel {
  final String id;
  final String trainerId;
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, ... 6 = Saturday
  final List<TimeSlot> timeSlots;
  final List<String> specificDateOverrides; // ISO string format YYYY-MM-DD (e.g. blackout dates)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrainerAvailabilityModel({
    required this.id,
    required this.trainerId,
    required this.dayOfWeek,
    this.timeSlots = const [],
    this.specificDateOverrides = const [],
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainerId': trainerId,
      'dayOfWeek': dayOfWeek,
      'timeSlots': timeSlots.map((s) => s.toMap()).toList(),
      'specificDateOverrides': specificDateOverrides,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TrainerAvailabilityModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawSlots = map['timeSlots'] as List<dynamic>? ?? [];
    final slots = rawSlots.map((s) => TimeSlot.fromMap(s as Map<String, dynamic>)).toList();

    return TrainerAvailabilityModel(
      id: id,
      trainerId: map['trainerId'] as String? ?? '',
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? 0,
      timeSlots: slots,
      specificDateOverrides: (map['specificDateOverrides'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory TrainerAvailabilityModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainerAvailabilityModel.fromMap(data, id: doc.id);
  }
}

