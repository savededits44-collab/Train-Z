import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';

class TrainerForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const TrainerForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  @override
  State<TrainerForgotPasswordScreen> createState() =>
      _TrainerForgotPasswordScreenState();
}

class _TrainerForgotPasswordScreenState
    extends State<TrainerForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final _trainerAuthController = TrainerAuthController();

  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _trainerAuthController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _statusMessage = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your registered trainer email.';
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final sent = await _trainerAuthController.sendPasswordReset(email);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (sent) {
        _isSuccess = true;
        _statusMessage =
            'A password reset link has been dispatched to $email. Please check your inbox.';
      } else {
        _isSuccess = false;
        _statusMessage = _trainerAuthController.errorMessage ??
            'Failed to dispatch reset email. Please try again.';
      }
    });
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
              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 36.0)),

              Text(
                'Reset Trainer Password.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (26.0 * sf).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter the email associated with your trainer account and we will send instructions to securely reset your password.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.5, 14.0),
                  color: kGrey,
                  height: 1.35,
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

              if (_statusMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFFCDD2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Iconsax.tick_circle : Iconsax.warning_2,
                        color: _isSuccess
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
                            color: _isSuccess
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

              AppTextField(
                controller: _emailController,
                label: 'Trainer Email Address',
                icon: Iconsax.sms,
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

              AppPrimaryButton(
                label: 'Send Reset Link',
                loading: _isLoading,
                onTap: _handleResetPassword,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

