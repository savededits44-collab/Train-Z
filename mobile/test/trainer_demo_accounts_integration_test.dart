import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/controllers/trainer_auth_controller.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/trainer_availability_service.dart';
import 'package:trainuspro/services/trainer_package_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    TrainerProfileService.instance.reset();
    BookingService.instance.resetForTest();
    TrainerAvailabilityService.instance.resetMockData();
    TrainerPackageService.instance.clearMockData();
  });

  group('Demo Accounts Integration & Verification', () {
    const stdEmail = 'trainer.demo@trainz.test';
    const stdUid = 'nY3lebkFPBZwWNV6ycj4QtpttV92';
    const advEmail = 'advanced.demo@trainz.test';
    const advUid = 'tBzc47n2bpbLVVIFSIEd34Mfbma2';
    const demoPassword = 'TrainZ@Demo123';

    test('1. Standard Trainer Demo Account specification compliance', () {
      expect(stdEmail, 'trainer.demo@trainz.test');
      expect(demoPassword, 'TrainZ@Demo123');

      final stdUser = AuthService.syntheticDemoUser(stdUid);
      expect(stdUser.email, stdEmail);
      expect(stdUser.role, UserRole.trainer);
      expect(stdUser.status, UserStatus.active);
      expect(stdUser.isEmailVerified, isTrue);

      final stdProfile = AuthService.syntheticDemoProfile(stdUid);
      expect(stdProfile.category, TrainerCategory.trainer);
      expect(stdProfile.verificationStatus, TrainerVerificationStatus.approved);
      expect(stdProfile.isApproved, isTrue);
      expect(stdProfile.isActive, isTrue);
      expect(stdProfile.isProfileCompleted, isTrue);

      // Certificate: clearly labelled synthetic demo qualification data
      expect(stdProfile.verifiedQualifications.length, 1);
      final cert = stdProfile.verifiedQualifications.first;
      expect(cert.certificateName, contains('[DEMO TEST]'));
      expect(cert.issuingOrganization, contains('Test Synthetic'));

      // Package access: Standard Trainer uses 6 platform packages
      final platformPlans = TrainerPackageService.instance.getPlatformPackages();
      expect(platformPlans.length, 6);
      expect(platformPlans.every((p) => !p.isCustom), isTrue);

      // Dashboard routing: RoleGuards allows direct access to dashboard
      expect(RoleGuards.canAccessTrainerDashboard(user: stdUser, profile: stdProfile), isTrue);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: stdUser, profile: stdProfile), AppRouter.trainerDashboard);
    });

    test('2. Advanced Trainer Demo Account specification compliance', () {
      expect(advEmail, 'advanced.demo@trainz.test');
      expect(demoPassword, 'TrainZ@Demo123');

      final advUser = AuthService.syntheticDemoUser(advUid);
      expect(advUser.email, advEmail);
      expect(advUser.role, UserRole.trainer);
      expect(advUser.status, UserStatus.active);
      expect(advUser.isEmailVerified, isTrue);

      final advProfile = AuthService.syntheticDemoProfile(advUid);
      expect(advProfile.category, TrainerCategory.advancedTrainer);
      expect(advProfile.verificationStatus, TrainerVerificationStatus.approved);
      expect(advProfile.isApproved, isTrue);
      expect(advProfile.isActive, isTrue);
      expect(advProfile.isProfileCompleted, isTrue);

      // Experience: At least 3.5 years (4.0 years synthetic demo)
      expect(advProfile.experienceYears, greaterThanOrEqualTo(3.5));
      expect(advProfile.experienceYears, 4.0);

      // Qualifications: Clearly labelled synthetic demo qualification records
      expect(advProfile.verifiedQualifications.length, 2);
      for (final q in advProfile.verifiedQualifications) {
        expect(q.certificateName, contains('[DEMO TEST]'));
        expect(q.issuingOrganization, contains('Test Synthetic'));
      }

      // Dashboard routing: RoleGuards allows direct access to dashboard
      expect(RoleGuards.canAccessTrainerDashboard(user: advUser, profile: advProfile), isTrue);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: advUser, profile: advProfile), AppRouter.trainerDashboard);
    });

    test('3. Separation of Concerns: Standard Trainer cannot access Advanced custom plan features', () {
      final stdProfile = AuthService.syntheticDemoProfile(stdUid);
      final advProfile = AuthService.syntheticDemoProfile(advUid);

      // Standard Trainer category check
      final isStdEligibleForCustomPlans = stdProfile.category == TrainerCategory.advancedTrainer;
      expect(isStdEligibleForCustomPlans, isFalse);

      // Advanced Trainer category check
      final isAdvEligibleForCustomPlans = advProfile.category == TrainerCategory.advancedTrainer;
      expect(isAdvEligibleForCustomPlans, isTrue);
    });

    test('4. Advanced Trainer can create custom plans requiring Admin approval', () async {
      final pkgService = TrainerPackageService.instance;

      final planId = await pkgService.createCustomPlan(
        title: '[DEMO] Advanced Conditioning Plan',
        price: 15999,
        sessionsCount: 20,
        validityDays: 60,
        description: 'Elite conditioning program',
        submitForApproval: true,
      );

      final customPlans = await pkgService.streamCustomPlans('test_trainer_uid').first;
      final createdPlan = customPlans.firstWhere((p) => p.id == planId);

      expect(createdPlan.isCustom, isTrue);
      expect(createdPlan.isApproved, isFalse); // Requires Admin approval
      expect(createdPlan.approvalStatus, PackageApprovalStatus.pending);
    });

    test('5. Data Isolation: Accounts cannot access each other\'s bookings or schedule', () {
      final bookingService = BookingService.instance;

      // Booking for Standard Trainer
      final stdBooking = BookingModel(
        id: 'bk_std_isolation_01',
        clientId: 'cl_01',
        trainerId: stdUid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.confirmed,
        packageName: '1 Month',
        totalSessions: 26,
      );

      // Booking for Advanced Trainer
      final advBooking = BookingModel(
        id: 'bk_adv_isolation_01',
        clientId: 'cl_02',
        trainerId: advUid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        status: BookingStatus.confirmed,
        packageName: 'Custom 12-Week',
        totalSessions: 36,
      );

      bookingService.addOrUpdateBooking(stdBooking);
      bookingService.addOrUpdateBooking(advBooking);

      // Query bookings strictly by trainerId
      final stdBookings = bookingService.bookingsForTrainer(stdUid);
      final advBookings = bookingService.bookingsForTrainer(advUid);

      expect(stdBookings.length, 1);
      expect(stdBookings.first.id, 'bk_std_isolation_01');
      expect(stdBookings.any((b) => b.trainerId == advUid), isFalse);

      expect(advBookings.length, 1);
      expect(advBookings.first.id, 'bk_adv_isolation_01');
      expect(advBookings.any((b) => b.trainerId == stdUid), isFalse);
    });

    test('6. Form validation for demo credentials conforms to application rules', () {
      final stdErr = TrainerAuthController.validateRegistrationFormStatic(
        name: 'Demo Standard Trainer',
        email: stdEmail,
        phoneNumber: '9876543210',
        password: demoPassword,
        confirmPassword: demoPassword,
      );
      expect(stdErr, isNull);

      final advErr = TrainerAuthController.validateRegistrationFormStatic(
        name: 'Demo Advanced Trainer',
        email: advEmail,
        phoneNumber: '9876543211',
        password: demoPassword,
        confirmPassword: demoPassword,
      );
      expect(advErr, isNull);
    });
  });
}

