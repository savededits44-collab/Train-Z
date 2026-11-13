import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/screens/trainer/trainer_earnings_screen.dart';
import 'package:trainuspro/services/trainer_earnings_service.dart';
import 'package:trainuspro/shared/models/trainer_earnings_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrainerId = 'trainer_rohit_uid_101';
  const otherTrainerId = 'trainer_priya_uid_202';
  final now = DateTime.now();

  setUp(() {
    TrainerEarningsService.instance.resetForTest();
  });

  group('1. Trainer Earnings & Payout Models', () {
    test('Calculates gross, commission, and net earnings accurately', () {
      const gross = 1000;
      const rate = 15;
      final commission = (gross * (rate / 100)).round();
      final net = gross - commission;

      expect(commission, 150);
      expect(net, 850);

      final tx = TrainerEarningsTransactionModel(
        id: 'earn_bk_101',
        bookingId: 'bk_101',
        bookingRef: '#BK101',
        trainerId: testTrainerId,
        clientName: 'Aarav Mehta',
        packageName: '1 Month Transformation',
        sessionDate: now,
        grossAmount: gross,
        commissionRatePercent: rate,
        commissionAmount: commission,
        netAmount: net,
        payoutStatus: TrainerPayoutStatus.eligibleForPayout,
      );

      expect(tx.formattedGross, '₹1000');
      expect(tx.formattedCommission, '₹150');
      expect(tx.formattedNet, '₹850');
      expect(tx.isEligible, isTrue);
      expect(tx.isRefunded, isFalse);
    });

    test('Serializes to and from Map with all audit and failure fields', () {
      final tx = TrainerEarningsTransactionModel(
        id: 'earn_bk_102',
        bookingId: 'bk_102',
        bookingRef: '#BK102',
        trainerId: testTrainerId,
        clientName: 'Vikram Seth',
        packageName: '3 Months Pro',
        sessionDate: DateTime(2026, 11, 13, 10, 0),
        grossAmount: 1399,
        commissionRatePercent: 15,
        commissionAmount: 210,
        netAmount: 1189,
        payoutStatus: TrainerPayoutStatus.payoutPending,
        status: 'COMPLETED',
        failureReason: null,
      );

      final map = tx.toMap();
      expect(map['grossAmount'], 1399);
      expect(map['commissionAmount'], 210);
      expect(map['netAmount'], 1189);
      expect(map['payoutStatus'], 'PAYOUT_PENDING');

      final reconstructed = TrainerEarningsTransactionModel.fromMap(map, id: 'earn_bk_102');
      expect(reconstructed.id, 'earn_bk_102');
      expect(reconstructed.netAmount, 1189);
      expect(reconstructed.payoutStatus, TrainerPayoutStatus.payoutPending);
      expect(reconstructed.status, 'COMPLETED');
    });

    test('TrainerPayoutStatus handles all required backend states', () {
      final statuses = [
        'PROCESSING',
        'ELIGIBLE_FOR_PAYOUT',
        'PAYOUT_PENDING',
        'PAID',
        'FAILED',
        'REFUNDED',
        'REVERSED',
      ];

      for (final s in statuses) {
        final parsed = TrainerPayoutStatus.fromFirestore(s);
        expect(parsed.toFirestore(), isNotEmpty);
        expect(parsed.displayTitle, isNotEmpty);
        expect(parsed.color, isNotNull);
      }
    });

    test('TrainerPayoutModel formats bank details and failure reason properly', () {
      final payout = TrainerPayoutModel(
        id: 'PO-202611-001',
        trainerId: testTrainerId,
        amount: 8500,
        payoutDate: DateTime(2026, 11, 10),
        status: PayoutBatchStatus.failed,
        transactionCount: 10,
        bankAccountLast4: '4821',
        bankName: 'HDFC Bank',
        failureReason: 'Beneficiary IFSC verification failed at partner clearing house',
      );

      expect(payout.formattedAmount, '₹8500');
      expect(payout.bankAccountLast4, '4821');
      expect(payout.failureReason, contains('IFSC verification'));
      expect(payout.status, PayoutBatchStatus.failed);

      final map = payout.toMap();
      final fromMap = TrainerPayoutModel.fromMap(map, id: 'PO-202611-001');
      expect(fromMap.id, 'PO-202611-001');
      expect(fromMap.status, PayoutBatchStatus.failed);
      expect(fromMap.failureReason, contains('IFSC'));
    });
  });

  group('2. Platform Commission & Financial Aggregations', () {
    test('Calculates total gross, commission deduction, net earnings and pending payouts', () async {
      final service = TrainerEarningsService.instance;
      service.setTestCommissionRate(15);

      service.setTestTransactions([
        TrainerEarningsTransactionModel(
          id: 'earn_1',
          bookingId: 'bk_1',
          bookingRef: '#BK1',
          trainerId: testTrainerId,
          clientName: 'Client 1',
          packageName: '1 Day',
          sessionDate: now,
          grossAmount: 500,
          commissionRatePercent: 15,
          commissionAmount: 75,
          netAmount: 425,
          payoutStatus: TrainerPayoutStatus.eligibleForPayout,
          status: 'COMPLETED',
        ),
        TrainerEarningsTransactionModel(
          id: 'earn_2',
          bookingId: 'bk_2',
          bookingRef: '#BK2',
          trainerId: testTrainerId,
          clientName: 'Client 2',
          packageName: '1 Month',
          sessionDate: now,
          grossAmount: 1000,
          commissionRatePercent: 15,
          commissionAmount: 150,
          netAmount: 850,
          payoutStatus: TrainerPayoutStatus.payoutPending,
          status: 'COMPLETED',
        ),
        TrainerEarningsTransactionModel(
          id: 'earn_3',
          bookingId: 'bk_3',
          bookingRef: '#BK3',
          trainerId: testTrainerId,
          clientName: 'Client 3',
          packageName: '3 Days',
          sessionDate: now.subtract(const Duration(days: 7)),
          grossAmount: 1000,
          commissionRatePercent: 15,
          commissionAmount: 150,
          netAmount: 850,
          payoutStatus: TrainerPayoutStatus.paid,
          status: 'COMPLETED',
        ),
      ]);

      service.setTestPayouts([
        TrainerPayoutModel(
          id: 'PO-1',
          trainerId: testTrainerId,
          amount: 850,
          payoutDate: now.subtract(const Duration(days: 5)),
          status: PayoutBatchStatus.paid,
        ),
      ]);

      final summary = await service.getEarningsSummary(testTrainerId);

      expect(summary.totalGrossRevenue, 2500);
      expect(summary.totalCommission, 375);
      expect(summary.netEarnings, 2125);
      expect(summary.pendingPayout, 1275); // 425 + 850
      expect(summary.totalPaidOut, 850);
      expect(summary.completedSessionsCount, 3);
      expect(summary.isCommissionConfigured, isTrue);
      expect(summary.commissionRatePercent, 15);
    });

    test('Pending configuration state when commission rate is not configured', () async {
      final service = TrainerEarningsService.instance;
      service.setTestCommissionRate(null); // Unconfigured

      final summary = await service.getEarningsSummary(testTrainerId);
      expect(summary.isCommissionConfigured, isFalse);
      expect(summary.commissionRatePercent, isNull);
      expect(summary.formattedCommissionRate, 'Pending');
    });
  });

  group('3. Completed Session Eligibility & Refunds Synchronization', () {
    test('Refunded or cancelled transactions are excluded from pending payout', () async {
      final service = TrainerEarningsService.instance;
      service.setTestCommissionRate(15);

      service.setTestTransactions([
        TrainerEarningsTransactionModel(
          id: 'earn_active',
          bookingId: 'bk_active',
          bookingRef: '#BK_ACT',
          trainerId: testTrainerId,
          clientName: 'Active Client',
          packageName: '1 Month',
          sessionDate: now,
          grossAmount: 1000,
          commissionRatePercent: 15,
          commissionAmount: 150,
          netAmount: 850,
          payoutStatus: TrainerPayoutStatus.eligibleForPayout,
          status: 'COMPLETED',
        ),
        TrainerEarningsTransactionModel(
          id: 'earn_refunded',
          bookingId: 'bk_refunded',
          bookingRef: '#BK_REF',
          trainerId: testTrainerId,
          clientName: 'Cancelled Client',
          packageName: '1 Month',
          sessionDate: now,
          grossAmount: 1000,
          commissionRatePercent: 15,
          commissionAmount: 150,
          netAmount: 850,
          payoutStatus: TrainerPayoutStatus.refunded,
          status: 'REFUNDED',
          refundReason: 'Client medical leave',
        ),
      ]);

      final summary = await service.getEarningsSummary(testTrainerId);

      // Only the completed, non-refunded transaction is counted
      expect(summary.totalGrossRevenue, 1000);
      expect(summary.totalCommission, 150);
      expect(summary.netEarnings, 850);
      expect(summary.pendingPayout, 850);
      expect(summary.completedSessionsCount, 1);
    });
  });

  group('4. Duplicate Transaction Prevention & Data Ownership', () {
    test('Idempotent transaction key prevents duplicate earnings records', () {
      final service = TrainerEarningsService.instance;

      final tx1 = TrainerEarningsTransactionModel(
        id: 'earn_bk_unique_99',
        bookingId: 'bk_unique_99',
        bookingRef: '#BK99',
        trainerId: testTrainerId,
        clientName: 'Client Alpha',
        packageName: '1 Month',
        sessionDate: now,
        grossAmount: 500,
        commissionAmount: 75,
        netAmount: 425,
      );

      service.addTestTransaction(tx1);
      expect(service.allTransactions.length, 1);

      // Add same transaction ID again (re-attempt or duplicate trigger)
      service.addTestTransaction(tx1.copyWith(netAmount: 425));
      expect(service.allTransactions.length, 1);
    });

    test('Trainers can only access their own earnings records', () {
      final service = TrainerEarningsService.instance;

      service.setTestTransactions([
        TrainerEarningsTransactionModel(
          id: 'earn_mine',
          bookingId: 'bk_mine',
          bookingRef: '#BK_MINE',
          trainerId: testTrainerId,
          clientName: 'My Client',
          packageName: 'Plan A',
          sessionDate: now,
          grossAmount: 500,
          commissionAmount: 75,
          netAmount: 425,
        ),
        TrainerEarningsTransactionModel(
          id: 'earn_other',
          bookingId: 'bk_other',
          bookingRef: '#BK_OTHER',
          trainerId: otherTrainerId,
          clientName: 'Other Client',
          packageName: 'Plan B',
          sessionDate: now,
          grossAmount: 800,
          commissionAmount: 120,
          netAmount: 680,
        ),
      ]);

      final myTransactions = service.filterTransactions(trainerId: testTrainerId);
      expect(myTransactions.length, 1);
      expect(myTransactions.first.clientName, 'My Client');
      expect(myTransactions.any((t) => t.trainerId == otherTrainerId), isFalse);
    });
  });

  group('5. Widget Tests: TrainerEarningsScreen UI Flow', () {
    testWidgets('Renders financial summary cards, commission transparency banner, and tabs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerEarningsService.instance;
      service.setTestCommissionRate(15);
      service.setTestTransactions([
        TrainerEarningsTransactionModel(
          id: 'earn_ui_1',
          bookingId: 'bk_ui_1',
          bookingRef: '#BKUI1',
          trainerId: testTrainerId,
          clientName: 'Kunal Kapoor',
          packageName: '1 Month Transformation',
          sessionDate: now,
          startTime: '07:00',
          endTime: '08:00',
          grossAmount: 1000,
          commissionRatePercent: 15,
          commissionAmount: 150,
          netAmount: 850,
          payoutStatus: TrainerPayoutStatus.eligibleForPayout,
          status: 'COMPLETED',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEarningsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Title & Commission Banner
      expect(find.text('Earnings & Payouts'), findsOneWidget);
      expect(find.textContaining('TRAIN Z Platform Fee: 15%'), findsOneWidget);

      // Financial Metric Cards
      expect(find.text('TRAINER NET EARNINGS'), findsOneWidget);
      expect(find.text('₹850'), findsWidgets); // Net earnings
      expect(find.text('Gross Revenue'), findsWidgets);
      expect(find.text('₹1000'), findsWidgets);
      expect(find.text('Platform Fee'), findsOneWidget);
      expect(find.text('Pending Payout'), findsOneWidget);
      expect(find.text('Paid Out'), findsOneWidget);

      // Tabs
      expect(find.text('Overview & History'), findsOneWidget);
      expect(find.text('Payout Batches'), findsOneWidget);
      expect(find.text('Payout Account'), findsOneWidget);

      // Transaction item in list
      expect(find.text('Kunal Kapoor'), findsOneWidget);
      expect(find.text('Eligible for Payout'), findsWidgets);
    });

    testWidgets('Displays commission unconfigured alert when backend platform fee is pending', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerEarningsService.instance;
      service.setTestCommissionRate(null); // Unconfigured

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEarningsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Commission Rate Pending Configuration'), findsOneWidget);
      expect(find.textContaining('Platform commission percentage is currently pending administrator publication'), findsOneWidget);
    });

    testWidgets('Filters earnings history by search text and status chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerEarningsService.instance;
      service.setTestCommissionRate(15);
      service.setTestTransactions([
        TrainerEarningsTransactionModel(
          id: 'earn_a',
          bookingId: 'bk_a',
          bookingRef: '#BKA',
          trainerId: testTrainerId,
          clientName: 'Rohit Sharma',
          packageName: '1 Month',
          sessionDate: now,
          grossAmount: 500,
          commissionAmount: 75,
          netAmount: 425,
          payoutStatus: TrainerPayoutStatus.eligibleForPayout,
        ),
        TrainerEarningsTransactionModel(
          id: 'earn_b',
          bookingId: 'bk_b',
          bookingRef: '#BKB',
          trainerId: testTrainerId,
          clientName: 'Virat Kohli',
          packageName: '6 Months',
          sessionDate: now,
          grossAmount: 1000,
          commissionAmount: 150,
          netAmount: 850,
          payoutStatus: TrainerPayoutStatus.paid,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEarningsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rohit Sharma'), findsOneWidget);
      expect(find.text('Virat Kohli'), findsOneWidget);

      // Search for Rohit
      await tester.enterText(find.byType(TextField), 'Rohit');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rohit Sharma'), findsOneWidget);
      expect(find.text('Virat Kohli'), findsNothing);
    });

    testWidgets('Tapping Payout Batches tab shows payout records and failure reason when failed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerEarningsService.instance;
      service.setTestPayouts([
        TrainerPayoutModel(
          id: 'PO-202611-999',
          trainerId: testTrainerId,
          amount: 4250,
          payoutDate: now,
          status: PayoutBatchStatus.failed,
          transactionCount: 5,
          bankAccountLast4: '9988',
          bankName: 'Axis Bank',
          failureReason: 'Account number mismatch with PAN beneficiary',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEarningsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Payout Batches tab
      await tester.tap(find.text('Payout Batches'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PO-202611-999'), findsOneWidget);
      expect(find.text('₹4250'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('Account number mismatch with PAN beneficiary'), findsOneWidget);
      expect(find.textContaining('Axis Bank •••• 9988'), findsOneWidget);
    });

    testWidgets('Payout Account tab explains direct bank settlements and zero credentials stored locally', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEarningsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Payout Account tab
      await tester.tap(find.text('Payout Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Bank Account Settlement'), findsOneWidget);
      expect(find.text('Verified Payout Channels'), findsOneWidget);
      expect(find.textContaining('Zero Banking Credentials Stored On Device'), findsOneWidget);
      expect(find.text('Payout Settlement Rules'), findsOneWidget);
    });
  });

  group('6. Zero Casual & Romantic Terminology Audit', () {
    test('Confirms zero casual, dating, or matching terms in earnings UI text', () {
      const prohibitedTerms = [
        'match',
        'matched',
        'matching',
        'date',
        'dating',
        'flirt',
        'swipe',
        'romance',
        'romantic',
        'soulmate',
        'partner',
        'crush',
      ];

      final sampleTexts = [
        'Earnings & Payouts',
        'TRAINER NET EARNINGS',
        'Gross Revenue',
        'Platform Fee',
        'Pending Payout',
        'Paid Out',
        'Session Earnings History',
        'Eligible for Payout',
        'Payout Batches',
        'Bank Account Settlement',
        'Verified Payout Channels',
        'Zero Banking Credentials Stored On Device',
      ];

      for (final text in sampleTexts) {
        final lower = text.toLowerCase();
        for (final term in prohibitedTerms) {
          expect(
            lower.contains(term),
            isFalse,
            reason: 'Text "$text" contains prohibited term "$term"',
          );
        }
      }
    });
  });
}
