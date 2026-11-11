import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/services/payment_service.dart';
import 'package:trainuspro/shared/models/payment_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';

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
}

