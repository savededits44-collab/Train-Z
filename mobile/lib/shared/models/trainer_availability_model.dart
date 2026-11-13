import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper to convert standard time strings (e.g. "06:00 AM", "01:30 PM") to total minutes from midnight
int timeStringToMinutes(String timeStr) {
  final clean = timeStr.trim().toUpperCase();
  final parts = clean.split(' ');
  final timeParts = (parts[0]).split(':');
  int hour = int.tryParse(timeParts[0]) ?? 0;
  final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
  final isPm = parts.length > 1 && parts[1] == 'PM';
  final isAm = parts.length > 1 && parts[1] == 'AM';

  if (isPm && hour != 12) hour += 12;
  if (isAm && hour == 12) hour = 0;
  return hour * 60 + minute;
}

/// Helper to convert total minutes from midnight to standard time strings (e.g. 360 -> "06:00 AM")
String minutesToTimeString(int minutes) {
  final totalMin = ((minutes % 1440) + 1440) % 1440;
  int hour = totalMin ~/ 60;
  final minute = totalMin % 60;
  final period = hour >= 12 ? 'PM' : 'AM';
  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }
  final hStr = hour.toString().padLeft(2, '0');
  final mStr = minute.toString().padLeft(2, '0');
  return '$hStr:$mStr $period';
}

/// Represents an atomic 60-minute training session slot
class TimeSlot {
  final String start; // e.g. "06:00 AM"
  final String end;   // e.g. "07:00 AM"
  final bool isBooked;
  final bool isReserved; // Temporarily reserved during 15-min checkout hold
  final bool isPast;     // Start time has already elapsed for today
  final String? bookedByClientName;
  final String? bookingId;
  final int sessionDurationMinutes; // Fixed at 60 minutes per TRAIN Z policy

  const TimeSlot({
    required this.start,
    required this.end,
    this.isBooked = false,
    this.isReserved = false,
    this.isPast = false,
    this.bookedByClientName,
    this.bookingId,
    this.sessionDurationMinutes = 60,
  });

  bool get isAvailable => !isBooked && !isReserved && !isPast;

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
        'isBooked': isBooked,
        'isReserved': isReserved,
        'isPast': isPast,
        if (bookedByClientName != null) 'bookedByClientName': bookedByClientName,
        if (bookingId != null) 'bookingId': bookingId,
        'sessionDurationMinutes': sessionDurationMinutes,
      };

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: map['start'] as String? ?? '06:00 AM',
      end: map['end'] as String? ?? '07:00 AM',
      isBooked: map['isBooked'] as bool? ?? false,
      isReserved: map['isReserved'] as bool? ?? false,
      isPast: map['isPast'] as bool? ?? false,
      bookedByClientName: map['bookedByClientName'] as String?,
      bookingId: map['bookingId'] as String?,
      sessionDurationMinutes: (map['sessionDurationMinutes'] as num?)?.toInt() ?? 60,
    );
  }

  TimeSlot copyWith({
    String? start,
    String? end,
    bool? isBooked,
    bool? isReserved,
    bool? isPast,
    String? bookedByClientName,
    String? bookingId,
    int? sessionDurationMinutes,
  }) {
    return TimeSlot(
      start: start ?? this.start,
      end: end ?? this.end,
      isBooked: isBooked ?? this.isBooked,
      isReserved: isReserved ?? this.isReserved,
      isPast: isPast ?? this.isPast,
      bookedByClientName: bookedByClientName ?? this.bookedByClientName,
      bookingId: bookingId ?? this.bookingId,
      sessionDurationMinutes: sessionDurationMinutes ?? this.sessionDurationMinutes,
    );
  }
}

/// A contiguous availability time window defined by a Trainer (e.g. 06:00 AM - 11:00 AM)
class AvailabilityWindow {
  final String start; // e.g. "06:00 AM"
  final String end;   // e.g. "11:00 AM"

