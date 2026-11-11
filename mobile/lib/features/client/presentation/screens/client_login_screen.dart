import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/client_auth_controller.dart';
import 'client_email_verification_screen.dart';
import 'client_forgot_password_screen.dart';
import 'client_home_screen.dart';
import 'client_profile_setup_screen.dart';
import 'client_register_screen.dart';

/// Premium Login Screen specifically tailored for TRAIN Z Clients.
class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ClientAuthController _authController = ClientAuthController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authController.addListener(_onAuthControllerUpdate);
  }

  void _onAuthControllerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthControllerUpdate);
    _authController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    final target = await _authController.loginClient(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (target != null) {
      HapticFeedback.mediumImpact();
      switch (target) {
        case ClientAuthNavigationTarget.verifyEmail:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ClientEmailVerificationScreen(
                email: _emailController.text.trim(),
              ),
            ),
          );
          break;
        case ClientAuthNavigationTarget.profileCompletion:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ClientProfileSetupScreen(),
            ),
          );
          break;
        case ClientAuthNavigationTarget.clientHome:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ClientHomeScreen(),
            ),
          );
          break;
      }
    } else if (_authController.errorMessage != null) {
      HapticFeedback.heavyImpact();
      _showToast(_authController.errorMessage!);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
          icon: const Icon(Iconsax.arrow_left, color: kDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const AppLogo(fontSize: 16),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.02 * sf).clamp(12.0, 24.0)),

              // Role Identifier Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Client Portal',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (11.0 * sf).clamp(10.0, 12.5),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Welcome\nback.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (32.0 * sf).clamp(26.0, 40.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Sign in to book sessions, review your trainer schedule & track workouts.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.5 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                  height: 1.4,
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

              // Email Address
              AppTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Iconsax.sms,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // Password
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Iconsax.lock,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                    size: (18.0 * sf).clamp(16.0, 22.0),
                    color: const Color(0xFFAAAAAA),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 12),

              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClientForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (12.0 * sf).clamp(11.0, 13.5),
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                ),
              ),

              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

              // Primary Login Button
              AppPrimaryButton(
                label: 'Log In as Client',
                loading: _authController.isLoading,
                onTap: _handleLogin,
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(18.0, 30.0)),

              // Or divider
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.0 * sf).clamp(10.0, 12.5),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFBBBBBB),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                ],
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(18.0, 30.0)),

              // Google Sign In Button
              _GoogleSignInButton(
                onTap: () async {
                  await _authController.loginClient(
                    email: _emailController.text,
                    password: _passwordController.text,
                  );
                },
              ),

              const SizedBox(height: 24),

              // Sign Up Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (13.0 * sf).clamp(11.0, 14.5),
                        color: kGrey,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const ClientRegisterScreen()),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (13.0 * sf).clamp(11.0, 14.5),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final h = MediaQuery.of(context).size.height;
    final btnH = (h * 0.062 * sf).clamp(44.0, 58.0);
    final radius = (13.0 * sf).clamp(10.0, 16.0);

    return SizedBox(
      width: double.infinity,
      height: btnH,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E5E5), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GoogleLogo(size: 20),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (13.0 * sf).clamp(12.0, 15.0),
                fontWeight: FontWeight.w600,
                color: kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
