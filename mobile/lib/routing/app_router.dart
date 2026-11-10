import 'package:flutter/material.dart';
import '../features/client/client_feature.dart';
import '../screens/client/client_dashboard.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding/client_onboarding.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/trainer_onboarding.dart';
import '../screens/signup_screen.dart';
import '../screens/trainer/trainer_dashboard.dart';
import '../screens/welcome_screen.dart';
import '../splashscreen/splashscreen.dart';

/// Centralized named route definitions for TRAIN Z.
class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String roleSelection = '/role-selection';
  static const String clientOnboarding = '/client/onboarding';
  static const String trainerOnboarding = '/trainer/onboarding';
  static const String clientDashboard = '/client/dashboard';
  static const String trainerDashboard = '/trainer/dashboard';
  static const String adminDashboard = '/admin/dashboard';
  static const String accountSuspended = '/account-suspended';

  // Dedicated Client Routes (Prompt 2C & Profile Setup)
  static const String clientLogin = '/client/login';
  static const String clientRegister = '/client/register';
  static const String clientVerifyEmail = '/client/verify-email';
  static const String clientForgotPassword = '/client/forgot-password';
  static const String clientProfileCompletion = '/client/profile-completion';
  static const String clientProfileSetup = '/client/profile-setup';
  static const String clientHome = '/client/home';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());
      case clientOnboarding:
        return MaterialPageRoute(builder: (_) => const ClientOnboardingScreen());
      case trainerOnboarding:
        return MaterialPageRoute(builder: (_) => const TrainerOnboardingScreen());
      case clientDashboard:
        return MaterialPageRoute(builder: (_) => const ClientDashboard());
      case trainerDashboard:
        return MaterialPageRoute(builder: (_) => const TrainerDashboard());

      // Client Feature Routes
      case clientLogin:
        return MaterialPageRoute(builder: (_) => const ClientLoginScreen());
      case clientRegister:
        return MaterialPageRoute(builder: (_) => const ClientRegisterScreen());
      case clientVerifyEmail:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => ClientEmailVerificationScreen(email: email),
        );
      case clientForgotPassword:
        final email = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => ClientForgotPasswordScreen(initialEmail: email),
        );
      case clientProfileCompletion:
      case clientProfileSetup:
        final isEditMode = (settings.arguments as bool?) ?? false;
        return MaterialPageRoute(
          builder: (_) => ClientProfileSetupScreen(isEditMode: isEditMode),
        );
      case clientHome:
        return MaterialPageRoute(builder: (_) => const ClientHomeScreen());

      case accountSuspended:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.block, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Account Suspended',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your account has been suspended by administration. Please contact support@trainz.app.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
