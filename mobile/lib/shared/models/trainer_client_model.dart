import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_model.dart';
import 'user_model.dart';

/// Relationship status between Trainer and Client.
enum TrainerClientStatus {
  active,
  past;

  String get displayName => this == TrainerClientStatus.active ? 'Active' : 'Past';
}

/// Represents an aggregated Client profile specifically for the authenticated Trainer.
class TrainerClientModel {
  final String clientId;
  final String name;
  final String? photoUrl;
  final Gender? gender;
  final String? fitnessGoal;
  final String? fitnessLevel;
  final String? activePackageName;
  final int totalSessions;
  final int completedSessions;
  final int remainingSessions;
  final DateTime? nextSessionDate;
  final String? nextSessionTime;
  final DateTime? lastCompletedSessionDate;
  final TrainerClientStatus status;
  final DateTime? firstSessionDate;
  final int totalBookingsCount;
  final List<BookingModel> bookings;

  const TrainerClientModel({
    required this.clientId,
    required this.name,
    this.photoUrl,
    this.gender,
    this.fitnessGoal,
    this.fitnessLevel,
    this.activePackageName,
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.remainingSessions = 0,
    this.nextSessionDate,
    this.nextSessionTime,
    this.lastCompletedSessionDate,
    this.status = TrainerClientStatus.active,
    this.firstSessionDate,
    this.totalBookingsCount = 0,
    this.bookings = const [],
  });

  bool get isActive => status == TrainerClientStatus.active;
  bool get hasUpcomingSession => nextSessionDate != null;

  String get displayInitial {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'C';
  }

  String get formattedNextSession {
    if (nextSessionDate == null) return 'No upcoming session';
    final d = nextSessionDate!;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final timeStr = nextSessionTime != null && nextSessionTime!.isNotEmpty ? ' • ${nextSessionTime!}' : '';
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}$timeStr';
  }

  String get formattedLastSession {
    if (lastCompletedSessionDate == null) return 'No completed sessions';
    final d = lastCompletedSessionDate!;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get formattedMemberSince {
    if (firstSessionDate == null) return 'Recent Client';
    final d = firstSessionDate!;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  String get packageSummary {
    if (activePackageName == null || activePackageName!.isEmpty) {
      return 'Standard Booking';
    }
    return activePackageName!;
  }

  TrainerClientModel copyWith({
    String? clientId,
    String? name,
    String? photoUrl,
    Gender? gender,
    String? fitnessGoal,
    String? fitnessLevel,
    String? activePackageName,
    int? totalSessions,
    int? completedSessions,
    int? remainingSessions,
    DateTime? nextSessionDate,
    String? nextSessionTime,
    DateTime? lastCompletedSessionDate,
    TrainerClientStatus? status,
    DateTime? firstSessionDate,
    int? totalBookingsCount,
    List<BookingModel>? bookings,
  }) {
    return TrainerClientModel(
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      activePackageName: activePackageName ?? this.activePackageName,
      totalSessions: totalSessions ?? this.totalSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      remainingSessions: remainingSessions ?? this.remainingSessions,
      nextSessionDate: nextSessionDate ?? this.nextSessionDate,
      nextSessionTime: nextSessionTime ?? this.nextSessionTime,
      lastCompletedSessionDate: lastCompletedSessionDate ?? this.lastCompletedSessionDate,
      status: status ?? this.status,
      firstSessionDate: firstSessionDate ?? this.firstSessionDate,
      totalBookingsCount: totalBookingsCount ?? this.totalBookingsCount,
      bookings: bookings ?? this.bookings,
    );
  }
}

/// A private note maintained exclusively by the Trainer for an individual Client.
/// Strictly non-medical coaching observations.
class TrainerClientNoteModel {
  final String id;
  final String trainerId;
  final String clientId;
  final String title;
  final String content;
  final String category; // e.g. 'Observation', 'Session', 'Form & Technique', 'General'
  final DateTime? sessionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrainerClientNoteModel({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.title,
    required this.content,
    this.category = 'Observation',
    this.sessionDate,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedCreatedAt {
    if (createdAt == null) return '';
    final d = createdAt!;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$min';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainerId': trainerId,
      'clientId': clientId,
      'title': title,
      'content': content,
      'category': category,
      'sessionDate': sessionDate != null ? Timestamp.fromDate(sessionDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TrainerClientNoteModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TrainerClientNoteModel(
      id: id,
      trainerId: map['trainerId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      title: map['title'] as String? ?? 'Training Note',
      content: map['content'] as String? ?? '',
      category: map['category'] as String? ?? 'Observation',
      sessionDate: parseTimestamp(map['sessionDate']),
      createdAt: parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  TrainerClientNoteModel copyWith({
    String? id,
    String? trainerId,
    String? clientId,
    String? title,
    String? content,
    String? category,
    DateTime? sessionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainerClientNoteModel(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      sessionDate: sessionDate ?? this.sessionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A legitimate training progress observation recorded by the Trainer.
/// Strictly non-medical fitness progress milestones.
class TrainerClientProgressModel {
  final String id;
  final String trainerId;
  final String clientId;
  final String title;
  final String category; // 'Milestone', 'Workout / Exercise', 'Goal Progress', 'Consistency'
  final String notes;
  final DateTime achievedDate;
  final DateTime? createdAt;

  const TrainerClientProgressModel({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.title,
    this.category = 'Milestone',
    required this.notes,
    required this.achievedDate,
    this.createdAt,
  });

  String get formattedAchievedDate {
    final d = achievedDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainerId': trainerId,
      'clientId': clientId,
      'title': title,
      'category': category,
      'notes': notes,
      'achievedDate': Timestamp.fromDate(achievedDate),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory TrainerClientProgressModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TrainerClientProgressModel(
      id: id,
      trainerId: map['trainerId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      title: map['title'] as String? ?? 'Milestone',
      category: map['category'] as String? ?? 'Milestone',
      notes: map['notes'] as String? ?? '',
      achievedDate: parseTimestamp(map['achievedDate']) ?? DateTime.now(),
      createdAt: parseTimestamp(map['createdAt']) ?? DateTime.now(),
    );
  }

  TrainerClientProgressModel copyWith({
    String? id,
    String? trainerId,
    String? clientId,
    String? title,
    String? category,
    String? notes,
    DateTime? achievedDate,
    DateTime? createdAt,
  }) {
    return TrainerClientProgressModel(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      achievedDate: achievedDate ?? this.achievedDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

