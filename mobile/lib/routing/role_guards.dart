import '../shared/models/user_model.dart';
import 'app_router.dart';

/// Role-based access control and navigation guard utility.
/// Enforces strict separation between Client, Trainer, and Admin areas.
class RoleGuards {
  RoleGuards._();

  /// Checks if user is authorized to access Client features
  static bool canAccessClient(UserModel? user) {
    if (user == null) return false;
    if (user.status == UserStatus.suspended) return false;
    return user.role == UserRole.client;
  }

  /// Checks if user is authorized to access Trainer features
  static bool canAccessTrainer(UserModel? user) {
    if (user == null) return false;
    if (user.status == UserStatus.suspended) return false;
    return user.role == UserRole.trainer;
  }

  /// Checks if user is authorized to access Admin features
  static bool canAccessAdmin(UserModel? user) {
    if (user == null) return false;
    if (user.status == UserStatus.suspended) return false;
    return user.role == UserRole.admin;
  }

  /// Evaluates user session and returns the appropriate destination route
  static String resolveDestinationRoute(UserModel? user) {
    if (user == null) {
      return AppRouter.login;
    }

    if (user.status == UserStatus.suspended) {
      return AppRouter.accountSuspended;
    }

    // Role not chosen yet
    if (user.role == null) {
      return AppRouter.roleSelection;
    }

    // Email verification check for Client
    if (user.role == UserRole.client && !user.isEmailVerified) {
      return AppRouter.clientVerifyEmail;
    }

    if (!user.isOnboarded) {
      return user.role == UserRole.trainer
          ? AppRouter.trainerOnboarding
          : AppRouter.clientProfileCompletion;
    }

    // Role-specific destinations
    switch (user.role!) {
      case UserRole.client:
        return AppRouter.clientHome;
      case UserRole.trainer:
        return AppRouter.trainerDashboard;
      case UserRole.admin:
        return AppRouter.adminDashboard;
    }
  }
}

