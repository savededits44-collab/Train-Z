import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/client_auth_controller.dart';

/// Password recovery screen for TRAIN Z Clients.
class ClientForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ClientForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  @override
  State<ClientForgotPasswordScreen> createState() =>
      _ClientForgotPasswordScreenState();
}

class _ClientForgotPasswordScreenState
    extends State<ClientForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final ClientAuthController _authController = ClientAuthController();
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
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
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    FocusScope.of(context).unfocus();

    final sent = await _authController.sendPasswordReset(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    if (sent) {
      HapticFeedback.mediumImpact();
      setState(() => _emailSent = true);
    } else if (_authController.errorMessage != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authController.errorMessage!,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E1E24),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
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
          icon: const Icon(Iconsax.arrow_left, color: kDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const AppLogo(fontSize: 16),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.02 * sf).clamp(12.0, 24.0)),

              if (!_emailSent) ...[
                Text(
                  'Recover\npassword.',
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
                  'Enter your registered email address and we will dispatch a secure password reset link to your inbox.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.5 * sf).clamp(11.0, 14.0),
                    color: kGrey,
                    height: 1.45,
                  ),
                ),

                SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Iconsax.sms,
                  keyboardType: TextInputType.emailAddress,
                ),

                SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

                AppPrimaryButton(
                  label: 'Send Recovery Link',
                  loading: _authController.isLoading,
                  onTap: _handleSendReset,
                ),
              ] else ...[
                const Spacer(flex: 2),

                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.direct_send,
                      size: 40,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Recovery Link Sent!',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (24.0 * sf).clamp(20.0, 28.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    'We sent password reset instructions to:\n${_emailController.text.trim()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (13.0 * sf).clamp(11.5, 14.5),
                      color: kGrey,
                      height: 1.5,
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                AppPrimaryButton(
                  label: 'Back to Login',
                  onTap: () => Navigator.of(context).maybePop(),
                ),

                const Spacer(flex: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

