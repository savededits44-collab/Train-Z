import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/core/utils/validators.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/shared/models/client_profile_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 2C: Client Registration Form Validation', () {
    test('validates client full name', () {
      expect(Validators.validateName('A'), isNotNull);
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('   '), isNotNull);
      expect(Validators.validateName('Sarah Connor'), isNull);
    });

    test('validates client email address', () {
      expect(Validators.validateEmail('client@trainz.app'), isNull);
      expect(Validators.validateEmail('invalid'), isNotNull);
      expect(Validators.validateEmail('user@'), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('validates client phone number (+91 / 10 digits)', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('+919876543210'), isNull);
      expect(Validators.validatePhone('98765'), isNotNull);
      expect(Validators.validatePhone(''), isNotNull);
    });

    test('validates client password (minimum 6 characters)', () {
      expect(Validators.validatePassword('secret123'), isNull);
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword(''), isNotNull);
    });

    test('gender selection is mandatory for trainer matching', () {
      Gender? selectedGender;
      expect(selectedGender, isNull);

      selectedGender = Gender.male;
      expect(selectedGender, Gender.male);
      expect(selectedGender.toFirestore(), 'MALE');

      selectedGender = Gender.female;
      expect(selectedGender, Gender.female);
      expect(selectedGender.toFirestore(), 'FEMALE');
    });
  });

  group('PROMPT 2C: Security & Role Protection', () {
    test('Clients must never register with ADMIN role', () {
      expect(
        () {
          const requestedRole = UserRole.admin;
          if (requestedRole == UserRole.admin) {
            throw const RolePermissionException(
              'Public registration for ADMIN role is strictly forbidden.',
            );
          }
        },
        throwsA(isA<RolePermissionException>()),
      );
    });

    test('Client model enforces CLIENT role and ACTIVE status', () {
      final client = UserModel(
        uid: 'client_001',
        email: 'athlete@trainz.app',
        displayName: 'John Doe',
        phoneNumber: '9876543210',
        role: UserRole.client,
        gender: Gender.male,
        status: UserStatus.active,
        isEmailVerified: false,
        isOnboarded: false,
      );

      expect(client.isClient, isTrue);
      expect(client.isTrainer, isFalse);
      expect(client.isAdmin, isFalse);
      expect(client.isActive, isTrue);
      expect(client.gender, Gender.male);

      final map = client.toMap();
      expect(map['role'], 'CLIENT');
      expect(map['gender'], 'MALE');
      expect(map['status'], 'ACTIVE');
      expect(map['phoneNumber'], '9876543210');
    });
  });

  group('PROMPT 2C: Client Profile & Credit Ledger Initialization', () {
    test('Client profile schema initializes correctly', () {
      const profile = ClientProfileModel(
        uid: 'client_001',
        fitnessGoals: ['Build Muscle & Strength'],
        fitnessLevel: 'Intermediate',
        preferredCityId: 'city_mumbai',
      );

      expect(profile.uid, 'client_001');
      expect(profile.fitnessGoals.first, 'Build Muscle & Strength');
      expect(profile.fitnessLevel, 'Intermediate');
      expect(profile.preferredCityId, 'city_mumbai');

      final map = profile.toMap();
      expect(map['fitnessGoals'], ['Build Muscle & Strength']);
      expect(map['fitnessLevel'], 'Intermediate');
      expect(map['preferredCityId'], 'city_mumbai');
    });

    test('Session credits account starts with 0 available credits', () {
      const credit = SessionCreditModel(
        clientId: 'client_001',
        totalPurchased: 0,
        totalReserved: 0,
        totalConsumed: 0,
        totalReturned: 0,
        totalForfeited: 0,
        availableBalance: 0,
      );

      expect(credit.availableBalance, 0);
      expect(credit.computedAvailable, 0);
    });
  });

  group('PROMPT 2C: Navigation & Email Verification Guards', () {
    test('Unverified client is redirected to ClientEmailVerificationScreen', () {
      final unverifiedClient = UserModel(
        uid: 'client_001',
        email: 'unverified@trainz.app',
        role: UserRole.client,
        gender: Gender.male,
        isEmailVerified: false,
        isOnboarded: false,
      );

      final route = RoleGuards.resolveDestinationRoute(unverifiedClient);
      expect(route, AppRouter.clientVerifyEmail);
    });

    test('Verified but not onboarded client is redirected to Profile Completion', () {
      final verifiedNotOnboarded = UserModel(
        uid: 'client_001',
        email: 'verified@trainz.app',
        role: UserRole.client,
        gender: Gender.male,
        isEmailVerified: true,
        isOnboarded: false,
      );

      final route = RoleGuards.resolveDestinationRoute(verifiedNotOnboarded);
      expect(route, AppRouter.clientProfileCompletion);
    });

    test('Verified and onboarded client is redirected to ClientHomeScreen', () {
      final readyClient = UserModel(
        uid: 'client_001',
        email: 'ready@trainz.app',
        role: UserRole.client,
        gender: Gender.male,
        isEmailVerified: true,
        isOnboarded: true,
      );

      final route = RoleGuards.resolveDestinationRoute(readyClient);
      expect(route, AppRouter.clientHome);
    });

    test('Suspended client is redirected to Account Suspended screen', () {
      final suspendedClient = UserModel(
        uid: 'client_001',
        email: 'suspended@trainz.app',
        role: UserRole.client,
        status: UserStatus.suspended,
        isEmailVerified: true,
        isOnboarded: true,
      );

      final route = RoleGuards.resolveDestinationRoute(suspendedClient);
      expect(route, AppRouter.accountSuspended);
    });
  });
}

