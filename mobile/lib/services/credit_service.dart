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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ───────────────────────────────────────────────────────────────────────────
  // Streams & Getters
  // ───────────────────────────────────────────────────────────────────────────

  /// Real-time stream of a client's credit account
  Stream<SessionCreditModel?> streamClientCredits(String clientId) {
    return _firestore
        .collection(FirestoreCollections.sessionCredits)
        .doc(clientId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SessionCreditModel.fromDocument(snap);
    });
  }

  /// Real-time stream of immutable credit transaction history
  Stream<List<CreditTransactionModel>> streamCreditTransactions(String clientId) {
    return _firestore
        .collection(FirestoreCollections.sessionCredits)
        .doc(clientId)
        .collection(FirestoreCollections.creditTransactions)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CreditTransactionModel.fromDocument(d)).toList());
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
  }) async {
    final creditDocRef = _firestore.collection(FirestoreCollections.sessionCredits).doc(clientId);
    final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

    await _firestore.runTransaction((transaction) async {
      // Idempotency guard: Verify payment hasn't already been credited
      final existingTx = await txColRef.where('paymentId', isEqualTo: paymentId).limit(1).get();
      if (existingTx.docs.isNotEmpty) {
        return; // Already credited
      }

      final creditSnap = await transaction.get(creditDocRef);
      final current = creditSnap.exists
          ? SessionCreditModel.fromDocument(creditSnap)
          : SessionCreditModel(clientId: clientId);

      final newPurchased = current.totalPurchased + sessionCount;
      final newAvailable = current.availableBalance + sessionCount;

      transaction.set(creditDocRef, {
        'clientId': clientId,
        'totalPurchased': newPurchased,
        'totalReserved': current.totalReserved,
        'totalConsumed': current.totalConsumed,
        'totalReturned': current.totalReturned,
        'totalForfeited': current.totalForfeited,
        'availableBalance': newAvailable,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final newTxRef = txColRef.doc();
      transaction.set(newTxRef, {
        'id': newTxRef.id,
        'clientId': clientId,
        'type': CreditTransactionType.purchase.toFirestore(),
        'count': sessionCount,
        'paymentId': paymentId,
        'reason': 'Purchased plan: $planId ($sessionCount sessions)',
        'balanceAfter': newAvailable,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Reserves 1 credit when a booking is created or confirmed
  Future<String> reserveCreditForBooking({
    required String clientId,
    required String bookingId,
  }) async {
    final creditDocRef = _firestore.collection(FirestoreCollections.sessionCredits).doc(clientId);
    final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

    return await _firestore.runTransaction<String>((transaction) async {
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
  }

  /// Records credit as consumed upon successful completion of training session
  Future<void> consumeCreditForCompletedSession({
    required String clientId,
    required String bookingId,
  }) async {
    final creditDocRef = _firestore.collection(FirestoreCollections.sessionCredits).doc(clientId);
    final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

    await _firestore.runTransaction((transaction) async {
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
    final creditDocRef = _firestore.collection(FirestoreCollections.sessionCredits).doc(clientId);
    final txColRef = creditDocRef.collection(FirestoreCollections.creditTransactions);

    final bool isTrainerOrAdmin =
        cancelledByRole == UserRole.trainer || cancelledByRole == UserRole.admin;
    final bool isEarly = DateTimeUtils.canReturnCreditOnClientCancellation(sessionStartTime);
    final bool returnCredit = isTrainerOrAdmin || isEarly;

    await _firestore.runTransaction((transaction) async {
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

    return returnCredit;
  }
}