  const AvailabilityWindow({
    required this.start,
    required this.end,
  });

  int get startMinutes => timeStringToMinutes(start);
  int get endMinutes => timeStringToMinutes(end);
  int get durationMinutes => endMinutes - startMinutes;

  /// Duration must be at least 60 minutes for a valid training window
  bool get isValid => durationMinutes >= 60;

  /// Detects whether this window overlaps with another window on the same day
  bool overlapsWith(AvailabilityWindow other) {
    return startMinutes < other.endMinutes && endMinutes > other.startMinutes;
  }

  /// Generates discrete 60-minute training session slots within this window
  List<TimeSlot> generate60MinSlots({bool isToday = false, int currentMinutes = 0}) {
    final slots = <TimeSlot>[];
    int curr = startMinutes;
    while (curr + 60 <= endMinutes) {
      final s = minutesToTimeString(curr);
      final e = minutesToTimeString(curr + 60);
      final isPast = isToday && curr <= currentMinutes;
      slots.add(TimeSlot(
        start: s,
        end: e,
        isPast: isPast,
      ));
      curr += 60;
    }
    return slots;
  }

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
      };

  factory AvailabilityWindow.fromMap(Map<String, dynamic> map) {
    return AvailabilityWindow(
      start: map['start'] as String? ?? '06:00 AM',
      end: map['end'] as String? ?? '07:00 AM',
    );
  }
}

/// Day of week availability (1 = Monday, 7 = Sunday)
class DayAvailability {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final bool isEnabled;
  final List<AvailabilityWindow> windows;

  const DayAvailability({
    required this.dayOfWeek,
    this.isEnabled = true,
    this.windows = const [],
  });

  static const List<String> _dayNames = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _dayShorts = [
    '',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  String get dayName => (dayOfWeek >= 1 && dayOfWeek <= 7) ? _dayNames[dayOfWeek] : 'Day';
  String get dayShort => (dayOfWeek >= 1 && dayOfWeek <= 7) ? _dayShorts[dayOfWeek] : 'DAY';

  /// Generates all 60-minute slots for this day across all non-overlapping windows.
  /// Gaps between windows represent breaks.
  List<TimeSlot> generateSlots({bool isToday = false, int currentMinutes = 0}) {
    if (!isEnabled || windows.isEmpty) return const [];
    final sorted = List<AvailabilityWindow>.from(windows)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final slots = <TimeSlot>[];
    for (final w in sorted) {
      slots.addAll(w.generate60MinSlots(isToday: isToday, currentMinutes: currentMinutes));
    }
    return slots;
  }

  DayAvailability copyWith({
    int? dayOfWeek,
    bool? isEnabled,
    List<AvailabilityWindow>? windows,
  }) {
    return DayAvailability(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      windows: windows ?? this.windows,
    );
  }

  Map<String, dynamic> toMap() => {
        'dayOfWeek': dayOfWeek,
        'isEnabled': isEnabled,
        'windows': windows.map((w) => w.toMap()).toList(),
      };

  factory DayAvailability.fromMap(Map<String, dynamic> map) {
    final rawWindows = map['windows'] as List<dynamic>? ?? [];
    return DayAvailability(
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? 1,
      isEnabled: map['isEnabled'] as bool? ?? true,
      windows: rawWindows.map((w) => AvailabilityWindow.fromMap(w as Map<String, dynamic>)).toList(),
    );
  }
}

/// Date-specific availability override (blackout/blocked date or customized hours)
class TrainerDateOverride {
  final String date; // YYYY-MM-DD
  final bool isBlocked; // true = whole day off (leave, emergency, vacation)
  final List<AvailabilityWindow> customWindows; // customized windows for this specific date
  final String? reason; // e.g. "Personal Leave", "Medical Appointment"

