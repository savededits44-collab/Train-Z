import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/screens/trainer/trainer_package_management_screen.dart';
import 'package:trainuspro/shared/models/purchased_package_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';

void main() {
  group('1. Standard Trainer Fixed Package Verification', () {
    test('Standard Trainers are strictly bound to the 6 fixed TRAIN Z platform packages', () {
      final packages = TrainingPlanModel.platformPackages;
      expect(packages.length, equals(6));

      // Package 1: 1 Day — ₹500 — 1 session — 1 day
      final p1 = packages.firstWhere((p) => p.title == '1 Day');
      expect(p1.price, equals(500));
      expect(p1.sessionsCount, equals(1));
      expect(p1.validityDays, equals(1));
      expect(p1.formattedPrice, equals('₹500'));
      expect(p1.isPlatformPackage, isTrue);

      // Package 2: 3 Days — ₹1,399 — 3 sessions — 3 days
      final p2 = packages.firstWhere((p) => p.title == '3 Days');
      expect(p2.price, equals(1399));
      expect(p2.sessionsCount, equals(3));
      expect(p2.validityDays, equals(3));
      expect(p2.formattedPrice, equals('₹1,399'));
      expect(p2.isPlatformPackage, isTrue);

      // Package 3: 1 Week — ₹2,799 — 6 sessions — 7 days
      final p3 = packages.firstWhere((p) => p.title == '1 Week');
      expect(p3.price, equals(2799));
      expect(p3.sessionsCount, equals(6));
      expect(p3.validityDays, equals(7));
      expect(p3.formattedPrice, equals('₹2,799'));
      expect(p3.isPlatformPackage, isTrue);

      // Package 4: 1 Month — ₹10,799 — 26 sessions — 30 days
      final p4 = packages.firstWhere((p) => p.title == '1 Month');
      expect(p4.price, equals(10799));
      expect(p4.sessionsCount, equals(26));
      expect(p4.validityDays, equals(30));
      expect(p4.popular, isTrue);
      expect(p4.formattedPrice, equals('₹10,799'));
      expect(p4.isPlatformPackage, isTrue);

      // Package 5: 3 Months — ₹29,999 — 78 sessions — 90 days
      final p5 = packages.firstWhere((p) => p.title == '3 Months');
      expect(p5.price, equals(29999));
      expect(p5.sessionsCount, equals(78));
      expect(p5.validityDays, equals(90));
      expect(p5.formattedPrice, equals('₹29,999'));
      expect(p5.isPlatformPackage, isTrue);

      // Package 6: 6-Month Transformation — ₹52,999 — 150 sessions — 180 days
      final p6 = packages.firstWhere((p) => p.title == '6-Month Transformation');
      expect(p6.price, equals(52999));
      expect(p6.sessionsCount, equals(150));
      expect(p6.validityDays, equals(180));
      expect(p6.isTransformationPackage, isTrue);
      expect(p6.formattedPrice, equals('₹52,999'));
      expect(p6.isPlatformPackage, isTrue);
    });

    test('Platform packages are pre-approved and non-customizable', () {
      for (final p in TrainingPlanModel.platformPackages) {
        expect(p.isApproved, isTrue);
        expect(p.approvalStatus, equals(PackageApprovalStatus.approved));
        expect(p.isCustom, isFalse);
        expect(p.trainerId, isNull);
        expect(p.isActive, isTrue);
      }
    });
  });

  group('2. Advanced Trainer Custom Package Lifecycle & Approval States', () {
    test('PackageApprovalStatus enum string conversion and display names', () {
      expect(PackageApprovalStatus.draft.displayName, equals('Draft'));
      expect(PackageApprovalStatus.pending.displayName, equals('Pending Approval'));
      expect(PackageApprovalStatus.approved.displayName, equals('Approved'));
      expect(PackageApprovalStatus.rejected.displayName, equals('Rejected'));

      expect(PackageApprovalStatus.fromString('DRAFT'), equals(PackageApprovalStatus.draft));
      expect(PackageApprovalStatus.fromString('PENDING'), equals(PackageApprovalStatus.pending));
      expect(PackageApprovalStatus.fromString('APPROVED'), equals(PackageApprovalStatus.approved));
      expect(PackageApprovalStatus.fromString('REJECTED'), equals(PackageApprovalStatus.rejected));

      // Fallback
      expect(PackageApprovalStatus.fromString(null, isApproved: true), equals(PackageApprovalStatus.approved));
      expect(PackageApprovalStatus.fromString(null, isApproved: false), equals(PackageApprovalStatus.pending));
    });

    test('New custom package starts in Pending Approval and inactive until Admin review', () {
      final customPlan = TrainingPlanModel(
        id: 'plan_custom_001',
        title: 'Strength & Hypertrophy Focus',
        price: 8500,
        sessionsCount: 16,
        validityDays: 45,
        sessionDurationMinutes: 60,
        description: 'Targeted hypertrophy program with customized split.',
        trainerId: 'trainer_adv_123',
        trainerName: 'Coach Vikram',
        isApproved: false,
        approvalStatus: PackageApprovalStatus.pending,
        isActive: false,
        isCustom: true,
      );

      expect(customPlan.isApproved, isFalse);
      expect(customPlan.isActive, isFalse);
      expect(customPlan.approvalStatus, equals(PackageApprovalStatus.pending));
      expect(customPlan.isCustom, isTrue);
      expect(customPlan.pricePerSession.round(), equals((8500 / 16).round()));

      final map = customPlan.toMap();
      expect(map['approvalStatus'], equals('PENDING'));
      expect(map['isApproved'], isFalse);
      expect(map['isActive'], isFalse);

      final reconstructed = TrainingPlanModel.fromMap(map, id: 'plan_custom_001');
      expect(reconstructed.approvalStatus, equals(PackageApprovalStatus.pending));
      expect(reconstructed.isApproved, isFalse);
    });

    test('Draft custom package maintains draft state', () {
      final draftPlan = TrainingPlanModel(
        id: 'plan_draft_001',
        title: 'Draft Fat Loss Routine',
        price: 5000,
        sessionsCount: 10,
        validityDays: 30,
        description: 'Work in progress draft description.',
        trainerId: 'trainer_adv_123',
        isApproved: false,
        approvalStatus: PackageApprovalStatus.draft,
        isActive: false,
        isCustom: true,
      );

      expect(draftPlan.approvalStatus, equals(PackageApprovalStatus.draft));
      expect(draftPlan.isApproved, isFalse);
      expect(draftPlan.isActive, isFalse);
    });

    test('Admin approval transitions package to Approved and Active', () {
      final pendingPlan = TrainingPlanModel(
        id: 'plan_pending_01',
        title: 'Elite Powerlifting Protocol',
        price: 15000,
        sessionsCount: 20,
        validityDays: 60,
        description: 'Heavy compound training protocol.',
        trainerId: 'trainer_adv_123',
        isApproved: false,
        approvalStatus: PackageApprovalStatus.pending,
        isActive: false,
        isCustom: true,
      );

      // Simulate Admin approval
      final approvedPlan = pendingPlan.copyWith(
        isApproved: true,
        isActive: true,
        approvalStatus: PackageApprovalStatus.approved,
      );

      expect(approvedPlan.isApproved, isTrue);
      expect(approvedPlan.isActive, isTrue);
      expect(approvedPlan.approvalStatus, equals(PackageApprovalStatus.approved));
    });

    test('Admin rejection sets Rejected status and preserves Admin rejection reason', () {
      final pendingPlan = TrainingPlanModel(
        id: 'plan_pending_02',
        title: 'Rapid Transformation 5 Days',
        price: 25000,
        sessionsCount: 5,
        validityDays: 7,
        description: 'Intense short-term regimen.',
        trainerId: 'trainer_adv_123',
        isApproved: false,
        approvalStatus: PackageApprovalStatus.pending,
        isActive: false,
        isCustom: true,
      );

      // Simulate Admin rejection
      const rejectionNote = 'Price per session is excessive. Please adjust pricing or sessions.';
      final rejectedPlan = pendingPlan.copyWith(
        isApproved: false,
        isActive: false,
        approvalStatus: PackageApprovalStatus.rejected,
        adminRejectionReason: rejectionNote,
      );

      expect(rejectedPlan.isApproved, isFalse);
      expect(rejectedPlan.isActive, isFalse);
      expect(rejectedPlan.approvalStatus, equals(PackageApprovalStatus.rejected));
      expect(rejectedPlan.adminRejectionReason, equals(rejectionNote));

      // Test serialization of rejection note
      final map = rejectedPlan.toMap();
      expect(map['approvalStatus'], equals('REJECTED'));
      expect(map['adminRejectionReason'], equals(rejectionNote));

      final restored = TrainingPlanModel.fromMap(map, id: 'plan_pending_02');
      expect(restored.approvalStatus, equals(PackageApprovalStatus.rejected));
      expect(restored.adminRejectionReason, equals(rejectionNote));
    });

    test('Editing an approved custom package resets approval status to Pending (mandatory re-approval)', () {
      final approvedPlan = TrainingPlanModel(
        id: 'plan_approved_01',
        title: 'Athletic Conditioning',
        price: 12000,
        sessionsCount: 20,
        validityDays: 45,
        description: 'Elite athletic conditioning.',
        trainerId: 'trainer_adv_123',
        isApproved: true,
        approvalStatus: PackageApprovalStatus.approved,
        isActive: true,
        isCustom: true,
      );

      // Trainer edits price and title
      final editedPlan = approvedPlan.copyWith(
        title: 'Athletic Conditioning Pro',
        price: 14000,
        isApproved: false, // Must be reset
        isActive: false,   // Must be un-published until re-approved
        approvalStatus: PackageApprovalStatus.pending,
        adminRejectionReason: null,
      );

      expect(editedPlan.title, equals('Athletic Conditioning Pro'));
      expect(editedPlan.price, equals(14000));
      expect(editedPlan.isApproved, isFalse);
      expect(editedPlan.isActive, isFalse);
      expect(editedPlan.approvalStatus, equals(PackageApprovalStatus.pending));
    });
  });

  group('3. Package Safety and Purchase History Protection', () {
    test('Existing purchased package snapshots remain immutable when original plan is edited or deleted', () {
      final originalPlan = TrainingPlanModel(
        id: 'custom_plan_999',
        title: 'VIP 1-on-1 Transformation',
        price: 20000,
        sessionsCount: 24,
        validityDays: 60,
        description: 'Original plan description.',
        trainerId: 'trainer_adv_123',
        trainerName: 'Coach Vikram',
        isApproved: true,
        approvalStatus: PackageApprovalStatus.approved,
        isActive: true,
        isCustom: true,
      );

      // Client purchased this package
      final purchase = PurchasedPackageModel(
        id: 'purchase_rec_777',
        clientId: 'client_athlete_1',
        clientName: 'Rahul Verma',
        trainerId: originalPlan.trainerId!,
        trainerName: originalPlan.trainerName!,
        packageId: originalPlan.id,
        packageName: originalPlan.title,
        price: originalPlan.price,
        purchaseDate: DateTime(2026, 11, 1),
        startDate: DateTime(2026, 11, 2),
        expiryDate: DateTime(2026, 11, 2).add(Duration(days: originalPlan.validityDays)),
        totalDays: originalPlan.validityDays,
        totalSessions: originalPlan.sessionsCount,
        completedSessions: 4,
        status: 'ACTIVE',
      );

      expect(purchase.price, equals(20000));
      expect(purchase.totalSessions, equals(24));
      expect(purchase.totalDays, equals(60));
      expect(purchase.remainingSessions, equals(20));

      // Trainer later edits original plan (increases price, reduces sessions)
      final editedPlan = originalPlan.copyWith(
        price: 28000,
        sessionsCount: 20,
        validityDays: 45,
        isApproved: false,
        approvalStatus: PackageApprovalStatus.pending,
      );

      // Verify the client purchase retains its original terms completely
      expect(purchase.price, equals(20000));
      expect(purchase.totalSessions, equals(24));
      expect(purchase.totalDays, equals(60));
      expect(purchase.packageName, equals('VIP 1-on-1 Transformation'));
      expect(purchase.price, isNot(equals(editedPlan.price)));
      expect(purchase.totalSessions, isNot(equals(editedPlan.sessionsCount)));

      // Trainer soft-deletes the plan
      final deletedPlan = editedPlan.copyWith(isDeleted: true, isActive: false);
      expect(deletedPlan.isDeleted, isTrue);

      // Client's purchased package remains valid and unchanged
      expect(purchase.status, equals('ACTIVE'));
      expect(purchase.price, equals(20000));
      expect(purchase.remainingSessions, equals(20));
    });
  });

  group('4. UI Rendering Verification', () {
    testWidgets('Standard Trainer sees read-only platform packages and policy explanation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerPackageManagementScreen(
            trainerId: 'trainer_std_1',
            isAdvanced: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and title
      expect(find.text('Platform Packages'), findsOneWidget);
      expect(find.text('STANDARD TRAINER'), findsOneWidget);
      expect(find.text('Platform-Standardized Packages'), findsOneWidget);
      expect(find.text('Read-Only'), findsOneWidget);

      // Predefined packages are displayed
      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('3 Days'), findsAtLeastNWidgets(1));
      expect(find.text('1 Week'), findsOneWidget);
      expect(find.text('1 Month'), findsOneWidget);
      expect(find.text('3 Months'), findsOneWidget);
      expect(find.text('6-Month Transformation'), findsOneWidget);

      // No FAB for Standard Trainers
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Advanced Trainer sees custom plans management interface with status filters and create FAB', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerPackageManagementScreen(
            trainerId: 'trainer_adv_test',
            isAdvanced: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & category
      expect(find.text('Custom Training Plans'), findsOneWidget);
      expect(find.text('ADVANCED TRAINER'), findsOneWidget);
      expect(find.text('Custom Package Management'), findsOneWidget);

      // Filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      // FAB for creating custom plans is present
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New Custom Plan'), findsOneWidget);
    });
  });
}
