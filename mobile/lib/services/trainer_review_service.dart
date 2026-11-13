import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/review_model.dart';
import '../shared/models/review_report_model.dart';
import 'notification_service.dart';

enum ReviewStarFilter { all, fiveStars, fourStars, threeStars, twoStars, oneStar }
enum ReviewResponseFilter { all, responded, awaitingResponse }

/// Central service for Trainer Reviews, Ratings Aggregation, Public Responses, and Policy Reporting.
class TrainerReviewService extends ChangeNotifier {
  static final TrainerReviewService instance = TrainerReviewService._internal();
  factory TrainerReviewService() => instance;
  TrainerReviewService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  final List<ReviewModel> _reviews = [];
  final List<ReviewReportModel> _reports = [];

  final StreamController<List<ReviewModel>> _reviewsStreamController =
      StreamController<List<ReviewModel>>.broadcast();

  Stream<List<ReviewModel>> get reviewsStream => _reviewsStreamController.stream;
  List<ReviewModel> get allReviews => List.unmodifiable(_reviews);
  List<ReviewReportModel> get allReports => List.unmodifiable(_reports);

  void _broadcast() {
    _reviewsStreamController.add(List.unmodifiable(_reviews));
    notifyListeners();
  }

  /// Streams verified reviews for a trainer
  Stream<List<ReviewModel>> streamReviewsForTrainer(String trainerId) {
    if (trainerId.isEmpty) {
      return Stream.value([]);
    }

    if (_firestore == null) {
      return Stream.value(_reviews.where((r) => r.trainerId == trainerId).toList());
    }

    try {
      return _firestore!
          .collection(FirestoreCollections.reviews)
          .where('trainerId', isEqualTo: trainerId)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((doc) => ReviewModel.fromDocument(doc)).toList();
        // Update in-memory cache
        for (final item in list) {
          final idx = _reviews.indexWhere((r) => r.id == item.id);
          if (idx >= 0) {
            _reviews[idx] = item;
          } else {
            _reviews.add(item);
          }
        }
        return list;
      }).handleError((e) {
        debugPrint('Notice: Firestore reviews stream error (using in-memory): $e');
        return _reviews.where((r) => r.trainerId == trainerId).toList();
      });
    } catch (_) {
      return Stream.value(_reviews.where((r) => r.trainerId == trainerId).toList());
    }
  }

  /// Calculates authoritative ratings metrics from verified review records
  Future<TrainerReviewMetricsModel> getReviewMetrics(String trainerId) async {
    final list = _reviews.where((r) => r.trainerId == trainerId && r.isPublic).toList();

    if (list.isEmpty) {
      return const TrainerReviewMetricsModel(
        averageRating: 5.0,
        totalReviews: 0,
        ratingDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
        respondedCount: 0,
      );
    }

    double sum = 0.0;
    final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    int responded = 0;

    for (final r in list) {
      sum += r.rating;
      final star = r.stars;
      dist[star] = (dist[star] ?? 0) + 1;
      if (r.hasResponse) {
        responded++;
      }
    }

    final avg = (sum / list.length).clamp(1.0, 5.0);

    return TrainerReviewMetricsModel(
      averageRating: double.parse(avg.toStringAsFixed(1)),
      totalReviews: list.length,
      ratingDistribution: dist,
      respondedCount: responded,
    );
  }

  /// Filters reviews by star rating, response status, and search query
  List<ReviewModel> filterReviews({
    required String trainerId,
    ReviewStarFilter starFilter = ReviewStarFilter.all,
    ReviewResponseFilter responseFilter = ReviewResponseFilter.all,
    String? searchQuery,
  }) {
    var list = _reviews.where((r) => r.trainerId == trainerId && r.isPublic).toList();

    // 1. Star Rating Filter
    switch (starFilter) {
      case ReviewStarFilter.fiveStars:
        list = list.where((r) => r.stars == 5).toList();
        break;
      case ReviewStarFilter.fourStars:
        list = list.where((r) => r.stars == 4).toList();
        break;
      case ReviewStarFilter.threeStars:
        list = list.where((r) => r.stars == 3).toList();
        break;
      case ReviewStarFilter.twoStars:
        list = list.where((r) => r.stars == 2).toList();
        break;
      case ReviewStarFilter.oneStar:
        list = list.where((r) => r.stars == 1).toList();
        break;
      case ReviewStarFilter.all:
        break;
    }

    // 2. Response Status Filter
    switch (responseFilter) {
      case ReviewResponseFilter.responded:
        list = list.where((r) => r.hasResponse).toList();
        break;
      case ReviewResponseFilter.awaitingResponse:
        list = list.where((r) => !r.hasResponse).toList();
        break;
      case ReviewResponseFilter.all:
        break;
    }

    // 3. Search Query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((r) {
        return r.displayClientName.toLowerCase().contains(q) ||
            r.comment.toLowerCase().contains(q) ||
            (r.packageName ?? '').toLowerCase().contains(q) ||
            (r.trainerResponse ?? '').toLowerCase().contains(q);
      }).toList();
    }

    // Order recent first
    list.sort((a, b) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return list;
  }

  /// Submits a professional public response from the trainer to an eligible review.
  /// Enforces ownership checks and content validation.
  Future<void> submitTrainerResponse({
    required String reviewId,
    required String trainerId,
    required String responseText,
  }) async {
    final cleaned = responseText.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Response content cannot be empty.');
    }
    if (cleaned.length < 3) {
      throw ArgumentError('Response must be at least 3 characters.');
    }
    if (cleaned.length > 500) {
      throw ArgumentError('Response cannot exceed 500 characters.');
    }

    // Check for inappropriate terms
    final lower = cleaned.toLowerCase();
    const prohibitedWords = ['abuse', 'scam', 'fraud', 'hate', 'idiot', 'fake'];
    for (final word in prohibitedWords) {
      if (lower.contains(word)) {
        throw ArgumentError('Response contains terms that violate professional communication guidelines.');
      }
    }

    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index >= 0) {
      final current = _reviews[index];
      if (current.trainerId != trainerId) {
        throw StateError('You are not authorized to respond to a review belonging to another trainer.');
      }
      final now = DateTime.now();
      final updated = current.copyWith(
        trainerResponse: cleaned,
        trainerRespondedAt: now,
        updatedAt: now,
      );
      _reviews[index] = updated;
      _broadcast();

      // Notify the client
      try {
        await NotificationService.instance.sendNotification(
          userId: current.clientId,
          title: 'Trainer Responded to Your Review',
          body: 'Your coach has posted a public response to your workout review.',
          type: 'REVIEW_RESPONSE',
          relatedId: reviewId,
        );
      } catch (_) {}
    }

    if (_firestore != null) {
      try {
        await _firestore!.collection(FirestoreCollections.reviews).doc(reviewId).update({
          'trainerResponse': cleaned,
          'trainerRespondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Notice: Error persisting trainer review response: $e');
      }
    }
  }

  /// Deletes a trainer's response
  Future<void> deleteTrainerResponse({
    required String reviewId,
    required String trainerId,
  }) async {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index >= 0) {
      final current = _reviews[index];
      if (current.trainerId != trainerId) {
        throw StateError('You are not authorized to modify a review belonging to another trainer.');
      }
      final updated = current.copyWith(
        clearResponse: true,
        updatedAt: DateTime.now(),
      );
      _reviews[index] = updated;
      _broadcast();
    }

    if (_firestore != null) {
      try {
        await _firestore!.collection(FirestoreCollections.reviews).doc(reviewId).update({
          'trainerResponse': FieldValue.delete(),
          'trainerRespondedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Notice: Error deleting trainer review response: $e');
      }
    }
  }

  /// Reports a review to Platform Admins for policy violation.
  /// Prevents duplicate reports by the same trainer for the same review.
  Future<void> reportReview({
    required String reviewId,
    required String trainerId,
    required String reason,
    String? details,
  }) async {
    final reportDocId = '${trainerId}_$reviewId';

    // Duplicate check
    final duplicate = _reports.any((rp) => rp.id == reportDocId);
    if (duplicate) {
      throw StateError('You have already submitted a report for this review.');
    }

    final report = ReviewReportModel(
      id: reportDocId,
      reviewId: reviewId,
      trainerId: trainerId,
      reporterId: trainerId,
      reason: reason,
      details: details,
      status: 'PENDING',
      createdAt: DateTime.now(),
    );

    _reports.add(report);

    // Update in-memory review report flag
    final idx = _reviews.indexWhere((r) => r.id == reviewId);
    if (idx >= 0) {
      final current = _reviews[idx];
      _reviews[idx] = current.copyWith(
        isReported: true,
        reportReason: reason,
        reportedAt: DateTime.now(),
      );
      _broadcast();
    }

    if (_firestore != null) {
      try {
        await _firestore!.collection(FirestoreCollections.reviewReports).doc(reportDocId).set(
          report.toMap(),
          SetOptions(merge: true),
        );

        await _firestore!.collection(FirestoreCollections.reviews).doc(reviewId).update({
          'isReported': true,
          'reportReason': reason,
          'reportedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Notice: Error saving review report: $e');
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Testing & Mock Utilities
  // ───────────────────────────────────────────────────────────────────────────

  @visibleForTesting
  void resetForTest() {
    _reviews.clear();
    _reports.clear();
    _broadcast();
  }

  @visibleForTesting
  void setTestReviews(List<ReviewModel> reviews) {
    _reviews.clear();
    _reviews.addAll(reviews);
    _broadcast();
  }

  @visibleForTesting
  void addTestReview(ReviewModel review) {
    final idx = _reviews.indexWhere((r) => r.id == review.id);
    if (idx >= 0) {
      _reviews[idx] = review;
    } else {
      _reviews.add(review);
    }
    _broadcast();
  }

  @visibleForTesting
  void setTestReports(List<ReviewReportModel> reports) {
    _reports.clear();
    _reports.addAll(reports);
    notifyListeners();
  }
}