  const TrainerDateOverride({
    required this.date,
    this.isBlocked = false,
    this.customWindows = const [],
    this.reason,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'isBlocked': isBlocked,
        'customWindows': customWindows.map((w) => w.toMap()).toList(),
        if (reason != null) 'reason': reason,
      };

  factory TrainerDateOverride.fromMap(Map<String, dynamic> map) {
    final rawWindows = map['customWindows'] as List<dynamic>? ?? map['windows'] as List<dynamic>? ?? [];
    return TrainerDateOverride(
      date: map['date'] as String? ?? '',
      isBlocked: map['isBlocked'] as bool? ?? false,
      customWindows: rawWindows.map((w) => AvailabilityWindow.fromMap(w as Map<String, dynamic>)).toList(),
      reason: map['reason'] as String?,
    );
  }
}

/// Comprehensive Trainer Availability Model
class TrainerAvailabilityModel {
  final String id;
  final String trainerId;
  final String timezone; // default 'Asia/Kolkata' (IST)
  final List<DayAvailability> days;
  final List<TrainerDateOverride> overrides;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Backward compatibility fields
  final int? _legacyDayOfWeek;
  final List<TimeSlot>? _legacyTimeSlots;
  final List<String>? _legacySpecificDateOverrides;

  const TrainerAvailabilityModel({
    required this.id,
    required this.trainerId,
    this.timezone = 'Asia/Kolkata',
    this.days = const [],
    this.overrides = const [],
    this.createdAt,
    this.updatedAt,
    int? dayOfWeek,
    List<TimeSlot>? timeSlots,
    List<String>? specificDateOverrides,
  })  : // ignore: prefer_initializing_formals
        _legacyDayOfWeek = dayOfWeek,
        // ignore: prefer_initializing_formals
        _legacyTimeSlots = timeSlots,
        // ignore: prefer_initializing_formals
        _legacySpecificDateOverrides = specificDateOverrides;

  int get dayOfWeek => _legacyDayOfWeek ?? (days.isNotEmpty ? days.first.dayOfWeek : 1);
  List<TimeSlot> get timeSlots => _legacyTimeSlots ?? (days.isNotEmpty ? days.first.generateSlots() : const []);
  List<String> get specificDateOverrides =>
      _legacySpecificDateOverrides ?? overrides.where((o) => o.isBlocked).map((o) => o.date).toList();

  DayAvailability day(int dayOfWeek) {
    final match = days.where((d) => d.dayOfWeek == dayOfWeek);
    if (match.isNotEmpty) return match.first;
    return DayAvailability(
      dayOfWeek: dayOfWeek,
      isEnabled: dayOfWeek != 7, // Sunday off by default
      windows: const [
        AvailabilityWindow(start: '06:00 AM', end: '11:00 AM'),
        AvailabilityWindow(start: '04:00 PM', end: '08:00 PM'),
      ],
    );
  }

  TrainerDateOverride? overrideForDate(DateTime dt) {
    final dStr = dt.toIso8601String().substring(0, 10);
    final match = overrides.where((o) => o.date == dStr);
    return match.isNotEmpty ? match.first : null;
  }

  bool isDateBlocked(DateTime dt) {
    final ov = overrideForDate(dt);
    return ov != null && ov.isBlocked;
  }

