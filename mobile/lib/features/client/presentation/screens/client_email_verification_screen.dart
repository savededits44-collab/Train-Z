import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/client_auth_controller.dart';
import 'client_home_screen.dart';
import 'client_login_screen.dart';
import 'client_profile_completion_screen.dart';

/// Screen requiring the client to verify their email address before accessing protected trainer features.
class ClientEmailVerificationScreen extends StatefulWidget {
  final String email;

  const ClientEmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<ClientEmailVerificationScreen> createState() =>
      _ClientEmailVerificationScreenState();
}

class _ClientEmailVerificationScreenState
    extends State<ClientEmailVerificationScreen> {
  final ClientAuthController _authController = ClientAuthController();

  int _resendCooldown = 0;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    final verified = await _authController.checkEmailVerification();
    setState(() => _checking = false);

    if (!mounted) return;

    if (verified) {
      HapticFeedback.mediumImpact();
      _showToast('Email verified successfully! Welcome to TrainZ.');

      // Check onboarding state
      final client = _authController.currentClient;
      final bool isOnboarded = client?.isOnboarded ?? false;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isOnboarded
              ? const ClientHomeScreen()
              : const ClientProfileCompletionScreen(),
        ),
      );
    } else {
      HapticFeedback.selectionClick();
      _showToast(
        'Email not verified yet. Please check your inbox (including spam folder) or tap Resend.',
      );
    }
  }

  Future<void> _resendLink() async {
    if (_resendCooldown > 0) return;
    HapticFeedback.lightImpact();

    final sent = await _authController.resendVerificationEmail();
    if (!mounted) return;

    if (sent) {
      _startCooldown();
      _showToast('Verification email resent! Please check your inbox.');
    } else {
      _showToast(_authController.errorMessage ?? 'Unable to resend email.');
    }
  }

  Future<void> _handleSignOut() async {
    await _authController.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
    );
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
    final hPad = (w * 0.08).clamp(20.0, 36.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Iconsax.logout, size: 16, color: kDark),
            label: Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.0 * sf).clamp(11.0, 13.5),
                fontWeight: FontWeight.w600,
                color: kDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated Mail Envelope Badge
              Container(
                width: (88.0 * sf).clamp(72.0, 104.0),
                height: (88.0 * sf).clamp(72.0, 104.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Iconsax.sms_tracking,
                      size: (40.0 * sf).clamp(32.0, 48.0),
                      color: kDark,
                    ),
                    Positioned(
                      right: 18,
                      bottom: 18,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: kLime,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (26.0 * sf).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'We have dispatched a verification link to:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.5 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                ),
              ),

              const SizedBox(height: 10),

              // Email Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.verify, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (13.0 * sf).clamp(11.5, 14.5),
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Please click the link in your email to activate your account. You can return here immediately after verifying.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.0 * sf).clamp(11.0, 13.5),
                  color: const Color(0xFF777777),
                  height: 1.45,
                ),
              ),

              const Spacer(flex: 3),

              // Check Verification Button
              AppPrimaryButton(
                label: "I've Verified My Email",
                loading: _checking,
                onTap: _checkVerification,
              ),

              const SizedBox(height: 14),

              // Resend Button
              TextButton(
                onPressed: _resendCooldown > 0 ? null : _resendLink,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend link in ${_resendCooldown}s'
                      : 'Resend Verification Link',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (13.0 * sf).clamp(11.5, 14.5),
                    fontWeight: FontWeight.w600,
                    color: _resendCooldown > 0 ? kGrey : kDark,
                    decoration: _resendCooldown > 0 ? null : TextDecoration.underline,
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
