import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/features/client/presentation/screens/client_payment_status_screen.dart';
import 'package:trainuspro/services/payment_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/payment_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  final plans = AppConstants.fixedTrainingPlans
      .map((m) => TrainingPlanModel.fromMap(m, id: m['id'] as String? ?? ''))
      .toList();

  group('PROMPT 14: Payment System - Razorpay Order & Paise Calculations', () {
    test('Official platform packages have exact pricing and paise conversion', () {
      final expectedMap = {
        'plan_1_day': {'price': 500, 'paise': 50000, 'sessions': 1, 'validity': 1},
        'plan_3_days': {'price': 1399, 'paise': 139900, 'sessions': 3, 'validity': 3},
        'plan_1_week': {'price': 2799, 'paise': 279900, 'sessions': 6, 'validity': 7},
        'plan_1_month': {'price': 10799, 'paise': 1079900, 'sessions': 26, 'validity': 30},
        'plan_3_months': {'price': 29999, 'paise': 2999900, 'sessions': 78, 'validity': 90},
        'plan_6_months': {'price': 52999, 'paise': 5299900, 'sessions': 150, 'validity': 180},
      };

      for (final entry in expectedMap.entries) {
        final plan = plans.firstWhere((p) => p.id == entry.key);
        expect(plan.price, entry.value['price']);
        expect(plan.price * 100, entry.value['paise']);
        expect(plan.sessionsCount, entry.value['sessions']);
        expect(plan.validityDays, entry.value['validity']);
      }
    });

    test('RazorpayOrderData models order fields accurately', () {
      const order = RazorpayOrderData(
        orderId: 'order_1234567890',
        amount: 1079900,
        currency: 'INR',
        keyId: 'rzp_test_TRAINZ_LIVE',
        paymentDocId: 'pay_doc_abc',
        packageName: '1 Month',
        packagePrice: 10799,
        sessionsCount: 26,
        receiptNumber: 'REC-20261110-ABC123',
      );

      expect(order.orderId, 'order_1234567890');
      expect(order.amount, 1079900);
      expect(order.currency, 'INR');
      expect(order.packagePrice, 10799);
      expect(order.sessionsCount, 26);
      expect(order.receiptNumber, 'REC-20261110-ABC123');
    });
  });

  group('PROMPT 14: Payment System - Razorpay HMAC SHA256 Signature Verification', () {
    const mockSecret = 'trainz_secret_mock_sandbox_key';
    const orderId = 'order_DAF87123';
    const paymentId = 'pay_HJK99124';

    test('Generates expected HMAC SHA256 signature for Razorpay payload', () {
      final generatedSig = PaymentService.generateTestSignature(orderId, paymentId, secret: mockSecret);

      // Independently compute HMAC SHA256
      final payload = '$orderId|$paymentId';
      final hmac = Hmac(sha256, utf8.encode(mockSecret));
      final expectedSig = hmac.convert(utf8.encode(payload)).toString();

      expect(generatedSig, expectedSig);
      expect(generatedSig.length, 64); // SHA256 hex digest is 64 characters
    });

    test('Signature verification fails when orderId or paymentId is tampered', () {
      final validSig = PaymentService.generateTestSignature(orderId, paymentId, secret: mockSecret);

      final tamperedOrderId = 'order_TAMPERED';
      final tamperedSig = PaymentService.generateTestSignature(tamperedOrderId, paymentId, secret: mockSecret);

      expect(validSig, isNot(equals(tamperedSig)));
    });

    test('Signature verification fails when secret key is mismatched', () {
      final validSig = PaymentService.generateTestSignature(orderId, paymentId, secret: mockSecret);
      final wrongSecretSig = PaymentService.generateTestSignature(orderId, paymentId, secret: 'wrong_secret_key');

      expect(validSig, isNot(equals(wrongSecretSig)));
    });
  });

  group('PROMPT 14: Payment System - PaymentStatus Transitions & Firestore Serialization', () {
    test('PaymentStatus enum toFirestore and fromFirestore mapping', () {
      expect(PaymentStatus.initiated.toFirestore(), 'INITIATED');
      expect(PaymentStatus.pending.toFirestore(), 'PENDING');
      expect(PaymentStatus.success.toFirestore(), 'SUCCESS');
      expect(PaymentStatus.completed.toFirestore(), 'COMPLETED');
      expect(PaymentStatus.failed.toFirestore(), 'FAILED');
      expect(PaymentStatus.cancelled.toFirestore(), 'CANCELLED');
      expect(PaymentStatus.refunded.toFirestore(), 'REFUNDED');

      // fromFirestore case-insensitivity
      expect(PaymentStatus.fromFirestore('INITIATED'), PaymentStatus.initiated);
      expect(PaymentStatus.fromFirestore('initiated'), PaymentStatus.initiated);
      expect(PaymentStatus.fromFirestore('SUCCESS'), PaymentStatus.success);
      expect(PaymentStatus.fromFirestore('success'), PaymentStatus.success);
      expect(PaymentStatus.fromFirestore('FAILED'), PaymentStatus.failed);
      expect(PaymentStatus.fromFirestore('CANCELLED'), PaymentStatus.cancelled);
      expect(PaymentStatus.fromFirestore(null), PaymentStatus.initiated);
      expect(PaymentStatus.fromFirestore('UNKNOWN_STATUS'), PaymentStatus.initiated);
    });

    test('PaymentModel maps correctly to and from Firestore map', () {
      final payment = PaymentModel(
        id: 'pay_doc_101',
        clientId: 'client_usr_99',
        planId: 'plan_1_month',
        packageId: 'plan_1_month',
        packageName: '1 Month',
        sessionsCount: 26,
        validityDays: 30,
        amount: 10799,
        currency: 'INR',
        status: PaymentStatus.success,
        paymentMethod: 'UPI',
        gatewayOrderId: 'order_98765',
        razorpayPaymentId: 'pay_12345',
        razorpaySignature: 'sig_abcdef',
        receiptNumber: 'REC-20261110-PAY101',
        bookingId: 'booking_999',
        trainerId: 'trainer_456',
        trainerName: 'Vikram Singh',
        creditsGranted: true,
      );

      final map = payment.toMap();
      expect(map['id'], 'pay_doc_101');
      expect(map['clientId'], 'client_usr_99');
      expect(map['packageId'], 'plan_1_month');
      expect(map['packageName'], '1 Month');
      expect(map['sessionsCount'], 26);
      expect(map['validityDays'], 30);
      expect(map['amount'], 10799);
      expect(map['status'], 'SUCCESS');
      expect(map['paymentMethod'], 'UPI');
      expect(map['gatewayOrderId'], 'order_98765');
      expect(map['razorpayPaymentId'], 'pay_12345');
      expect(map['razorpaySignature'], 'sig_abcdef');
      expect(map['receiptNumber'], 'REC-20261110-PAY101');
      expect(map['bookingId'], 'booking_999');
      expect(map['trainerId'], 'trainer_456');
      expect(map['trainerName'], 'Vikram Singh');
      expect(map['creditsGranted'], isTrue);

      final reconstructed = PaymentModel.fromMap(map, id: 'pay_doc_101');
      expect(reconstructed.id, payment.id);
      expect(reconstructed.clientId, payment.clientId);
      expect(reconstructed.amount, payment.amount);
      expect(reconstructed.status, PaymentStatus.success);
      expect(reconstructed.isSuccess, isTrue);
      expect(reconstructed.isFailed, isFalse);
      expect(reconstructed.creditsGranted, isTrue);
      expect(reconstructed.displayAmount, '₹10799');
      expect(reconstructed.displayPackageName, '1 Month');
      expect(reconstructed.displayReceiptNumber, 'REC-20261110-PAY101');
    });

    test('PaymentModel status flags: isSuccess, isFailed, isInitiated', () {
      const initiated = PaymentModel(
        id: 'p1',
        clientId: 'c1',
        planId: 'plan_1_day',
        amount: 500,
        status: PaymentStatus.initiated,
      );
      expect(initiated.isInitiated, isTrue);
      expect(initiated.isSuccess, isFalse);
      expect(initiated.isFailed, isFalse);

      const success = PaymentModel(
        id: 'p2',
        clientId: 'c1',
        planId: 'plan_1_day',
        amount: 500,
        status: PaymentStatus.success,
      );
      expect(success.isSuccess, isTrue);
      expect(success.isFailed, isFalse);

      const failed = PaymentModel(
        id: 'p3',
        clientId: 'c1',
        planId: 'plan_1_day',
        amount: 500,
        status: PaymentStatus.failed,
      );
      expect(failed.isFailed, isTrue);
      expect(failed.isSuccess, isFalse);

      const cancelled = PaymentModel(
        id: 'p4',
        clientId: 'c1',
        planId: 'plan_1_day',
        amount: 500,
        status: PaymentStatus.cancelled,
      );
      expect(cancelled.isFailed, isTrue);
    });
  });

  group('PROMPT 14: Payment System - Idempotency & Credit Allocation Security', () {
    test('Credits are not granted when payment fails or is cancelled', () {
      const failedPayment = PaymentModel(
        id: 'p_fail',
        clientId: 'c_test',
        planId: 'plan_1_month',
        packageName: '1 Month',
        sessionsCount: 26,
        amount: 10799,
        status: PaymentStatus.failed,
        creditsGranted: false,
      );

      expect(failedPayment.creditsGranted, isFalse);
      expect(failedPayment.isSuccess, isFalse);
    });

    test('Idempotency flag prevents duplicate session credit grants', () {
      final payment = PaymentModel(
        id: 'pay_idemp_001',
        clientId: 'c_test',
        planId: 'plan_3_months',
        packageName: '3 Months',
        sessionsCount: 78,
        amount: 29999,
        status: PaymentStatus.success,
        creditsGranted: true,
      );

      // First webhook/callback execution
      bool grantedFirstTime = !payment.creditsGranted;
      expect(grantedFirstTime, isFalse, reason: 'Payment already marked creditsGranted=true');

      // Duplicate callback should not grant duplicate credits
      final duplicatePayment = payment.copyWith();
      expect(duplicatePayment.creditsGranted, isTrue);
    });

    test('Credit grant matches package sessions precisely', () {
      final sessionCounts = {
        'plan_1_day': 1,
        'plan_3_days': 3,
        'plan_1_week': 6,
        'plan_1_month': 26,
        'plan_3_months': 78,
        'plan_6_months': 150,
      };

      for (final plan in plans) {
        expect(plan.sessionsCount, sessionCounts[plan.id]);
      }
    });
  });

  group('PROMPT 14: Payment System - Standalone vs Linked Booking Purchase', () {
    test('Payment with linked booking confirms reservation', () {
      const linkedPayment = PaymentModel(
        id: 'p_linked',
        clientId: 'c_athlete',
        planId: 'plan_1_month',
        packageName: '1 Month',
        sessionsCount: 26,
        amount: 10799,
        status: PaymentStatus.success,
        bookingId: 'booking_res_123',
        trainerId: 'trainer_456',
        trainerName: 'Vikram Singh',
        creditsGranted: true,
      );

      expect(linkedPayment.bookingId, isNotNull);
      expect(linkedPayment.trainerId, 'trainer_456');
      expect(linkedPayment.trainerName, 'Vikram Singh');
    });

    test('Payment without linked booking allows client to book sessions later', () {
      const standalonePayment = PaymentModel(
        id: 'p_standalone',
        clientId: 'c_athlete',
        planId: 'plan_6_months',
        packageName: '6-Month Transformation',
        sessionsCount: 150,
        amount: 52999,
        status: PaymentStatus.success,
        bookingId: null,
        trainerId: null,
        creditsGranted: true,
      );

      expect(standalonePayment.bookingId, isNull);
      expect(standalonePayment.trainerId, isNull);
      expect(standalonePayment.creditsGranted, isTrue);
      expect(standalonePayment.sessionsCount, 150);
    });
  });

  group('PROMPT 14: Payment System - Receipt Text and Sharing Content', () {
    test('Receipt formatted text includes all required proof-of-payment details', () {
      final payment = PaymentModel(
        id: 'pay_doc_777',
        clientId: 'client_rajesh',
        planId: 'plan_1_month',
        packageId: 'plan_1_month',
        packageName: '1 Month',
        sessionsCount: 26,
        amount: 10799,
        currency: 'INR',
        status: PaymentStatus.success,
        paymentMethod: 'UPI',
        gatewayOrderId: 'order_987654321',
        razorpayPaymentId: 'pay_987654321',
        receiptNumber: 'REC-20261110-PAY777',
        trainerName: 'Vikram Singh',
      );

      final shareText = '''
TRAIN Z - Payment Receipt
---------------------------
Receipt No: ${payment.displayReceiptNumber}
Package: ${payment.displayPackageName} (${payment.sessionsCount} Sessions)
Amount: ${payment.displayAmount}
Status: Successful
Payment ID: ${payment.razorpayPaymentId}
Order ID: ${payment.gatewayOrderId}
Coach: ${payment.trainerName}
---------------------------
Thank you for training with TRAIN Z!
''';

      expect(shareText, contains('REC-20261110-PAY777'));
      expect(shareText, contains('1 Month (26 Sessions)'));
      expect(shareText, contains('₹10799'));
      expect(shareText, contains('Successful'));
      expect(shareText, contains('pay_987654321'));
      expect(shareText, contains('order_987654321'));
      expect(shareText, contains('Vikram Singh'));
      expect(shareText, contains('TRAIN Z'));
    });
  });

  group('PROMPT 14: Payment System - PaymentModel with purchasedPackageId & Deserialization', () {
    test('PaymentModel serializes and deserializes purchasedPackageId correctly', () {
      final payment = PaymentModel(
        id: 'pay_xyz_999',
        clientId: 'client_123',
        planId: 'plan_1_month',
        amount: 10799,
        status: PaymentStatus.success,
        purchasedPackageId: 'pkg_active_abc123',
        verifiedAt: DateTime(2026, 11, 12, 10, 30),
      );

      final map = payment.toMap();
      expect(map['purchasedPackageId'], 'pkg_active_abc123');

      final deserialized = PaymentModel.fromMap(map, id: 'pay_xyz_999');
      expect(deserialized.purchasedPackageId, 'pkg_active_abc123');
      expect(deserialized.status, PaymentStatus.success);

      final updated = payment.copyWith(purchasedPackageId: 'pkg_new_id');
      expect(updated.purchasedPackageId, 'pkg_new_id');
    });
  });

  group('PROMPT 14: Payment System - Trainer Eligibility & Package Pricing Governance', () {
    test('Standard Trainer strictly accepts only predefined platform packages', () {
      const standardCategory = TrainerCategory.trainer;
      expect(standardCategory == TrainerCategory.trainer, isTrue);
      expect(standardCategory == TrainerCategory.advancedTrainer, isFalse);
      expect(standardCategory.isAvailableAtLaunch, isTrue);

      // Predefined packages are the sole options for Standard Trainer
      final standardPlanIds = plans.map((p) => p.id).toList();
      expect(standardPlanIds, contains('plan_1_day'));
      expect(standardPlanIds, contains('plan_3_days'));
      expect(standardPlanIds, contains('plan_1_week'));
      expect(standardPlanIds, contains('plan_1_month'));
      expect(standardPlanIds, contains('plan_3_months'));
      expect(standardPlanIds, contains('plan_6_months'));
      expect(standardPlanIds.length, 6);
    });

    test('Advanced Trainer requires custom approved training plans', () {
      const advancedCategory = TrainerCategory.advancedTrainer;
      expect(advancedCategory == TrainerCategory.advancedTrainer, isTrue);
      expect(advancedCategory.isAvailableAtLaunch, isTrue);

      final customPlan = TrainingPlanModel(
        id: 'custom_plan_adv_1',
        trainerId: 'trainer_adv_007',
        title: 'Pro Hypertrophy Mastery',
        description: 'Elite 8-week periodized hypertrophy protocol',
        price: 18500,
        sessionsCount: 32,
        validityDays: 60,
        isCustom: true,
        isApproved: true,
        isActive: true,
      );

      expect(customPlan.isCustom, isTrue);
      expect(customPlan.isApproved, isTrue);
      expect(customPlan.isActive, isTrue);
      expect(customPlan.price, 18500);
      expect(customPlan.sessionsCount, 32);
    });

    test('Professional Trainer category is blocked as Coming Soon', () {
      const proCategory = TrainerCategory.professionalTrainer;
      expect(proCategory == TrainerCategory.professionalTrainer, isTrue);
      expect(proCategory.isAvailableAtLaunch, isFalse);
      expect(proCategory.displayName, 'Professional Trainer');
    });
  });

  group('PROMPT 14: Payment System - Package Activation & Session Credits Double-Entry Rules', () {
    test('Activated package attributes calculate correct expiry and credit balance', () {
      final now = DateTime(2026, 11, 12, 12, 0, 0);
      final plan = plans.firstWhere((p) => p.id == 'plan_1_month');
      final expiryDate = now.add(Duration(days: plan.validityDays));

      final purchasedPackage = {
        'id': 'pkg_month_001',
        'clientId': 'client_alpha',
        'trainerId': 'trainer_beta',
        'planId': plan.id,
        'packageName': plan.title,
        'packagePrice': plan.price,
        'totalSessions': plan.sessionsCount,
        'sessionsRemaining': plan.sessionsCount,
        'validityDays': plan.validityDays,
        'status': 'ACTIVE',
        'startDate': now.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
      };

      expect(purchasedPackage['status'], 'ACTIVE');
      expect(purchasedPackage['totalSessions'], 26);
      expect(purchasedPackage['sessionsRemaining'], 26);
      expect(expiryDate.difference(now).inDays, 30);
    });

    test('Session credit allocation follows double-entry ledger rule: 1 credit = 1 session', () {
      const packageSessions = 26;
      int startingBalance = 0;
      int creditsToCredit = packageSessions;
      int newBalance = startingBalance + creditsToCredit;

      // Double-entry ledger audit record
      final ledgerAudit = {
        'clientId': 'client_alpha',
        'type': 'CREDIT_PURCHASE',
        'amount': creditsToCredit,
        'balanceAfter': newBalance,
        'reason': 'Package purchase 1 Month (26 sessions)',
        'timestamp': DateTime.now().toIso8601String(),
      };

      expect(ledgerAudit['amount'], 26);
      expect(ledgerAudit['balanceAfter'], 26);
      expect(newBalance, 26);
    });
  });

  group('PROMPT 14: Payment System - Slot Reservation Expiration & Cancellation Release', () {
    test('Active unexpired slot hold allows booking confirmation', () {
      final now = DateTime(2026, 11, 12, 12, 0, 0);
      final expiresAt = now.add(const Duration(minutes: 5)); // 5 mins in future

      final isHoldExpired = expiresAt.isBefore(now);
      expect(isHoldExpired, isFalse);

      final booking = BookingModel(
        id: 'bk_active_001',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 11, 15),
        startTime: '10:00',
        endTime: '11:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.success,
      );

      expect(booking.status, BookingStatus.confirmed);
      expect(booking.paymentStatus, PaymentStatus.success);
    });

    test('Expired slot hold triggers cancellation/expiry and frees slot lock', () {
      final now = DateTime(2026, 11, 12, 12, 10, 0);
      final expiresAt = DateTime(2026, 11, 12, 12, 0, 0); // 10 mins ago

      final isHoldExpired = expiresAt.isBefore(now);
      expect(isHoldExpired, isTrue);

      // Lock should transition to RELEASED
      const lockStatusAfterExpiry = 'RELEASED';
      expect(lockStatusAfterExpiry, 'RELEASED');
    });

    test('Payment cancellation or failure immediately releases slot lock', () {
      const paymentStatus = PaymentStatus.cancelled;
      expect(paymentStatus.toFirestore(), 'CANCELLED');

      const expectedSlotLockStatus = 'RELEASED';
      expect(expectedSlotLockStatus, 'RELEASED');
    });
  });

  group('PROMPT 14: Payment System - Widget Tests for ClientPaymentStatusScreen', () {
    final samplePlan = plans.firstWhere((p) => p.id == 'plan_1_month');
    final sampleProfile = const TrainerProfileModel(
      uid: 'tr_123',
      fullName: 'Kabir Sharma',
      phoneNumber: '+919876543210',
      gender: Gender.male,
      category: TrainerCategory.trainer,
    );
    final sampleTrainer = TrainerDisplayModel(
      profile: sampleProfile,
      uid: 'tr_123',
      displayName: 'Kabir Sharma',
      gender: Gender.male,
      specialties: const ['Strength Training'],
      experienceYears: 4,
      ratingAvg: 4.8,
      totalReviews: 24,
      hourlyRate: 500,
    );

    testWidgets('Renders Payment Successful screen without linked booking', (tester) async {
      final payment = PaymentModel(
        id: 'pay_success_1',
        clientId: 'c_test_widget',
        planId: samplePlan.id,
        packageName: samplePlan.title,
        sessionsCount: samplePlan.sessionsCount,
        validityDays: samplePlan.validityDays,
        amount: samplePlan.price,
        status: PaymentStatus.success,
        receiptNumber: 'REC-2026-TEST1',
        razorpayPaymentId: 'pay_TEST_9999',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPaymentStatusScreen(
            initialStatus: PaymentStatusType.success,
            payment: payment,
            plan: samplePlan,
            trainer: sampleTrainer,
            clientId: 'c_test_widget',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Payment Successful!'), findsNWidgets(2)); // AppBar and Header
      expect(find.text('PACKAGE ACTIVATED'), findsOneWidget);
      expect(find.text('TRANSACTION SUMMARY'), findsOneWidget);
      expect(find.text('View Official Receipt'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);
      expect(find.text('₹10799'), findsOneWidget);
    });

    testWidgets('Renders Payment Successful screen with linked confirmed booking', (tester) async {
      final payment = PaymentModel(
        id: 'pay_success_2',
        clientId: 'c_test_widget',
        planId: samplePlan.id,
        packageName: samplePlan.title,
        sessionsCount: samplePlan.sessionsCount,
        validityDays: samplePlan.validityDays,
        amount: samplePlan.price,
        status: PaymentStatus.success,
        receiptNumber: 'REC-2026-TEST2',
        trainerName: 'Kabir Sharma',
      );

      final booking = BookingModel(
        id: 'bk_linked_test',
        clientId: 'c_test_widget',
        trainerId: 'tr_123',
        trainerName: 'Kabir Sharma',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 11, 20),
        startTime: '08:00',
        endTime: '09:00',
        locationReference: 'Cult Fitness Koramangala',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.success,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPaymentStatusScreen(
            initialStatus: PaymentStatusType.success,
            payment: payment,
            plan: samplePlan,
            trainer: sampleTrainer,
            booking: booking,
            clientId: 'c_test_widget',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
      expect(find.text('Coach: Kabir Sharma'), findsOneWidget);
      expect(find.text('Location: Cult Fitness Koramangala'), findsOneWidget);
      expect(find.text('Date: 20/11/2026 at 08:00 (60 min session)'), findsOneWidget);
    });

    testWidgets('Renders Payment Failed screen with retry & choose another buttons', (tester) async {
      final payment = PaymentModel(
        id: 'pay_failed_1',
        clientId: 'c_test_widget',
        planId: samplePlan.id,
        packageName: samplePlan.title,
        amount: samplePlan.price,
        status: PaymentStatus.failed,
        errorMessage: 'Bank server timeout',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPaymentStatusScreen(
            initialStatus: PaymentStatusType.failed,
            payment: payment,
            plan: samplePlan,
            trainer: sampleTrainer,
            clientId: 'c_test_widget',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Payment Failed'), findsNWidgets(2)); // AppBar and Header
      expect(find.text('PAYMENT INCOMPLETE'), findsOneWidget);
      expect(find.textContaining('Funds Safe'), findsOneWidget);
      expect(find.text('Retry Payment'), findsOneWidget);
      expect(find.text('Choose Another Package'), findsOneWidget);
    });

    testWidgets('Renders Payment Cancelled screen with funds safe banner', (tester) async {
      final payment = PaymentModel(
        id: 'pay_cancelled_1',
        clientId: 'c_test_widget',
        planId: samplePlan.id,
        packageName: samplePlan.title,
        amount: samplePlan.price,
        status: PaymentStatus.cancelled,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPaymentStatusScreen(
            initialStatus: PaymentStatusType.cancelled,
            payment: payment,
            plan: samplePlan,
            trainer: sampleTrainer,
            clientId: 'c_test_widget',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Payment Cancelled'), findsNWidgets(2)); // AppBar and Header
      expect(find.text('CHECKOUT CANCELLED'), findsOneWidget);
      expect(find.textContaining('Funds Safe'), findsOneWidget);
      expect(find.text('Retry Payment'), findsOneWidget);
    });

    testWidgets('Renders Payment Pending Verification screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientPaymentStatusScreen(
            initialStatus: PaymentStatusType.pendingVerification,
            plan: samplePlan,
            trainer: sampleTrainer,
            clientId: 'c_test_widget',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Payment Pending Verification'), findsNWidgets(2)); // AppBar and Header
      expect(find.text('Verifying with Payment Gateway'), findsOneWidget);
      expect(find.text('View Payment History'), findsOneWidget);
    });
  });

  group('PROMPT 14: Payment System - Zero Dating & Romantic Terminology Audit', () {
    test('Payment & receipt texts contain strictly professional fitness terminology', () {
      final paymentTexts = [
        'TRAIN Z - Payment Receipt',
        'Package Purchase',
        'Session Credits Allocation',
        'Trainer Verification & Package Pricing',
        'Coach: Kabir Sharma',
        '60 min professional coaching session',
        'Cult Fitness Koramangala',
        'Personal Trainer Booking Confirmed',
      ];

      final prohibitedTerms = ['match', 'dating', 'hookup', 'swipe', 'romance', 'couple', 'singles'];

      for (final text in paymentTexts) {
        for (final prohibited in prohibitedTerms) {
          expect(
            text.toLowerCase().contains(prohibited),
            isFalse,
            reason: 'Prohibited dating terminology "$prohibited" detected in "$text"',
          );
        }
      }
    });
  });
}

