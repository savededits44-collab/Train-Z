import 'package:flutter/material.dart';
import '../features/client/client_feature.dart';
import '../features/trainer/trainer_feature.dart';
import '../services/auth_service.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/user_model.dart';
import '../screens/admin/admin_trainer_review_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding/client_onboarding.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/trainer_onboarding.dart';
import '../screens/signup_screen.dart';
import '../screens/trainer/trainer_availability_screen.dart';
import '../screens/trainer/trainer_certificates_screen.dart';
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
  static const String clientTrainerDetail = '/client/trainer-detail';
  static const String clientPackageSelection = '/client/package-selection';
  static const String clientBookingSchedule = '/client/booking-schedule';
  static const String clientBookingConfirmation = '/client/booking-confirmation';
  static const String clientPayment = '/client/payment';
  static const String clientPaymentStatus = '/client/payment-status';
  static const String clientPaymentReceipt = '/client/payment-receipt';
  static const String clientPaymentHistory = '/client/payment-history';
  static const String clientMyBookings = '/client/my-bookings';
  static const String clientBookingDetail = '/client/booking-detail';
  static const String clientChat = '/client/chat';
  static const String clientNotifications = '/client/notifications';
  static const String clientSettings = '/client/settings';
  static const String clientPersonalInfo = '/client/personal-info';
  static const String clientAccountSecurity = '/client/account-security';
  static const String clientAccountDeletion = '/client/account-deletion';
  static const String clientNotificationPreferences = '/client/notification-preferences';
  static const String clientPrivacySettings = '/client/privacy-settings';
  static const String clientHelpSupport = '/client/help-support';
  static const String clientSupportTickets = '/client/support-tickets';
  static const String clientSubmitTicket = '/client/submit-ticket';
  static const String clientSupportDetail = '/client/support-detail';
  static const String clientLegal = '/client/legal';

  // Dedicated Trainer Routes
  static const String trainerLogin = '/trainer/login';
  static const String trainerRegister = '/trainer/register';
  static const String trainerCategorySelection = '/trainer/category-selection';
  static const String trainerRegistrationSuccess = '/trainer/registration-success';
  static const String trainerVerifyEmail = '/trainer/verify-email';
  static const String trainerPendingApproval = '/trainer/pending-approval';
  static const String trainerApproved = '/trainer/approved';
  static const String trainerRejected = '/trainer/rejected';
  static const String trainerForgotPassword = '/trainer/forgot-password';
  static const String trainerCertificates = '/trainer/certificates';
  static const String trainerAvailability = '/trainer/availability';

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
      case clientHome:
        final initialTab = (settings.arguments is int)
            ? settings.arguments as int
            : (settings.arguments is Map ? (settings.arguments as Map)['initialTab'] as int? ?? 0 : 0);
        return MaterialPageRoute(builder: (_) => ClientHomeScreen(initialTab: initialTab));
      case trainerDashboard:
        if (AuthService.instance.currentRole == UserRole.client) {
          return MaterialPageRoute(builder: (_) => const ClientHomeScreen());
        }
        final trainerId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => TrainerDashboard(trainerId: trainerId),
        );

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
      case clientTrainerDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => TrainerDetailScreen(
            trainer: args['trainer'],
            clientGender: args['clientGender'],
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientPackageSelection:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPackageSelectionScreen(
            trainer: args['trainer'],
            clientGender: args['clientGender'],
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientBookingSchedule:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientBookingScheduleScreen(
            trainer: args['trainer'],
            plan: args['plan'],
            clientGender: args['clientGender'],
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientBookingConfirmation:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientBookingConfirmationScreen(
            booking: args['booking'],
            trainer: args['trainer'],
            plan: args['plan'],
          ),
        );
      case clientPayment:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPaymentScreen(
            plan: args['plan'],
            trainer: args['trainer'],
            booking: args['booking'],
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
            clientEmail: args['clientEmail'] ?? 'athlete@trainz.com',
            clientPhone: args['clientPhone'] ?? '+91 98201 54321',
          ),
        );
      case clientPaymentStatus:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPaymentStatusScreen(
            initialStatus: args['initialStatus'] ?? PaymentStatusType.success,
            payment: args['payment'],
            plan: args['plan'],
            trainer: args['trainer'],
            booking: args['booking'],
            errorMessage: args['errorMessage'],
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
            clientEmail: args['clientEmail'] ?? 'athlete@trainz.com',
            clientPhone: args['clientPhone'] ?? '+91 98201 54321',
          ),
        );
      case clientPaymentReceipt:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPaymentReceiptScreen(
            payment: args['payment'],
            trainer: args['trainer'],
            booking: args['booking'],
          ),
        );
      case clientPaymentHistory:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPaymentHistoryScreen(
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientMyBookings:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientMyBookingsScreen(
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientBookingDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientBookingDetailScreen(
            booking: args['booking'],
          ),
        );
      case clientNotifications:
        return MaterialPageRoute(
          builder: (_) => const ClientNotificationsScreen(),
        );
      case clientChat:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientChatScreen(
            conversation: args['conversation'],
          ),
        );
      case clientSettings:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientSettingsScreen(
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
            clientEmail: args['clientEmail'],
          ),
        );
      case clientPersonalInfo:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPersonalInfoScreen(
            clientId: args['clientId'] ?? '',
            userModel: args['userModel'],
            profileModel: args['profileModel'],
          ),
        );
      case clientAccountSecurity:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientAccountSecurityScreen(
            clientId: args['clientId'] ?? '',
            userEmail: args['userEmail'] ?? '',
            isEmailVerified: args['isEmailVerified'] ?? false,
          ),
        );
      case clientAccountDeletion:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientAccountDeletionScreen(
            clientId: args['clientId'] ?? '',
            clientEmail: args['clientEmail'] ?? '',
          ),
        );
      case clientNotificationPreferences:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientNotificationPreferencesScreen(
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientPrivacySettings:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientPrivacySettingsScreen(
            clientId: args['clientId'] ?? '',
          ),
        );
      case clientHelpSupport:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientHelpSupportScreen(
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
            clientEmail: args['clientEmail'],
          ),
        );
      case clientSupportTickets:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientSupportTicketsScreen(
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
            clientEmail: args['clientEmail'],
          ),
        );
      case clientSubmitTicket:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientSubmitTicketScreen(
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
            clientEmail: args['clientEmail'],
            initialBooking: args['initialBooking'],
          ),
        );
      case clientSupportDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientSupportDetailScreen(
            ticket: args['ticket'],
            clientId: args['clientId'] ?? '',
            clientName: args['clientName'] ?? 'TRAIN Z Athlete',
          ),
        );
      case clientLegal:
        final initialTab = (settings.arguments is int)
            ? settings.arguments as int
            : (settings.arguments is Map ? (settings.arguments as Map)['initialTabIndex'] as int? ?? 0 : 0);
        return MaterialPageRoute(
          builder: (_) => ClientLegalScreen(initialTabIndex: initialTab),
        );

      // Dedicated Trainer Routes
      case trainerLogin:
        return MaterialPageRoute(builder: (_) => const TrainerLoginScreen());
      case trainerRegister:
        return MaterialPageRoute(builder: (_) => const TrainerRegisterScreen());
      case trainerVerifyEmail:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => TrainerEmailVerificationScreen(email: email),
        );
      case trainerPendingApproval:
        return MaterialPageRoute(
          builder: (_) => const TrainerPendingApprovalScreen(),
        );
      case trainerApproved:
        final profile = settings.arguments as TrainerProfileModel?;
        return MaterialPageRoute(
          builder: (_) => profile != null
              ? TrainerApprovedScreen(profile: profile)
              : const TrainerDashboard(),
        );
      case trainerRejected:
        final profile = settings.arguments as TrainerProfileModel?;
        return MaterialPageRoute(
          builder: (_) => profile != null
              ? TrainerRejectedScreen(profile: profile)
              : const TrainerLoginScreen(),
        );
      case trainerForgotPassword:
        final email = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => TrainerForgotPasswordScreen(initialEmail: email),
        );
      case trainerCertificates:
        if (AuthService.instance.currentRole == UserRole.client) {
          return MaterialPageRoute(builder: (_) => const ClientHomeScreen());
        }
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => TrainerCertificatesScreen(
            trainerId: args?['trainerId'],
            category: args?['category'],
          ),
        );
      case trainerAvailability:
        if (AuthService.instance.currentRole == UserRole.client) {
          return MaterialPageRoute(builder: (_) => const ClientHomeScreen());
        }
        final args = settings.arguments as Map<String, dynamic>?;
        final trainerId = args?['trainerId'] as String? ?? (settings.arguments is String ? settings.arguments as String : null);
        return MaterialPageRoute(
          builder: (_) => TrainerAvailabilityScreen(
            trainerId: trainerId,
          ),
        );

      case adminDashboard:
        if (AuthService.instance.currentRole == UserRole.client) {
          return MaterialPageRoute(builder: (_) => const ClientHomeScreen());
        }
        return MaterialPageRoute(builder: (_) => const AdminTrainerReviewScreen());

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
