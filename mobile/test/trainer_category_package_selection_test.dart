import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/client/presentation/screens/client_package_selection_screen.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

TrainerDisplayModel _createTestTrainer({
  required String uid,
  required String displayName,
  required TrainerCategory category,
  Gender gender = Gender.male,
  int hourlyRate = 500,
  double experienceYears = 5.0,
}) {
  return TrainerDisplayModel(
    profile: TrainerProfileModel(
      uid: uid,
      category: category,
      hourlyRate: hourlyRate,
      experienceYears: experienceYears,
      isActive: true,
      verificationStatus: TrainerVerificationStatus.approved,
    ),
    uid: uid,
    displayName: displayName,
    gender: gender,
    specialties: const ['Strength Training', 'Hypertrophy'],
    experienceYears: experienceYears,
    ratingAvg: 4.9,
    totalReviews: 12,
    hourlyRate: hourlyRate,
    gymName: 'Fitness Hub',
    serviceArea: 'Central Hub',
  );
}

void main() {
  group('1. Predefined TRAIN Z Platform Packages (Standard Trainer)', () {
    test('Platform packages contain exactly 6 predefined tiers with platform-controlled pricing', () {
      final packages = TrainingPlanModel.platformPackages;
      expect(packages.length, equals(6));

      // 1 Day
      final day1 = packages.firstWhere((p) => p.title == '1 Day');
      expect(day1.price, equals(500));
      expect(day1.sessionsCount, equals(1));
      expect(day1.validityDays, equals(1));
      expect(day1.sessionDurationMinutes, equals(60));
      expect(day1.isPlatformPackage, isTrue);
      expect(day1.packageTypeLabel, equals('TRAIN Z Platform Package'));

      // 3 Days
      final days3 = packages.firstWhere((p) => p.title == '3 Days');
      expect(days3.price, equals(1399));
      expect(days3.sessionsCount, equals(3));
      expect(days3.validityDays, equals(3));
      expect(days3.sessionDurationMinutes, equals(60));
      expect(days3.isPlatformPackage, isTrue);

      // 1 Week
      final week1 = packages.firstWhere((p) => p.title == '1 Week');
      expect(week1.price, equals(2799));
      expect(week1.sessionsCount, equals(6));
      expect(week1.validityDays, equals(7));
      expect(week1.sessionDurationMinutes, equals(60));
      expect(week1.isPlatformPackage, isTrue);

      // 1 Month
      final month1 = packages.firstWhere((p) => p.title == '1 Month');
      expect(month1.price, equals(10799));
      expect(month1.sessionsCount, equals(26));
      expect(month1.validityDays, equals(30));
      expect(month1.sessionDurationMinutes, equals(60));
      expect(month1.isPlatformPackage, isTrue);

      // 3 Months
      final months3 = packages.firstWhere((p) => p.title == '3 Months');
      expect(months3.price, equals(29999));
      expect(months3.sessionsCount, equals(78));
      expect(months3.validityDays, equals(90));
      expect(months3.sessionDurationMinutes, equals(60));
      expect(months3.isPlatformPackage, isTrue);

      // 6-Month Transformation
      final trans6 = packages.firstWhere((p) => p.title == '6-Month Transformation');
      expect(trans6.price, equals(52999));
      expect(trans6.sessionsCount, equals(150));
      expect(trans6.validityDays, equals(180));
      expect(trans6.sessionDurationMinutes, equals(60));
      expect(trans6.isTransformationPackage, isTrue);
      expect(trans6.isPlatformPackage, isTrue);
    });

    test('Platform packages have verified 60-minute duration and approved status', () {
      for (final p in TrainingPlanModel.platformPackages) {
        expect(p.sessionDurationMinutes, equals(60));
        expect(p.isApproved, isTrue);
        expect(p.isActive, isTrue);
        expect(p.trainerId, isNull);
        expect(p.pricePerSession, greaterThan(0));
      }
    });
  });

  group('2. Advanced Trainer Custom Training Plans Model & Filtering', () {
    test('Advanced Trainer custom plan serialization & category identification', () {
      final customPlan = TrainingPlanModel(
        id: 'plan_adv_01',
        title: 'Elite Hypertrophy & Biomechanics Protocol',
        description: 'Comprehensive 1-on-1 hypertrophy and athletic conditioning program.',
        price: 18500,
        sessionsCount: 30,
        validityDays: 45,
        sessionDurationMinutes: 60,
        trainerId: 'trainer_adv_999',
        trainerName: 'Vikram Rajput',
        isApproved: true,
        isActive: true,
        isCustom: true,
      );

      expect(customPlan.isPlatformPackage, isFalse);
      expect(customPlan.packageTypeLabel, equals('Advanced Trainer Custom Plan'));
      expect(customPlan.pricePerSession.round(), equals((18500 / 30).round()));

      final map = customPlan.toMap();
      expect(map['trainerId'], equals('trainer_adv_999'));
      expect(map['trainerName'], equals('Vikram Rajput'));
      expect(map['isApproved'], isTrue);
      expect(map['isCustom'], isTrue);

      final restored = TrainingPlanModel.fromMap(map, id: 'plan_adv_01');
      expect(restored.id, equals('plan_adv_01'));
      expect(restored.trainerId, equals('trainer_adv_999'));
      expect(restored.trainerName, equals('Vikram Rajput'));
      expect(restored.isApproved, isTrue);
      expect(restored.isCustom, isTrue);
      expect(restored.packageTypeLabel, equals('Advanced Trainer Custom Plan'));
    });

    test('Strict filtering: Excludes unapproved, inactive, and other trainers custom plans', () {
      final trainerUid = 'trainer_adv_100';

      final allPlansInDb = [
        // 1. Valid approved custom plan for this trainer
        TrainingPlanModel(
          id: 'plan_1',
          title: 'Powerlifting Foundation',
          description: 'Specialized 1-on-1 powerlifting mechanics.',
          price: 12000,
          sessionsCount: 20,
          validityDays: 30,
          trainerId: trainerUid,
          isApproved: true,
          isActive: true,
          isCustom: true,
        ),
        // 2. Unapproved custom plan (pending admin review) -> MUST BE EXCLUDED
        TrainingPlanModel(
          id: 'plan_2',
          title: 'Unapproved Draft Plan',
          description: 'Pending review plan.',
          price: 15000,
          sessionsCount: 25,
          validityDays: 30,
          trainerId: trainerUid,
          isApproved: false,
          isActive: true,
          isCustom: true,
        ),
        // 3. Inactive plan -> MUST BE EXCLUDED
        TrainingPlanModel(
          id: 'plan_3',
          title: 'Archived Plan',
          description: 'Archived training plan.',
          price: 8000,
          sessionsCount: 10,
          validityDays: 20,
          trainerId: trainerUid,
          isApproved: true,
          isActive: false,
          isCustom: true,
        ),
        // 4. Plan belonging to another Advanced Trainer -> MUST BE EXCLUDED
        TrainingPlanModel(
          id: 'plan_4',
          title: 'Other Trainer Plan',
          description: 'Different trainer custom plan.',
          price: 20000,
          sessionsCount: 30,
          validityDays: 60,
          trainerId: 'trainer_adv_OTHER',
          isApproved: true,
          isActive: true,
          isCustom: true,
        ),
      ];

      // Simulate Firestore filter: trainerId == trainerUid, isApproved == true, isActive == true
      final filtered = allPlansInDb.where((p) =>
          p.trainerId == trainerUid && p.isApproved == true && p.isActive == true).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('plan_1'));
      expect(filtered.first.title, equals('Powerlifting Foundation'));
    });
  });

  group('3. Category Convenience Getters on TrainerDisplayModel', () {
    test('TrainerDisplayModel exposes category directly from profile', () {
      final standardDisplay = _createTestTrainer(
        uid: 'std_01',
        displayName: 'Rahul Verma',
        category: TrainerCategory.trainer,
      );
      expect(standardDisplay.category, equals(TrainerCategory.trainer));

      final advancedDisplay = _createTestTrainer(
        uid: 'adv_01',
        displayName: 'Arjun Kapoor',
        category: TrainerCategory.advancedTrainer,
      );
      expect(advancedDisplay.category, equals(TrainerCategory.advancedTrainer));

      final professionalDisplay = _createTestTrainer(
        uid: 'pro_01',
        displayName: 'Sunita Rao',
        category: TrainerCategory.professionalTrainer,
        gender: Gender.female,
      );
      expect(professionalDisplay.category, equals(TrainerCategory.professionalTrainer));
    });
  });

  group('4. Widget Tests: ClientPackageSelectionScreen Category Display', () {
    testWidgets('Standard Trainer displays TRAIN Z platform packages and no auto-selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final standardTrainer = _createTestTrainer(
        uid: 'tr_std_01',
        displayName: 'Rahul Sharma',
        category: TrainerCategory.trainer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPackageSelectionScreen(
            trainer: standardTrainer,
            clientGender: Gender.male,
            clientId: 'client_1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Trainer Header & Category
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Trainer'), findsWidgets);
      expect(find.text('Standard Platform Packages'), findsOneWidget);

      // 2. Verify platform packages are displayed
      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('1 Month'), findsOneWidget);
      expect(find.text('₹10,799'), findsOneWidget);
      expect(find.text('6-Month Transformation'), findsOneWidget);
      expect(find.text('₹52,999'), findsOneWidget);

      // 3. Verify NO automatic package selection on load
      expect(find.text('No Package Selected'), findsOneWidget);
      expect(find.text('Select a Package'), findsOneWidget);

      // Verify the sticky button is initially disabled
      final elevatedButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Select a Package'));
      expect(elevatedButton.onPressed, isNull);

      // 4. Select a package (e.g. 1 Month)
      await tester.ensureVisible(find.text('1 Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 Month'));
      await tester.pumpAndSettle();

      // Now sticky bar updates with selected plan
      expect(find.text('1 Month'), findsWidgets);
      expect(find.text('Review & Continue'), findsOneWidget);

      // 5. Tap "Review & Continue" to trigger transparent summary modal
      await tester.tap(find.text('Review & Continue'));
      await tester.pumpAndSettle();

      // Verify transparent summary bottom sheet contents
      expect(find.text('Package Summary'), findsOneWidget);
      expect(find.text('Selected Trainer'), findsOneWidget);
      expect(find.text('Selected Package'), findsOneWidget);
      expect(find.text('Total Price'), findsOneWidget);
      expect(find.text('Important Package Conditions'), findsOneWidget);
      expect(find.textContaining('12-Hour Cancellation Rule'), findsOneWidget);
      expect(find.textContaining('Full 60-minute 1-on-1 personal training sessions'), findsOneWidget);
      expect(find.text('Continue to Schedule Session'), findsOneWidget);
    });

    testWidgets('Professional Trainer displays Coming Soon card with purchase disabled', (tester) async {
      final proTrainer = _createTestTrainer(
        uid: 'tr_pro_01',
        displayName: 'Master Coach Vikram',
        category: TrainerCategory.professionalTrainer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPackageSelectionScreen(
            trainer: proTrainer,
            clientGender: Gender.male,
            clientId: 'client_1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Category chip displays "Professional Trainer • Coming Soon"
      expect(find.text('Professional Trainer • Coming Soon'), findsWidgets);

      // Coming soon banner and explanation is displayed
      expect(find.textContaining('Packages for Professional Trainers are coming soon and are unavailable for booking at launch'), findsOneWidget);
      expect(find.text('Explore Other Trainers'), findsOneWidget);

      // Sticky purchase bar is completely disabled/omitted
      expect(find.text('Review & Continue'), findsNothing);
      expect(find.text('Select a Package'), findsNothing);
    });

    testWidgets('Advanced Trainer displays empty state message when no plans exist', (tester) async {
      final advTrainer = _createTestTrainer(
        uid: 'tr_adv_empty',
        displayName: 'Anjali Desai',
        category: TrainerCategory.advancedTrainer,
        gender: Gender.female,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientPackageSelectionScreen(
            trainer: advTrainer,
            clientGender: Gender.female,
            clientId: 'client_female_1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Advanced Trainer category header
      expect(find.text('Advanced Trainer Custom Plans'), findsOneWidget);

      // Exact empty state requirement: "No training plans are currently available from this trainer."
      expect(find.text('No training plans are currently available from this trainer.'), findsOneWidget);
      expect(find.text('Explore Other Trainers'), findsOneWidget);

      // No packages to select
      expect(find.text('Review & Continue'), findsNothing);
    });
  });

  group('5. Zero Dating & Romantic Language Audit', () {
    test('Verify all platform package titles, descriptions, and labels are professional and free of dating/matching terms', () {
      final forbiddenTerms = [
        'match',
        'matching',
        'find your match',
        'match found',
        'no matching found',
        'matched coaches',
        'start matching',
        'browse trainer',
        'coach',
      ];

      for (final p in TrainingPlanModel.platformPackages) {
        final textToCheck = '${p.title} ${p.description}'.toLowerCase();
        for (final term in forbiddenTerms) {
          expect(
            textToCheck.contains(term),
            isFalse,
            reason: 'Package "${p.title}" contains forbidden term "$term"',
          );
        }
      }
    });
  });
}