  /// Calculates discrete 60-minute time slots for any specific date,
  /// respecting weekly schedule, date overrides, breaks, confirmed bookings, and active temporary holds.
  List<TimeSlot> getSlotsForDate(
    DateTime date, {
    Set<String> confirmedStarts = const {},
    Set<String> reservedStarts = const {},
    Map<String, String> bookingClientNames = const {},
    Map<String, String> bookingIds = const {},
    String? currentClientId,
  }) {
    final ov = overrideForDate(date);

    // If whole date is blocked by trainer, return empty list
    if (ov != null && ov.isBlocked) {
      return const [];
    }

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isPastDate = DateTime(date.year, date.month, date.day).isBefore(DateTime(now.year, now.month, now.day));
    final currentMinutes = now.hour * 60 + now.minute;

    List<TimeSlot> baseSlots;

    if (ov != null && ov.customWindows.isNotEmpty) {
      // Use date-specific custom windows
      final sorted = List<AvailabilityWindow>.from(ov.customWindows)
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      baseSlots = [];
      for (final w in sorted) {
        baseSlots.addAll(w.generate60MinSlots(isToday: isToday, currentMinutes: currentMinutes));
      }
    } else {
      // Use weekly recurring schedule (1 = Monday, 7 = Sunday)
      final jsDay = date.weekday; // DateTime.weekday: 1 = Mon ... 7 = Sun
      final dayConfig = day(jsDay);
      if (!dayConfig.isEnabled) return const [];
      baseSlots = dayConfig.generateSlots(isToday: isToday, currentMinutes: currentMinutes);
    }

    // Apply bookings, holds, and past flags
    return baseSlots.map((s) {
      final startNorm = s.start.trim().toUpperCase();
      final isBooked = confirmedStarts.contains(startNorm);
      final isReserved = !isBooked && reservedStarts.contains(startNorm);
      final isPast = isPastDate || (isToday && timeStringToMinutes(s.start) <= currentMinutes);

      return s.copyWith(
        isBooked: isBooked,
        isReserved: isReserved,
        isPast: isPast,
        bookedByClientName: bookingClientNames[startNorm],
        bookingId: bookingIds[startNorm],
      );
    }).toList();
  }

  /// Default baseline schedule for newly created or unconfigured trainers:
  /// Mon - Sat: 06:00 AM - 11:00 AM (Break: 11:00 AM - 04:00 PM), 04:00 PM - 08:00 PM
  /// Sunday: Rest Day (Disabled)
  static TrainerAvailabilityModel defaultSchedule(String trainerId) {
    final days = List.generate(7, (i) {
      final d = i + 1; // 1 = Monday .. 7 = Sunday
      final isSun = d == 7;
      return DayAvailability(
        dayOfWeek: d,
        isEnabled: !isSun,
        windows: isSun
            ? const []
            : const [
                AvailabilityWindow(start: '06:00 AM', end: '11:00 AM'),
                AvailabilityWindow(start: '04:00 PM', end: '08:00 PM'),
              ],
      );
    });

    return TrainerAvailabilityModel(
      id: '${trainerId}_weekly',
      trainerId: trainerId,
      timezone: 'Asia/Kolkata',
      days: days,
      overrides: const [],
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainerId': trainerId,
      'timezone': timezone,
      'days': days.map((d) => d.toMap()).toList(),
      'overrides': overrides.map((o) => o.toMap()).toList(),
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

    final rawDays = map['days'] as List<dynamic>? ?? [];
    final days = rawDays.map((d) => DayAvailability.fromMap(d as Map<String, dynamic>)).toList();

    final rawOverrides = map['overrides'] as List<dynamic>? ?? [];
    final overrides = rawOverrides.map((o) => TrainerDateOverride.fromMap(o as Map<String, dynamic>)).toList();

    // Legacy fallback
    final rawSlots = map['timeSlots'] as List<dynamic>? ?? [];
    final slots = rawSlots.map((s) => TimeSlot.fromMap(s as Map<String, dynamic>)).toList();
    final legacyOverrides = (map['specificDateOverrides'] as List<dynamic>?)?.map((e) => e.toString()).toList();

    return TrainerAvailabilityModel(
      id: id,
      trainerId: map['trainerId'] as String? ?? '',
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      days: days.isNotEmpty ? days : TrainerAvailabilityModel.defaultSchedule(map['trainerId'] as String? ?? '').days,
      overrides: overrides,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt(),
      timeSlots: slots.isNotEmpty ? slots : null,
      specificDateOverrides: legacyOverrides,
    );
  }

  factory TrainerAvailabilityModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainerAvailabilityModel.fromMap(data, id: doc.id);
  }
}
