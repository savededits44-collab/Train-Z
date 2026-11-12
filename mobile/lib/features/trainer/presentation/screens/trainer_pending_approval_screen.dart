import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';
import 'trainer_approved_screen.dart';
import 'trainer_login_screen.dart';
import 'trainer_rejected_screen.dart';

class TrainerPendingApprovalScreen extends StatefulWidget {
  const TrainerPendingApprovalScreen({super.key});

  @override
  State<TrainerPendingApprovalScreen> createState() =>
      _TrainerPendingApprovalScreenState();
}

class _TrainerPendingApprovalScreenState
    extends State<TrainerPendingApprovalScreen> {
  final _trainerAuthController = TrainerAuthController();
  bool _isRefreshing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _trainerAuthController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
      _statusMessage = null;
    });

    final profile = await _trainerAuthController.refreshTrainerStatus();

    if (!mounted) return;
    setState(() => _isRefreshing = false);

    if (profile != null) {
      if (profile.verificationStatus == TrainerVerificationStatus.approved) {
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
      } else {
        setState(() {
          _statusMessage = 'Application is currently under Admin review. Status: PENDING.';
        });
      }
    }
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
    final profile = _trainerAuthController.currentTrainerProfile;
    final categoryName = profile?.category.displayName ?? 'Trainer';

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
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 40.0)),

              // Animated/Glowing Pending Icon Container
              Container(
                width: (84.0 * sf).clamp(72.0, 100.0),
                height: (84.0 * sf).clamp(72.0, 100.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 2.0,
                  ),
                ),
                child: const Icon(
                  Iconsax.clock,
                  color: Color(0xFFF57F17),
                  size: 42,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Under Admin Review.',
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
                'Every Trainer and Advanced Trainer account requires Admin verification before accessing platform coaching tools.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.5, 14.0),
                  color: kGrey,
                  height: 1.4,
                ),
              ),

              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

              // Status Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'REVIEW STATUS',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kGrey,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 12,
                                color: Color(0xFFE65100),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'PENDING APPROVAL',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildDetailRow('Applied Category', categoryName),
                    const Divider(height: 20),
                    _buildDetailRow('Security Policy', 'Strict Admin Approval Only'),
                    const Divider(height: 20),
                    _buildDetailRow(
                      'Access Permission',
                      'Restricted until Approved',
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 28.0)),

              // Security & Policy Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Iconsax.shield_security,
                      size: 20,
                      color: kDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Trainers cannot approve themselves or alter their own verification status. Advanced Trainer eligibility is verified separately via submitted credentials.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.5 * sf).clamp(10.5, 12.5),
                          color: const Color(0xFF424242),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              SizedBox(height: (h * 0.035 * sf).clamp(24.0, 36.0)),

              // Refresh Button
              AppPrimaryButton(
                label: 'Check Approval Status',
                loading: _isRefreshing,
                onTap: _refreshStatus,
              ),

              const SizedBox(height: 16),

              // Support Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.info_circle, size: 14, color: kGrey),
                  const SizedBox(width: 6),
                  Text(
                    'Need assistance? Contact trainers@trainz.app',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(10.5, 12.5),
                      color: kGrey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: kGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kDark,
          ),
        ),
      ],
    );
  }
}

