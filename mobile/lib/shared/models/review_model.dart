import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a verified personal training session review submitted by a client.
class ReviewModel {
  final String id;
  final String bookingId;
  final String clientId;
  final String trainerId;
  final String clientName;
  final String? clientPhotoUrl;
  final double rating; // 1.0 - 5.0
  final String comment;
  final List<String> categories; // e.g. ["Punctual & Prepared", "Technique & Form"]
  final String? packageName;
  final DateTime? sessionDate;
  final bool isPublic;
  final String? trainerResponse;
  final DateTime? trainerRespondedAt;
  final bool isReported;
  final String? reportReason;
  final DateTime? reportedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.trainerId,
    this.clientName = 'Verified Athlete',
    this.clientPhotoUrl,
    required this.rating,
    required this.comment,
    this.categories = const [],
    this.packageName,
    this.sessionDate,
    this.isPublic = true,
    this.trainerResponse,
    this.trainerRespondedAt,
    this.isReported = false,
    this.reportReason,
    this.reportedAt,
    this.createdAt,
    this.updatedAt,
  });

  String get ratingText => rating.toStringAsFixed(1);

  int get stars => rating.round().clamp(1, 5);

  String get displayClientName =>
      (clientName.trim().isNotEmpty) ? clientName : 'Verified Athlete';

  bool get hasResponse => trainerResponse != null && trainerResponse!.trim().isNotEmpty;

  String get formattedDate {
    if (createdAt == null) return 'Recent';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${createdAt!.day} ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }

  String get formattedResponseDate {
    if (trainerRespondedAt == null) return 'Recent';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${trainerRespondedAt!.day} ${months[trainerRespondedAt!.month - 1]} ${trainerRespondedAt!.year}';
  }

  ReviewModel copyWith({
    String? id,
    String? bookingId,
    String? clientId,
    String? trainerId,
    String? clientName,
    String? clientPhotoUrl,
    double? rating,
    String? comment,
    List<String>? categories,
    String? packageName,
    DateTime? sessionDate,
    bool? isPublic,
    String? trainerResponse,
    DateTime? trainerRespondedAt,
    bool clearResponse = false,
    bool? isReported,
    String? reportReason,
    DateTime? reportedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      clientName: clientName ?? this.clientName,
      clientPhotoUrl: clientPhotoUrl ?? this.clientPhotoUrl,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      categories: categories ?? this.categories,
      packageName: packageName ?? this.packageName,
      sessionDate: sessionDate ?? this.sessionDate,
      isPublic: isPublic ?? this.isPublic,
      trainerResponse: clearResponse ? null : (trainerResponse ?? this.trainerResponse),
      trainerRespondedAt: clearResponse ? null : (trainerRespondedAt ?? this.trainerRespondedAt),
      isReported: isReported ?? this.isReported,
      reportReason: reportReason ?? this.reportReason,
      reportedAt: reportedAt ?? this.reportedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'clientId': clientId,
      'trainerId': trainerId,
      'clientName': clientName,
      'clientPhotoUrl': clientPhotoUrl,
      'rating': rating,
      'comment': comment,
      'categories': categories,
      'packageName': packageName,
      'sessionDate': sessionDate != null ? Timestamp.fromDate(sessionDate!) : null,
      'isPublic': isPublic,
      'trainerResponse': trainerResponse,
      'trainerRespondedAt': trainerRespondedAt != null ? Timestamp.fromDate(trainerRespondedAt!) : null,
      'isReported': isReported,
      'reportReason': reportReason,
      'reportedAt': reportedAt != null ? Timestamp.fromDate(reportedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawCategories = map['categories'];
    final List<String> categoriesList = rawCategories is List
        ? rawCategories.map((e) => e.toString()).toList()
        : const [];

    return ReviewModel(
      id: id,
      bookingId: map['bookingId'] as String? ?? id,
      clientId: map['clientId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? 'Verified Athlete',
      clientPhotoUrl: map['clientPhotoUrl'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment'] as String? ?? '',
      categories: categoriesList,
      packageName: map['packageName'] as String?,
      sessionDate: parseTimestamp(map['sessionDate']),
      isPublic: map['isPublic'] as bool? ?? true,
      trainerResponse: map['trainerResponse'] as String?,
      trainerRespondedAt: parseTimestamp(map['trainerRespondedAt']),
      isReported: map['isReported'] as bool? ?? false,
      reportReason: map['reportReason'] as String?,
      reportedAt: parseTimestamp(map['reportedAt']),
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory ReviewModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReviewModel.fromMap(data, id: doc.id);
  }
}
