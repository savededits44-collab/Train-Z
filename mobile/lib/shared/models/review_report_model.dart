import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a report filed by a trainer regarding a policy-violating review
class ReviewReportModel {
  final String id;
  final String reviewId;
  final String trainerId;
  final String reporterId;
  final String reason;
  final String? details;
  final String status; // 'PENDING', 'REVIEWED', 'DISMISSED', 'ACTION_TAKEN'
  final DateTime? createdAt;

  const ReviewReportModel({
    required this.id,
    required this.reviewId,
    required this.trainerId,
    required this.reporterId,
    required this.reason,
    this.details,
    this.status = 'PENDING',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reviewId': reviewId,
      'trainerId': trainerId,
      'reporterId': reporterId,
      'reason': reason,
      'details': details,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ReviewReportModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ReviewReportModel(
      id: id,
      reviewId: map['reviewId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      reporterId: map['reporterId'] as String? ?? '',
      reason: map['reason'] as String? ?? 'Inappropriate Content',
      details: map['details'] as String?,
      status: map['status'] as String? ?? 'PENDING',
      createdAt: parseDate(map['createdAt']),
    );
  }
}

/// Aggregated metrics for Trainer Reviews & Ratings
class TrainerReviewMetricsModel {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // 1 to 5 star counts
  final int respondedCount;

  const TrainerReviewMetricsModel({
    this.averageRating = 5.0,
    this.totalReviews = 0,
    this.ratingDistribution = const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    this.respondedCount = 0,
  });

  String get formattedAverage => averageRating.toStringAsFixed(1);

  double starPercentage(int star) {
    if (totalReviews <= 0) return 0.0;
    final count = ratingDistribution[star] ?? 0;
    return (count / totalReviews).clamp(0.0, 1.0);
  }

  double get positivePercentage {
    if (totalReviews <= 0) return 100.0;
    final pos = (ratingDistribution[5] ?? 0) + (ratingDistribution[4] ?? 0);
    return ((pos / totalReviews) * 100).clamp(0.0, 100.0);
  }

  double get responseRatePercent {
    if (totalReviews <= 0) return 0.0;
    return ((respondedCount / totalReviews) * 100).clamp(0.0, 100.0);
  }
}

