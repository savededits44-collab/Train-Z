import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/platform_settings_model.dart';
import '../shared/models/trainer_earnings_model.dart';
import 'booking_service.dart';
import 'firestore_service.dart';

enum DateRangeFilter { allTime, thisMonth, last30Days, last90Days }

/// Central service for Trainer Earnings, Commission tracking, and Payout Management.
class TrainerEarningsService extends ChangeNotifier {
  static final TrainerEarningsService instance = TrainerEarningsService._internal();
  factory TrainerEarningsService() => instance;
  TrainerEarningsService._internal() {
    _initLiveSync();
  }

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }
  final FirestoreService _firestoreService = FirestoreService();

  final List<TrainerEarningsTransactionModel> _transactions = [];
  final List<TrainerPayoutModel> _payouts = [];
  PlatformSettingsModel? _cachedSettings;

  int? _testCommissionRate = 15;
  bool _isTestOverride = false;

  final StreamController<List<TrainerEarningsTransactionModel>> _txStreamController =
      StreamController<List<TrainerEarningsTransactionModel>>.broadcast();
  final StreamController<List<TrainerPayoutModel>> _payoutStreamController =
      StreamController<List<TrainerPayoutModel>>.broadcast();

  Stream<List<TrainerEarningsTransactionModel>> get transactionStream => _txStreamController.stream;
  Stream<List<TrainerPayoutModel>> get payoutStream => _payoutStreamController.stream;

  List<TrainerEarningsTransactionModel> get allTransactions => List.unmodifiable(_transactions);
  List<TrainerPayoutModel> get allPayouts => List.unmodifiable(_payouts);

  void _initLiveSync() {
    try {
      BookingService.instance.addListener(_syncFromBookings);
    } catch (_) {}
  }

  /// Synchronize earnings in real-time from completed bookings when running
  void _syncFromBookings() {
    final bookings = BookingService.instance.allBookings;
    for (final b in bookings) {
      if (b.status == BookingStatus.completed) {
        final existingIndex = _transactions.indexWhere((t) => t.bookingId == b.id);
        final rate = _testCommissionRate ?? _cachedSettings?.platformFeePercent ?? 15;

        int gross = 500;
        if (b.packagePrice != null && b.totalSessions != null && b.totalSessions! > 0) {
          gross = (b.packagePrice! / b.totalSessions!).round();
        } else if (b.packagePrice != null && b.packagePrice! > 0) {
          gross = b.packagePrice!;
        }

        final comm = (gross * (rate / 100)).round();
        final net = gross - comm;

        if (existingIndex < 0) {
          final tx = TrainerEarningsTransactionModel(
            id: 'earn_${b.id}',
            bookingId: b.id,
            bookingRef: '#${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id}',
            trainerId: b.trainerId,
            clientId: b.clientId,
            clientName: b.displayClientName,
            packageName: b.resolvedPackageName,
            sessionDate: b.sessionDate,
            startTime: b.startTime,
            endTime: b.endTime,
            grossAmount: gross,
            commissionRatePercent: rate,
            commissionAmount: comm,
            netAmount: net,
            payoutStatus: TrainerPayoutStatus.eligibleForPayout,
            status: 'COMPLETED',
            createdAt: b.completedAt ?? DateTime.now(),
          );
          _transactions.add(tx);
        }
      } else if (b.isCancelled) {
        final existingIndex = _transactions.indexWhere((t) => t.bookingId == b.id);
        if (existingIndex >= 0) {
          final existing = _transactions[existingIndex];
          _transactions[existingIndex] = existing.copyWith(
            payoutStatus: TrainerPayoutStatus.refunded,
            status: 'REFUNDED',
            refundReason: b.cancellationReason ?? 'Cancelled session',
          );
        }
      }
    }
    _broadcast();
  }

  void _broadcast() {
    _txStreamController.add(List.unmodifiable(_transactions));
    _payoutStreamController.add(List.unmodifiable(_payouts));
    notifyListeners();
  }

  /// Fetches platform settings to obtain commission percentage
  Future<PlatformSettingsModel?> getPlatformSettings() async {
    if (_cachedSettings != null) return _cachedSettings;
    try {
      _cachedSettings = await _firestoreService.getPlatformSettings();
      return _cachedSettings;
    } catch (e) {
      debugPrint('Notice: Error loading platform settings: $e');
      return null;
    }
  }

  /// Streams earnings transactions for a trainer
  Stream<List<TrainerEarningsTransactionModel>> streamTransactionsForTrainer(String trainerId) {
    if (trainerId.isEmpty) {
      return Stream.value([]);
    }

    if (_firestore == null) {
      return Stream.value(_transactions.where((t) => t.trainerId == trainerId).toList());
    }

    // Try listening to Firestore
    try {
      return _firestore!
          .collection(FirestoreCollections.trainerEarnings)
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('sessionDate', descending: true)
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((doc) => TrainerEarningsTransactionModel.fromMap(doc.data(), id: doc.id))
            .toList();
      }).handleError((e) {
        debugPrint('Notice: Firestore trainer_earnings stream error (using in-memory): $e');
        return _transactions.where((t) => t.trainerId == trainerId).toList();
      });
    } catch (_) {
      return Stream.value(_transactions.where((t) => t.trainerId == trainerId).toList());
    }
  }

  /// Streams payouts for a trainer
  Stream<List<TrainerPayoutModel>> streamPayoutsForTrainer(String trainerId) {
    if (trainerId.isEmpty) {
      return Stream.value([]);
    }

    if (_firestore == null) {
      return Stream.value(_payouts.where((p) => p.trainerId == trainerId).toList());
    }

    try {
      return _firestore!
          .collection(FirestoreCollections.trainerPayouts)
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('payoutDate', descending: true)
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((doc) => TrainerPayoutModel.fromMap(doc.data(), id: doc.id))
            .toList();
      }).handleError((e) {
        debugPrint('Notice: Firestore trainer_payouts stream error: $e');
        return _payouts.where((p) => p.trainerId == trainerId).toList();
      });
    } catch (_) {
      return Stream.value(_payouts.where((p) => p.trainerId == trainerId).toList());
    }
  }

  /// Calculates authoritative financial overview metrics
  Future<TrainerEarningsSummaryModel> getEarningsSummary(String trainerId) async {
    int? commissionRate = _isTestOverride ? _testCommissionRate : null;
    if (commissionRate == null) {
      final settings = await getPlatformSettings();
      commissionRate = settings?.platformFeePercent;
    }

    final txs = _transactions.where((t) => t.trainerId == trainerId).toList();
    final pos = _payouts.where((p) => p.trainerId == trainerId).toList();

    int totalGross = 0;
    int totalCommission = 0;
    int netEarnings = 0;
    int pendingPayout = 0;
    int totalPaidOut = 0;
    int completedCount = 0;

    for (final tx in txs) {
      if (tx.status == 'COMPLETED') {
        completedCount++;
        totalGross += tx.grossAmount;
        totalCommission += tx.commissionAmount;
        netEarnings += tx.netAmount;

        if (tx.payoutStatus == TrainerPayoutStatus.eligibleForPayout ||
            tx.payoutStatus == TrainerPayoutStatus.payoutPending) {
          pendingPayout += tx.netAmount;
        }
      }
    }

    for (final po in pos) {
      if (po.status == PayoutBatchStatus.paid) {
        totalPaidOut += po.amount;
      }
    }

    return TrainerEarningsSummaryModel(
      totalGrossRevenue: totalGross,
      totalCommission: totalCommission,
      netEarnings: netEarnings,
      pendingPayout: pendingPayout,
      totalPaidOut: totalPaidOut,
      completedSessionsCount: completedCount,
      commissionRatePercent: commissionRate,
      isCommissionConfigured: commissionRate != null,
    );
  }

  /// Filters transactions by date range and payout status
  List<TrainerEarningsTransactionModel> filterTransactions({
    required String trainerId,
    DateRangeFilter dateRange = DateRangeFilter.allTime,
    TrainerPayoutStatus? statusFilter,
    String? searchQuery,
  }) {
    final now = DateTime.now();
    var list = _transactions.where((t) => t.trainerId == trainerId).toList();

    // 1. Date Range
    switch (dateRange) {
      case DateRangeFilter.thisMonth:
        list = list.where((t) => t.sessionDate.year == now.year && t.sessionDate.month == now.month).toList();
        break;
      case DateRangeFilter.last30Days:
        final limit = now.subtract(const Duration(days: 30));
        list = list.where((t) => t.sessionDate.isAfter(limit)).toList();
        break;
      case DateRangeFilter.last90Days:
        final limit = now.subtract(const Duration(days: 90));
        list = list.where((t) => t.sessionDate.isAfter(limit)).toList();
        break;
      case DateRangeFilter.allTime:
        break;
    }

    // 2. Status Filter
    if (statusFilter != null) {
      list = list.where((t) => t.payoutStatus == statusFilter).toList();
    }

    // 3. Search Query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((t) {
        return t.clientName.toLowerCase().contains(q) ||
            t.packageName.toLowerCase().contains(q) ||
            t.bookingRef.toLowerCase().contains(q) ||
            t.id.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Test & Mock Utilities
  // ───────────────────────────────────────────────────────────────────────────

  @visibleForTesting
  void resetForTest() {
    _transactions.clear();
    _payouts.clear();
    _cachedSettings = null;
    _testCommissionRate = 15;
    _isTestOverride = false;
    _broadcast();
  }

  @visibleForTesting
  void setTestTransactions(List<TrainerEarningsTransactionModel> txs) {
    _transactions.clear();
    _transactions.addAll(txs);
    _broadcast();
  }

  @visibleForTesting
  void addTestTransaction(TrainerEarningsTransactionModel tx) {
    final index = _transactions.indexWhere((t) => t.id == tx.id);
    if (index >= 0) {
      _transactions[index] = tx;
    } else {
      _transactions.add(tx);
    }
    _broadcast();
  }

  @visibleForTesting
  void setTestPayouts(List<TrainerPayoutModel> pos) {
    _payouts.clear();
    _payouts.addAll(pos);
    _broadcast();
  }

  @visibleForTesting
  void setTestCommissionRate(int? rate) {
    _testCommissionRate = rate;
    _isTestOverride = true;
    notifyListeners();
  }
}
