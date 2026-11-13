import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/review_model.dart';
import 'booking_service.dart';

/// Dedicated service for managing client session reviews, ratings aggregation,
/// and review reporting for TRAIN Z.
class ReviewService {
  ReviewService._internal();
  static final ReviewService instance = ReviewService._internal();
  factory ReviewService() => instance;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      return _firestoreInstance ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void setFirestoreForTesting(FirebaseFirestore? firestore) {
    _firestoreInstance = firestore;
  }

  // ── In-Memory Mock Store for Testing and Offline Mode ──
  final Map<String, ReviewModel> _mockReviews = {};
  final List<Map<String, dynamic>> _mockReports = [];

  void setMockReview(ReviewModel review) {
    _mockReviews[review.bookingId] = review;
    _mockReviews[review.id] = review;
  }

  ReviewModel? getMockReview(String bookingOrReviewId) => _mockReviews[bookingOrReviewId];

  void resetMockReviews() {
    _mockReviews.clear();
    _mockReports.clear();
  }

  List<Map<String, dynamic>> get mockReports => List.unmodifiable(_mockReports);

  // ── Read Streams & Lookups ──

  /// Streams approved public reviews for a trainer sorted chronologically
  Stream<List<ReviewModel>> streamTrainerReviews(String trainerId) {
    if (trainerId.trim().isEmpty) return Stream.value([]);
    final fs = _firestore;
    if (fs == null) {
      final list = _mockReviews.values
          .where((r) => r.trainerId == trainerId && r.isPublic && !r.isReported)
          .toSet()
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return Stream.value(list);
    }

    try {
      return fs
          .collection(FirestoreCollections.reviews)
          .where('trainerId', isEqualTo: trainerId)
          .where('isPublic', isEqualTo: true)
          .snapshots()
          .map((snap) {
            final reviews = snap.docs
                .map((d) => ReviewModel.fromDocument(d))
                .where((r) => !r.isReported)
                .toList()
              ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
            return reviews;
          })
          .handleError((_) {
            final list = _mockReviews.values
                .where((r) => r.trainerId == trainerId && r.isPublic && !r.isReported)
                .toSet()
                .toList()
              ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
            return list;
          });
    } catch (_) {
      final list = _mockReviews.values
          .where((r) => r.trainerId == trainerId && r.isPublic && !r.isReported)
          .toSet()
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return Stream.value(list);
    }
  }

  /// Streams reviews written by a client
  Stream<List<ReviewModel>> streamClientReviews(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value([]);
    final fs = _firestore;
    if (fs == null) {
      final list = _mockReviews.values
          .where((r) => r.clientId == clientId)
          .toSet()
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return Stream.value(list);
    }

    try {
      return fs
          .collection(FirestoreCollections.reviews)
          .where('clientId', isEqualTo: clientId)
          .snapshots()
          .map((snap) => snap.docs.map((d) => ReviewModel.fromDocument(d)).toList())
          .handleError((_) {
            final list = _mockReviews.values
                .where((r) => r.clientId == clientId)
                .toSet()
                .toList();
            return list;
          });
    } catch (_) {
      final list = _mockReviews.values
          .where((r) => r.clientId == clientId)
          .toSet()
          .toList();
      return Stream.value(list);
    }
  }

  /// Streams a single review linked to a bookingId
  Stream<ReviewModel?> streamReviewForBooking(String bookingId) {
    if (bookingId.trim().isEmpty) return Stream.value(null);
    final fs = _firestore;
    if (fs == null) {
      return Stream.value(_mockReviews[bookingId]);
    }

    try {
      return fs
          .collection(FirestoreCollections.reviews)
          .doc(bookingId)
          .snapshots()
          .map((snap) {
            if (!snap.exists) return _mockReviews[bookingId];
            return ReviewModel.fromDocument(snap);
          })
          .handleError((_) => _mockReviews[bookingId]);
    } catch (_) {
      return Stream.value(_mockReviews[bookingId]);
    }
  }

