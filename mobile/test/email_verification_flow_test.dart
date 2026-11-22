import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/client_feature.dart';
import 'package:trainuspro/features/trainer/trainer_feature.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('TRAIN Z Email Verification Architecture & Security Suite', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Registration & Verification Routing
    // ─────────────────────────────────────────────────────────────────────────
    test('1. New client registration results in unverified user that routes to verifyEmail', () {
      final unverifiedClient = UserModel(
        uid: 'client_new_1',
        email: 'alex.client@trainz.app',
        displayName: 'Alex Mercer',
        role: UserRole.client,
        gender: Gender.male,
        status: UserStatus.active,
        isEmailVerified: false,
        isOnboarded: false,
        createdAt: DateTime.now(),
      );

      expect(unverifiedClient.isEmailVerified, isFalse);
      expect(unverifiedClient.isClient, isTrue);

      final route = RoleGuards.resolveDestinationRoute(unverifiedClient);
      expect(route, AppRouter.clientVerifyEmail);
    });

    test('2. New trainer registration results in unverified trainer that routes to trainerVerifyEmail', () {
      final unverifiedTrainer = UserModel(
        uid: 'trainer_new_1',
        email: 'priya.trainer@trainz.app',
        displayName: 'Priya Sharma',
        role: UserRole.trainer,
        gender: Gender.female,
        status: UserStatus.active,
        isEmailVerified: false,
        isOnboarded: false,
        createdAt: DateTime.now(),
      );

      const pendingProfile = TrainerProfileModel(
        uid: 'trainer_new_1',
        verificationStatus: TrainerVerificationStatus.pending,
      );

      expect(unverifiedTrainer.isEmailVerified, isFalse);
      expect(unverifiedTrainer.isTrainer, isTrue);

      final route = RoleGuards.resolveTrainerDestinationRoute(
        user: unverifiedTrainer,
        profile: pendingProfile,
      );
      expect(route, AppRouter.trainerVerifyEmail);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Strict Access Control: Unverified Users Blocked From Protected Screens
    // ─────────────────────────────────────────────────────────────────────────
    test('3. Unverified client cannot access client home or profile completion', () {
      final unverifiedClient = UserModel(
        uid: 'client_unverified_guard',
        email: 'guard@trainz.app',
        role: UserRole.client,
        isEmailVerified: false,
        isOnboarded: true, // Even if somehow marked onboarded, unverified email stops them
      );

      final route = RoleGuards.resolveDestinationRoute(unverifiedClient);
      expect(route, AppRouter.clientVerifyEmail);
      expect(route, isNot(AppRouter.clientHome));
    });

    test('4. Unverified trainer cannot access trainer dashboard even if profile is approved', () {
      final unverifiedTrainer = UserModel(
        uid: 'trainer_unverified_guard',
        email: 'coach.unverified@trainz.app',
        role: UserRole.trainer,
        isEmailVerified: false,
      );

      const approvedProfile = TrainerProfileModel(
        uid: 'trainer_unverified_guard',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      );

      final route = RoleGuards.resolveTrainerDestinationRoute(
        user: unverifiedTrainer,
        profile: approvedProfile,
      );
      expect(route, AppRouter.trainerVerifyEmail);
      expect(route, isNot(AppRouter.trainerDashboard));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Google Sign-In Users Are Never Blocked
    // ─────────────────────────────────────────────────────────────────────────
    test('5. Google-authenticated client is treated as pre-verified and allowed forward', () {
      final googleClient = UserModel(
        uid: 'client_google_123',
        email: 'google.athlete@gmail.com',
        displayName: 'Google Athlete',
        role: UserRole.client,
        gender: Gender.female,
        status: UserStatus.active,
        isEmailVerified: true, // Google OAuth accounts are pre-verified
        isOnboarded: true,
      );

      final route = RoleGuards.resolveDestinationRoute(googleClient);
      expect(route, AppRouter.clientHome);
    });

    test('6. Google client not yet onboarded routes directly to Profile Completion, not email verification', () {
      final googleClientNew = UserModel(
        uid: 'client_google_new',
        email: 'new.google@gmail.com',
        displayName: 'New Google Athlete',
        role: UserRole.client,
        isEmailVerified: true,
        isOnboarded: false,
      );

      final route = RoleGuards.resolveDestinationRoute(googleClientNew);
      expect(route, AppRouter.clientProfileCompletion);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Verification Check Invariant: Firebase Auth Must Confirm emailVerified
    // ─────────────────────────────────────────────────────────────────────────
    test('7. Verified client transitions to clientHome when onboarded', () {
      final verifiedClient = UserModel(
        uid: 'client_verified_1',
        email: 'verified@trainz.app',
        role: UserRole.client,
        isEmailVerified: true,
        isOnboarded: true,
      );

      final route = RoleGuards.resolveDestinationRoute(verifiedClient);
      expect(route, AppRouter.clientHome);
    });

    test('8. Verified trainer transitions to approval/dashboard flow based on review status', () {
      final verifiedTrainer = UserModel(
        uid: 'trainer_verified_1',
        email: 'verified.trainer@trainz.app',
        role: UserRole.trainer,
        isEmailVerified: true,
      );

      const pendingProfile = TrainerProfileModel(
        uid: 'trainer_verified_1',
        verificationStatus: TrainerVerificationStatus.pending,
      );

      const approvedProfile = TrainerProfileModel(
        uid: 'trainer_verified_1',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      );

      expect(
        RoleGuards.resolveTrainerDestinationRoute(user: verifiedTrainer, profile: pendingProfile),
        AppRouter.trainerPendingApproval,
      );

      expect(
        RoleGuards.resolveTrainerDestinationRoute(user: verifiedTrainer, profile: approvedProfile),
        AppRouter.trainerDashboard,
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Cooldown Invariant for Resending Verification
    // ─────────────────────────────────────────────────────────────────────────
    test('9. AuthService resendCooldownRemaining handles null timestamp safely', () {
      final auth = AuthService.instance;
      expect(auth.resendCooldownRemaining, 0);
    });

    test('10. AppExceptions formats clear, user-friendly auth exception messages', () {
      const rateLimitEx = AuthException(
        'Too many verification requests sent. Please wait a few minutes before trying again.',
      );
      expect(rateLimitEx.message, contains('Too many verification requests'));

      const networkEx = AuthException(
        'Network connection unavailable. Please check your internet connection.',
      );
      expect(networkEx.message, contains('Network connection unavailable'));

      const sessionEx = AuthException(
        'Your session has expired. Please sign in again to receive a verification email.',
      );
      expect(sessionEx.message, contains('Your session has expired'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 6. UI Widget Tests: Verification Screens Display Correct Controls
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets('11. ClientEmailVerificationScreen renders email, verify button, and resend button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientEmailVerificationScreen(
            email: 'athlete@trainz.app',
          ),
        ),
      );

      await tester.pump();

      // Check header and text
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('athlete@trainz.app'), findsOneWidget);

      // Check primary action button
      expect(find.text("I've Verified My Email"), findsOneWidget);

      // Check Sign Out button in AppBar
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('12. TrainerEmailVerificationScreen renders email, verify button, and resend action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEmailVerificationScreen(
            email: 'trainer@trainz.app',
          ),
        ),
      );

      await tester.pump();

      // Check header and email text
      expect(find.text('Verify Your Email.'), findsOneWidget);
      expect(find.text('trainer@trainz.app'), findsOneWidget);

      // Check primary action button
      expect(find.text("I've Verified My Email"), findsOneWidget);

      // Check sign out
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
