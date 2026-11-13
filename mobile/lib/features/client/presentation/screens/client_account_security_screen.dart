import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/client_settings_service.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_forgot_password_screen.dart';

class ClientAccountSecurityScreen extends StatefulWidget {
  final String clientId;
  final String userEmail;
  final bool isEmailVerified;

  const ClientAccountSecurityScreen({
    super.key,
    required this.clientId,
    required this.userEmail,
    required this.isEmailVerified,
  });

  @override
  State<ClientAccountSecurityScreen> createState() => _ClientAccountSecurityScreenState();
}

class _ClientAccountSecurityScreenState extends State<ClientAccountSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientSettingsService _settingsService = ClientSettingsService.instance;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  late bool _emailVerified;
  bool _isCheckingVerification = false;
  bool _isUpdatingPassword = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _emailVerified = widget.isEmailVerified;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResendVerification() async {
    try {
      await _settingsService.sendEmailVerification();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification link dispatched to ${widget.userEmail}.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _handleRefreshVerification() async {
    setState(() => _isCheckingVerification = true);
    try {
      final verified = await _settingsService.reloadAndCheckEmailVerified();
      if (!mounted) return;
      setState(() {
        _emailVerified = verified;
        _isCheckingVerification = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verified ? 'Email verified successfully!' : 'Email is not yet verified. Please click the link in your email.'),
          backgroundColor: verified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isCheckingVerification = false);
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isUpdatingPassword = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _settingsService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isUpdatingPassword = false;
        _successMessage = 'Password updated successfully. A security confirmation has been recorded.';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingPassword = false;
        _errorMessage = e.toString().replaceAll('TrainZException: ', '').replaceAll('SettingsException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context, _emailVerified != widget.isEmailVerified),
        ),
        title: Text(
          'Account & Security',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Email Verification Status Card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _emailVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _emailVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _emailVerified ? Icons.verified : Icons.warning_amber_rounded,
                          size: 20,
                          color: _emailVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _emailVerified ? 'Email Address Verified' : 'Email Not Verified',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (14.0 * sf).clamp(13.0, 15.5),
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.userEmail,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _emailVerified
                        ? 'Your registered email is verified. You will receive booking notifications, Razorpay receipts, and coach updates.'
                        : 'Please verify your email address to ensure prompt booking updates, coach arrivals, and account security.',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF4B5563)),
                  ),
                  if (!_emailVerified) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleResendVerification,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kDark),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Resend Email',
                              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12, color: kDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isCheckingVerification ? null : _handleRefreshVerification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDark,
                              foregroundColor: kLime,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: _isCheckingVerification
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kLime))
                                : const Text(
                                    'Check Status',
                                    style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12, color: kLime),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 2. Change Password Section ──
            Text(
              'CHANGE PASSWORD',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (11.0 * sf).clamp(10.0, 12.5),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Password
                    _buildFieldLabel('Current Password', sf),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      validator: (v) => (v == null || v.isEmpty) ? 'Please enter your current password.' : null,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                      decoration: _buildPasswordInputDecoration(
                        hint: 'Enter your existing password',
                        isObscured: _obscureCurrent,
                        onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // New Password
                    _buildFieldLabel('New Password', sf),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      validator: (v) => ClientSettingsService.validateNewPassword(v ?? ''),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                      decoration: _buildPasswordInputDecoration(
                        hint: 'At least 8 chars with uppercase, lowercase & digit',
                        isObscured: _obscureNew,
                        onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Confirm New Password
                    _buildFieldLabel('Confirm New Password', sf),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm your new password.';
                        if (v != _newPasswordController.text) return 'Passwords do not match.';
                        return null;
                      },
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                      decoration: _buildPasswordInputDecoration(
                        hint: 'Re-enter your new password',
                        isObscured: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Password Rules Hint
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Requirements:',
                            style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11, color: kDark),
                          ),
                          SizedBox(height: 4),
                          Text('• Minimum 8 characters in length', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280))),
                          Text('• At least one uppercase letter (A-Z)', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280))),
                          Text('• At least one lowercase letter (a-z)', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280))),
                          Text('• At least one number (0-9)', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUpdatingPassword ? null : _handleUpdatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDark,
                          foregroundColor: kLime,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isUpdatingPassword
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kLime))
                            : const Text(
                                'Update Password',
                                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 14, color: kLime),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Forgot Password Link
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientForgotPasswordScreen(initialEmail: widget.userEmail),
                    ),
                  );
                },
                child: const Text(
                  'Forgot your current password? Recover Account',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 3. Security Guarantee Banner ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.lock, size: 20, color: kDark),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero-Knowledge Credential Security',
                          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12, color: kDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'TRAIN Z never stores plaintext passwords in Firestore databases or local storage. All authentication is cryptographically salted and tokenized via Firebase Auth.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, double sf) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Syne',
          fontSize: (12.0 * sf).clamp(11.0, 13.0),
          fontWeight: FontWeight.w700,
          color: kDark,
        ),
      ),
    );
  }

  InputDecoration _buildPasswordInputDecoration({
    required String hint,
    required bool isObscured,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFA0A0A0)),
      prefixIcon: const Icon(Iconsax.key, size: 18, color: kDark),
      suffixIcon: IconButton(
        icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF6B7280)),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kDark, width: 1.5)),
    );
  }
}
