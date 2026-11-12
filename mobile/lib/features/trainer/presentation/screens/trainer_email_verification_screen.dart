import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';
import 'trainer_approved_screen.dart';
import 'trainer_login_screen.dart';
import 'trainer_pending_approval_screen.dart';
import 'trainer_rejected_screen.dart';

class TrainerEmailVerificationScreen extends StatefulWidget {
  final String email;

  const TrainerEmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<TrainerEmailVerificationScreen> createState() =>
      _TrainerEmailVerificationScreenState();
}

class _TrainerEmailVerificationScreenState
    extends State<TrainerEmailVerificationScreen> {
  final _trainerAuthController = TrainerAuthController();

  bool _isChecking = false;
  bool _isResending = false;
  String? _statusMessage;
  bool _isSuccessMessage = false;

  @override
  void dispose() {
    _trainerAuthController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckVerification() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    final verified = await _trainerAuthController.checkEmailVerification();

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (verified) {
      final profile = await _trainerAuthController.refreshTrainerStatus();
      if (!mounted) return;

      if (profile == null || profile.verificationStatus == TrainerVerificationStatus.pending) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const TrainerPendingApprovalScreen(),
          ),
        );
      } else if (profile.verificationStatus == TrainerVerificationStatus.approved) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TrainerApprovedScreen(profile: profile),
          ),
        );
      } else if (profile.verificationStatus == TrainerVerificationStatus.rejected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TrainerRejectedScreen(profile: profile),
          ),
        );
      }
    } else {
      setState(() {
        _statusMessage =
            'Email not yet verified. Please tap the verification link in your inbox and try again.';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _handleResendEmail() async {
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });

    final sent = await _trainerAuthController.resendVerificationEmail();

    if (!mounted) return;
    setState(() {
      _isResending = false;
      if (sent) {
        _statusMessage = 'A new verification link has been sent to ${widget.email}.';
        _isSuccessMessage = true;
      } else {
        _statusMessage =
            _trainerAuthController.errorMessage ?? 'Failed to resend verification email.';
        _isSuccessMessage = false;
      }
    });
  }

  Future<void> _handleSignOut() async {
    await _trainerAuthController.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TrainerLoginScreen()),
      (route) => false,
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
        actions: [
          TextButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Iconsax.logout, size: 16, color: kGrey),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: kGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: (h * 0.04 * sf).clamp(20.0, 50.0)),

              // Email Icon Container
              Container(
                width: (80.0 * sf).clamp(70.0, 96.0),
                height: (80.0 * sf).clamp(70.0, 96.0),
                decoration: BoxDecoration(
                  color: kField,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(
                  Iconsax.sms_tracking,
                  color: kDark,
                  size: 38,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Verify Your Email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (26.0 * sf).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'We have sent an authentication link to:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(12.0, 14.0),
                  color: kGrey,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (14.0 * sf).clamp(12.5, 15.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 36.0)),

              if (_statusMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _isSuccessMessage
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccessMessage
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFFCDD2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccessMessage ? Iconsax.tick_circle : Iconsax.warning_2,
                        color: _isSuccessMessage
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD32F2F),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _isSuccessMessage
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFD32F2F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. I've Verified My Email Button
              AppPrimaryButton(
                label: "I've Verified My Email",
                loading: _isChecking,
                onTap: _handleCheckVerification,
              ),

              const SizedBox(height: 14),

              // 2. Resend Email Button
              SizedBox(
                width: double.infinity,
                height: (54.0 * sf).clamp(48.0, 60.0),
                child: OutlinedButton(
                  onPressed: _isResending ? null : _handleResendEmail,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kDark, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kDark,
                          ),
                        )
                      : const Text(
                          'Resend Verification Email',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kDark,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Trainer accounts must maintain a verified email address for account security and administrative notices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (11.5 * sf).clamp(10.5, 12.5),
                  color: kGrey,
                  height: 1.4,
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

