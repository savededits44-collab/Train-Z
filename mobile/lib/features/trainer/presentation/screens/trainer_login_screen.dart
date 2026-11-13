import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../screens/trainer/trainer_dashboard.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';
import 'trainer_category_selection_screen.dart';
import 'trainer_email_verification_screen.dart';
import 'trainer_forgot_password_screen.dart';
import 'trainer_pending_approval_screen.dart';
import 'trainer_register_screen.dart';
import 'trainer_rejected_screen.dart';

class TrainerLoginScreen extends StatefulWidget {
  const TrainerLoginScreen({super.key});

  @override
  State<TrainerLoginScreen> createState() => _TrainerLoginScreenState();
}

class _TrainerLoginScreenState extends State<TrainerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _trainerAuthController = TrainerAuthController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _trainerAuthController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _inlineError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _inlineError = 'Please enter your registered email address.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _inlineError = 'Please enter your password.');
      return;
    }

    setState(() => _isLoading = true);

    final target = await _trainerAuthController.loginTrainer(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (target != null) {
      switch (target) {
        case TrainerAuthNavigationTarget.verifyEmail:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TrainerEmailVerificationScreen(email: email),
            ),
          );
          break;

        case TrainerAuthNavigationTarget.categorySelection:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TrainerCategorySelectionScreen(
                fullName: _trainerAuthController.currentTrainerUser?.displayName ?? 'Trainer',
                email: email,
                phoneNumber: _trainerAuthController.currentTrainerUser?.phoneNumber ?? '',
                password: '',
                confirmPassword: '',
              ),
            ),
          );
          break;

        case TrainerAuthNavigationTarget.pendingApproval:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const TrainerPendingApprovalScreen(),
            ),
          );
          break;

        case TrainerAuthNavigationTarget.approved:
          final profile = _trainerAuthController.currentTrainerProfile;
          final uid = profile?.uid ?? _trainerAuthController.currentTrainerUser?.uid;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TrainerDashboard(trainerId: uid),
            ),
          );
          break;

        case TrainerAuthNavigationTarget.rejected:
          final profile = _trainerAuthController.currentTrainerProfile;
          if (profile != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TrainerRejectedScreen(profile: profile),
              ),
            );
          }
          break;

        case TrainerAuthNavigationTarget.suspended:
          setState(() {
            _inlineError = 'Your trainer account is suspended. Contact support@trainz.app.';
          });
          break;
      }
    } else {
      setState(() {
        _inlineError = _trainerAuthController.errorMessage ??
            'Login failed. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AppLogo(fontSize: 16),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.02 * sf).clamp(12.0, 24.0)),

              // Badge: Trainer Portal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TRAINER PORTAL LOGIN',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kLime,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Welcome Back,\nCoach.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (30.0 * sf).clamp(24.0, 36.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Log in to manage your bookings, schedule availability & client progress.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.5, 14.0),
                  color: kGrey,
                  height: 1.35,
                ),
              ),

              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

              if (_inlineError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Iconsax.warning_2,
                        color: Color(0xFFD32F2F),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Email Field
              AppTextField(
                controller: _emailController,
                label: 'Trainer Email Address',
                icon: Iconsax.sms,
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: (14.0 * sf).clamp(10.0, 18.0)),

              // Password Field
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Iconsax.lock,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                    size: 18,
                    color: kGrey,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 8),

              // Forgot Password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 30.0)),

              // Login Button
              AppPrimaryButton(
                label: 'Log In to Trainer Portal',
                loading: _isLoading,
                onTap: _handleLogin,
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 38.0)),

              // Register Link
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "New trainer? ",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (13.0 * sf).clamp(11.5, 14.0),
                        color: kGrey,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const TrainerRegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Apply to Join',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (13.0 * sf).clamp(11.5, 14.0),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