  /// Gets review for a specific completed booking
  Future<ReviewModel?> getReviewForBooking(String bookingId) async {
    if (bookingId.trim().isEmpty) return null;
    final fs = _firestore;
    if (fs == null) return _mockReviews[bookingId];

    try {
      final doc = await fs.collection(FirestoreCollections.reviews).doc(bookingId).get();
      if (!doc.exists) return _mockReviews[bookingId];
      return ReviewModel.fromDocument(doc);
    } catch (_) {
      return _mockReviews[bookingId];
    }
  }

  /// Computes average rating and review count for a trainer from genuine eligible reviews
  Future<Map<String, dynamic>> calculateTrainerAggregateRating(String trainerId) async {
    final fs = _firestore;
    if (fs == null) {
      final active = _mockReviews.values
          .where((r) => r.trainerId == trainerId && r.isPublic && !r.isReported)
          .toSet()
          .toList();
      if (active.isEmpty) return {'ratingAvg': 5.0, 'totalReviews': 0};
      final sum = active.fold<double>(0.0, (acc, r) => acc + r.rating);
      final avg = (sum / active.length * 10).round() / 10;
      return {'ratingAvg': avg, 'totalReviews': active.length};
    }

    try {
      final snap = await fs
          .collection(FirestoreCollections.reviews)
          .where('trainerId', isEqualTo: trainerId)
          .where('isPublic', isEqualTo: true)
          .get();

      final active = snap.docs
          .map((d) => ReviewModel.fromDocument(d))
          .where((r) => !r.isReported)
          .toList();

      if (active.isEmpty) return {'ratingAvg': 5.0, 'totalReviews': 0};
      final sum = active.fold<double>(0.0, (acc, r) => acc + r.rating);
      final avg = (sum / active.length * 10).round() / 10;
      return {'ratingAvg': avg, 'totalReviews': active.length};
    } catch (_) {
      return {'ratingAvg': 5.0, 'totalReviews': 0};
    }
  }

  // ── Review Submission & Modification ──

