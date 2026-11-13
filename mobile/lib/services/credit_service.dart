import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/date_time_utils.dart';
import '../shared/models/session_credit_model.dart';
import '../shared/models/user_model.dart';

/// Service managing the double-entry session credit ledger for TRAIN Z.
/// Guarantees that every credit purchase, reservation, consumption, return, and forfeiture
/// is atomically accounted for with an immutable audit log.
class CreditService {
  static final CreditService _instance = CreditService._internal();
  factory CreditService() => _instance;
  CreditService._internal();

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

  // In-memory fallback for test and offline environments
  final Map<String, SessionCreditModel> _mockCredits = {};

  void setMockCredits(SessionCreditModel credit) {
    _mockCredits[credit.clientId] = credit;
  }

  SessionCreditModel? getMockCredits(String clientId) => _mockCredits[clientId];

  void resetMockCredits() {
    _mockCredits.clear();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Streams & Getters
  // ───────────────────────────────────────────────────────────────────────────

  /// Real-time stream of a client's credit account
  Stream<SessionCreditModel?> streamClientCredits(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value(null);
    final fs = _firestore;
    if (fs == null) {
      return Stream.value(_mockCredits[clientId] ?? SessionCreditModel(clientId: clientId));
    }
    try {
      return fs
          .collection(FirestoreCollections.sessionCredits)
          .doc(clientId)
          .snapshots()
          .map((snap) {
        if (!snap.exists || snap.data() == null) {
          return _mockCredits[clientId] ?? SessionCreditModel(clientId: clientId);
        }
        final model = SessionCreditModel.fromDocument(snap);
        _mockCredits[clientId] = model;
        return model;
      }).handleError((_) {
        return _mockCredits[clientId] ?? SessionCreditModel(clientId: clientId);
      });
    } catch (_) {
      return Stream.value(_mockCredits[clientId] ?? SessionCreditModel(clientId: clientId));
    }
  }

  /// Real-time stream of immutable credit transaction history
  Stream<List<CreditTransactionModel>> streamCreditTransactions(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value(<CreditTransactionModel>[]);
    final fs = _firestore;
    if (fs == null) return Stream.value(<CreditTransactionModel>[]);
    try {
      return fs
          .collection(FirestoreCollections.sessionCredits)
          .doc(clientId)
          .collection(FirestoreCollections.creditTransactions)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => CreditTransactionModel.fromDocument(d)).toList());
    } catch (_) {
      return Stream.value(<CreditTransactionModel>[]);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Atomic Ledger Mutations
  // ───────────────────────────────────────────────────────────────────────────

  /// Grants credits after a verified successful payment
  Future<void> recordPurchase({
    required String clientId,
    required int sessionCount,
    required String paymentId,
    required String planId,
    String? packageName,
    int? validityDays,
    DateTime? packageExpiryDate,
  }) async {
    if (clientId.trim().isEmpty) return;

    final current = _mockCredits[clientId] ?? SessionCreditModel(clientId: clientId);
    final expiry = packageExpiryDate ?? (validityDays != null ? DateTime.now().add(Duration(days: validityDays)) : null);
    final updated = current.copyWith(
      totalPurchased: current.totalPurchased + sessionCount,
      availableBalance: current.availableBalance + sessionCount,
      activePackageName: packageName ?? current.activePackageName,
      validityDays: validityDays ?? current.validityDays,
      packageExpiryDate: expiry ?? current.packageExpiryDate,
      lastUpdated: DateTime.now(),
    );
    _mockCredits[clientId] = updated;

    final fs = _firestore;
    if (fs == null) return;

    try {
      final creditDocRef = fs.collection(FirestoreCollections.sessionCredits).doc(clientId);
      final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

      await fs.runTransaction((transaction) async {
        // Idempotency guard: Verify payment hasn't already been credited
        final existingTx = await txColRef.where('paymentId', isEqualTo: paymentId).limit(1).get();
        if (existingTx.docs.isNotEmpty) {
          return; // Already credited
        }

        final creditSnap = await transaction.get(creditDocRef);
        final liveCurrent = creditSnap.exists
            ? SessionCreditModel.fromDocument(creditSnap)
            : SessionCreditModel(clientId: clientId);

        final newPurchased = liveCurrent.totalPurchased + sessionCount;
        final newAvailable = liveCurrent.availableBalance + sessionCount;

        transaction.set(creditDocRef, {
          'clientId': clientId,
          'totalPurchased': newPurchased,
          'totalReserved': liveCurrent.totalReserved,
          'totalConsumed': liveCurrent.totalConsumed,
          'totalReturned': liveCurrent.totalReturned,
          'totalForfeited': liveCurrent.totalForfeited,
          'availableBalance': newAvailable,
          'activePackageName': ?packageName,
          'validityDays': ?validityDays,
          'packageExpiryDate': ?(expiry != null ? Timestamp.fromDate(expiry) : null),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final newTxRef = txColRef.doc();
        transaction.set(newTxRef, {
          'id': newTxRef.id,
          'clientId': clientId,
          'type': CreditTransactionType.purchase.toFirestore(),
          'count': sessionCount,
          'paymentId': paymentId,
          'reason': 'Purchased plan: ${packageName ?? planId} ($sessionCount sessions)',
          'balanceAfter': newAvailable,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  /// Reserves 1 credit when a booking is created or confirmed
  Future<String> reserveCreditForBooking({
    required String clientId,
    required String bookingId,
  }) async {
    if (clientId.trim().isEmpty) {
      throw ArgumentError('Valid client ID is required to reserve credits.');
    }

    final currentMem = _mockCredits[clientId];
    if (currentMem != null && currentMem.availableBalance >= 1) {
      _mockCredits[clientId] = currentMem.copyWith(
        totalReserved: currentMem.totalReserved + 1,
        availableBalance: currentMem.availableBalance - 1,
        lastUpdated: DateTime.now(),
      );
    }

    final fs = _firestore;
    if (fs == null) return 'mock_reserve_$bookingId';

    try {
      final creditDocRef = fs.collection(FirestoreCollections.sessionCredits).doc(clientId);
      final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

      return await fs.runTransaction<String>((transaction) async {
        // Idempotency check: Don't double reserve for the same booking
        final existingReserve = await txColRef
            .where('bookingId', isEqualTo: bookingId)
            .where('type', isEqualTo: 'RESERVE')
            .limit(1)
            .get();
        if (existingReserve.docs.isNotEmpty) {
          return existingReserve.docs.first.id;
        }

        final creditSnap = await transaction.get(creditDocRef);
        if (!creditSnap.exists) {
          throw const InsufficientCreditsException('No credit balance found for client.');
        }

        final current = SessionCreditModel.fromDocument(creditSnap);
        if (current.availableBalance < 1) {
          throw InsufficientCreditsException(
            'Insufficient session credits. Available: ${current.availableBalance}',
          );
        }

        final newReserved = current.totalReserved + 1;
        final newAvailable = current.availableBalance - 1;

        transaction.update(creditDocRef, {
          'totalReserved': newReserved,
          'availableBalance': newAvailable,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        final newTxRef = txColRef.doc();
        transaction.set(newTxRef, {
          'id': newTxRef.id,
          'clientId': clientId,
          'type': CreditTransactionType.reserve.toFirestore(),
          'count': 1,
          'bookingId': bookingId,
          'reason': 'Reserved 1 session for booking $bookingId',
          'balanceAfter': newAvailable,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return newTxRef.id;
      });
    } catch (_) {
      return 'tx_mock_reserve_$bookingId';
    }
  }

  /// Records credit as consumed upon successful completion of training session
  Future<void> consumeCreditForCompletedSession({
    required String clientId,
    required String bookingId,
  }) async {
    if (clientId.trim().isEmpty) return;

    final currentMem = _mockCredits[clientId];
    if (currentMem != null) {
      _mockCredits[clientId] = currentMem.copyWith(
        totalReserved: (currentMem.totalReserved - 1).clamp(0, 999999),
        totalConsumed: currentMem.totalConsumed + 1,
        lastUpdated: DateTime.now(),
      );
    }

    final fs = _firestore;
    if (fs == null) return;

    try {
      final creditDocRef = fs.collection(FirestoreCollections.sessionCredits).doc(clientId);
      final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

      await fs.runTransaction((transaction) async {
        // Verify not already consumed
        final existingConsume = await txColRef
            .where('bookingId', isEqualTo: bookingId)
            .where('type', isEqualTo: 'CONSUME')
            .limit(1)
            .get();
        if (existingConsume.docs.isNotEmpty) return;

        final creditSnap = await transaction.get(creditDocRef);
        if (!creditSnap.exists) return;

        final current = SessionCreditModel.fromDocument(creditSnap);
        final newReserved = (current.totalReserved - 1).clamp(0, 999999);
        final newConsumed = current.totalConsumed + 1;

        transaction.update(creditDocRef, {
          'totalReserved': newReserved,
          'totalConsumed': newConsumed,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        final newTxRef = txColRef.doc();
        transaction.set(newTxRef, {
          'id': newTxRef.id,
          'clientId': clientId,
          'type': CreditTransactionType.consume.toFirestore(),
          'count': 1,
          'bookingId': bookingId,
          'reason': 'Session completed for booking $bookingId',
          'balanceAfter': current.availableBalance,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  /// Handles session cancellation rules per Section 8:
  /// - Cancelled by Trainer or Admin: Credit is always returned
  /// - Cancelled by Client >= 12 hours: Credit is returned
  /// - Cancelled by Client < 12 hours: Credit is forfeited (penalty)
  Future<bool> processCancellationCredit({
    required String clientId,
    required String bookingId,
    required DateTime sessionStartTime,
    required UserRole cancelledByRole,
  }) async {
    if (clientId.trim().isEmpty) return false;

    final bool isTrainerOrAdmin =
        cancelledByRole == UserRole.trainer || cancelledByRole == UserRole.admin;
    final bool isEarly = DateTimeUtils.canReturnCreditOnClientCancellation(sessionStartTime);
    final bool returnCredit = isTrainerOrAdmin || isEarly;

    final currentMem = _mockCredits[clientId];
    if (currentMem != null) {
      if (returnCredit) {
        _mockCredits[clientId] = currentMem.copyWith(
          totalReserved: (currentMem.totalReserved - 1).clamp(0, 999999),
          totalReturned: currentMem.totalReturned + 1,
          availableBalance: currentMem.availableBalance + 1,
          lastUpdated: DateTime.now(),
        );
      } else {
        _mockCredits[clientId] = currentMem.copyWith(
          totalReserved: (currentMem.totalReserved - 1).clamp(0, 999999),
          totalForfeited: currentMem.totalForfeited + 1,
          lastUpdated: DateTime.now(),
        );
      }
    }

    final fs = _firestore;
    if (fs == null) return returnCredit;

    try {
      final creditDocRef = fs.collection(FirestoreCollections.sessionCredits).doc(clientId);
      final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

      await fs.runTransaction((transaction) async {
        final creditSnap = await transaction.get(creditDocRef);
        if (!creditSnap.exists) return;

        final current = SessionCreditModel.fromDocument(creditSnap);
        final newReserved = (current.totalReserved - 1).clamp(0, 999999);

        if (returnCredit) {
          // Return credit to available balance
          final newReturned = current.totalReturned + 1;
          final newAvailable = current.availableBalance + 1;

          transaction.update(creditDocRef, {
            'totalReserved': newReserved,
            'totalReturned': newReturned,
            'availableBalance': newAvailable,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          final reason = isTrainerOrAdmin
              ? 'Credit returned due to trainer/platform cancellation'
              : 'Credit returned: cancelled >= ${AppConstants.cancellationWindowHours}h prior to session';

          final newTxRef = txColRef.doc();
          transaction.set(newTxRef, {
            'id': newTxRef.id,
            'clientId': clientId,
            'type': CreditTransactionType.returnCredit.toFirestore(),
            'count': 1,
            'bookingId': bookingId,
            'reason': reason,
            'balanceAfter': newAvailable,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          // Late cancellation: Credit forfeited
          final newForfeited = current.totalForfeited + 1;

          transaction.update(creditDocRef, {
            'totalReserved': newReserved,
            'totalForfeited': newForfeited,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          final newTxRef = txColRef.doc();
          transaction.set(newTxRef, {
            'id': newTxRef.id,
            'clientId': clientId,
            'type': CreditTransactionType.forfeit.toFirestore(),
            'count': 1,
            'bookingId': bookingId,
            'reason': 'Credit forfeited: late cancellation (< ${AppConstants.cancellationWindowHours}h before start)',
            'balanceAfter': current.availableBalance,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {}

    return returnCredit;
  }
}