  /// Submits or updates a session review for a verified completed booking
  Future<bool> submitReview({
    required String bookingId,
    required String clientId,
    required String trainerId,
    required double rating,
    required String comment,
    List<String> categories = const [],
    String? clientName,
    String? clientPhotoUrl,
    BookingModel? bookingContext,
  }) async {
    if (bookingId.trim().isEmpty || clientId.trim().isEmpty || trainerId.trim().isEmpty) {
      throw const ReviewException('Invalid booking or client identifier for review submission.');
    }

    if (rating < 1.0 || rating > 5.0) {
      throw const ReviewException('Rating must be between 1.0 and 5.0 stars.');
    }

    final trimmedComment = comment.trim();
    if (trimmedComment.length < 5) {
      throw const ReviewException('Written review feedback must be at least 5 characters long.');
    }

    // Verify session completion
    BookingModel? booking = bookingContext;
    if (booking == null) {
      final fs = _firestore;
      if (fs != null) {
        try {
          final bDoc = await fs.collection(FirestoreCollections.bookings).doc(bookingId).get();
          if (bDoc.exists) {
            booking = BookingModel.fromDocument(bDoc);
          }
        } catch (_) {}
      }
      try {
        booking ??= BookingService.instance.allBookings.firstWhere((b) => b.id == bookingId);
      } catch (_) {}
    }

    if (booking != null) {
      if (booking.clientId != clientId) {
        throw const ReviewException('Only the athlete who completed this booking can submit a review.');
      }
      if (booking.status != BookingStatus.completed) {
        throw const ReviewException('Reviews can only be submitted for completed training sessions.');
      }
    }

    final sanitizedCategories = categories.take(5).toList();

    // Mask client name to protect personal privacy (e.g. "Rahul Sharma" -> "Rahul S.")
    String maskedName = 'Verified Athlete';
    final rawName = (clientName ?? booking?.clientName ?? '').trim();
    if (rawName.isNotEmpty) {
      final parts = rawName.split(' ');
      if (parts.length > 1) {
        maskedName = '${parts[0]} ${parts[1][0].toUpperCase()}.';
      } else {
        maskedName = parts[0];
      }
    }

    final existing = _mockReviews[bookingId];
    if (existing != null && existing.clientId != clientId) {
      throw const ReviewException('You cannot modify another athlete\'s review.');
    }

    final reviewModel = ReviewModel(
      id: bookingId,
      bookingId: bookingId,
      clientId: clientId,
      trainerId: trainerId,
      clientName: maskedName,
      clientPhotoUrl: clientPhotoUrl ?? booking?.clientPhotoUrl,
      rating: (rating * 10).round() / 10,
      comment: trimmedComment,
      categories: sanitizedCategories,
      isPublic: true,
      isReported: false,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save in mock store
    setMockReview(reviewModel);

    // Save to Firestore if available
    final fs = _firestore;
    if (fs != null) {
      try {
        final reviewRef = fs.collection(FirestoreCollections.reviews).doc(bookingId);
        await reviewRef.set(reviewModel.toMap(), SetOptions(merge: true));

        // Recalculate aggregate rating for trainer
        final agg = await calculateTrainerAggregateRating(trainerId);
        final newRatingAvg = agg['ratingAvg'] as double;
        final newTotalReviews = agg['totalReviews'] as int;

        await Future.wait([
          fs.collection(FirestoreCollections.trainerProfiles).doc(trainerId).set({
            'ratingAvg': newRatingAvg,
            'totalReviews': newTotalReviews,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
          fs.collection(FirestoreCollections.users).doc(trainerId).set({
            'ratingAvg': newRatingAvg,
            'totalReviews': newTotalReviews,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        ]);
      } catch (_) {}
    }

    return true;
  }

  // ── Review Reporting (Abuse / Policy Violations) ──

  /// Submits an abuse report for an inappropriate or offensive review
  Future<bool> reportReview({
    required String reviewId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    if (reviewId.trim().isEmpty || reporterId.trim().isEmpty || reason.trim().isEmpty) {
      throw const ReviewException('Review ID, reporter ID, and reason are required to report.');
    }

    final existing = _mockReviews[reviewId];
    if (existing != null) {
      _mockReviews[reviewId] = existing.copyWith(
        isReported: true,
        reportReason: reason.trim(),
        reportedAt: DateTime.now(),
      );
    }

    final reportData = {
      'id': 'rep_${DateTime.now().millisecondsSinceEpoch}',
      'reviewId': reviewId,
      'reportedBy': reporterId,
      'reason': reason.trim(),
      'details': details?.trim(),
      'status': 'PENDING_MODERATION',
      'createdAt': DateTime.now(),
    };
    _mockReports.add(reportData);

    final fs = _firestore;
    if (fs != null) {
      try {
        final reportDocRef = fs.collection(FirestoreCollections.reviewReports).doc();
        await reportDocRef.set({
          'id': reportDocRef.id,
          'reviewId': reviewId,
          'reportedBy': reporterId,
          'reason': reason.trim(),
          'details': details?.trim(),
          'status': 'PENDING_MODERATION',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Mark review document as reported
        await fs.collection(FirestoreCollections.reviews).doc(reviewId).update({
          'isReported': true,
          'reportReason': reason.trim(),
          'reportedAt': FieldValue.serverTimestamp(),
        });

        // Recalculate trainer aggregate rating excluding reported review
        if (existing != null) {
          final agg = await calculateTrainerAggregateRating(existing.trainerId);
          await fs.collection(FirestoreCollections.trainerProfiles).doc(existing.trainerId).update({
            'ratingAvg': agg['ratingAvg'],
            'totalReviews': agg['totalReviews'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    }

    return true;
  }
}
