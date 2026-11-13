import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/auth_service.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);
const Color _kSuccess = Color(0xFF10B981);
const Color _kWarning = Color(0xFFF59E0B);

/// Dedicated Account & Security Management Screen for Trainers.
/// Manages passwords, email verification, and reauthentication via Firebase Authentication.
class TrainerAccountSecurityScreen extends StatefulWidget {
  const TrainerAccountSecurityScreen({super.key});

  @override
  State<TrainerAccountSecurityScreen> createState() =>
      _TrainerAccountSecurityScreenState();
}

class _TrainerAccountSecurityScreenState
    extends State<TrainerAccountSecurityScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPassword = false;
  bool _isCheckingVerification = false;
  bool _isSendingReset = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    setState(() => _isCheckingVerification = true);
    HapticFeedback.lightImpact();

    try {
      final verified = await _authService.reloadAndCheckEmailVerification();
      if (!mounted) return;
      setState(() => _isCheckingVerification = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Email verified successfully!'
                : 'Email is still unverified. Please check your inbox.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: verified ? _kSuccess : _kCardSubBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingVerification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification link sent to your email address.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: _kCardSubBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _authService.currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered email found.')),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: _kCardSubBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    HapticFeedback.lightImpact();

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordCtrl.text.trim(),
        newPassword: _newPasswordCtrl.text.trim(),
      );

      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();

      if (!mounted) return;
      setState(() => _isChangingPassword = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password changed successfully',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChangingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isEmailVerified = user?.emailVerified ?? false;
    final isGoogleAuth = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Account & Security',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Email Verification Status Card ─────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Iconsax.sms, color: _kLime, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isEmailVerified ? _kSuccess : _kWarning).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isEmailVerified ? _kSuccess : _kWarning).withAlpha(100),
                        ),
                      ),
                      child: Text(
                        isEmailVerified ? 'VERIFIED' : 'UNVERIFIED',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isEmailVerified ? _kSuccess : _kWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? 'No email linked',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                if (!isEmailVerified) ...[
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kLime,
                          foregroundColor: _kDark,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontFamily: 'Syne', fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _sendVerificationEmail,
                        icon: const Icon(Iconsax.send_1, size: 14),
                        label: const Text('Resend Link'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontFamily: 'Syne', fontSize: 12),
                        ),
                        onPressed: _isCheckingVerification ? null : _checkEmailVerification,
                        icon: _isCheckingVerification
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: const Text('Check Status'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 2. Password Management Card ───────────────────
          if (isGoogleAuth) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.g_mobiledata, color: _kLime, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your account is secured via Google OAuth. Password changes are managed through Google Security.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _kGrey),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Iconsax.lock, color: _kLime, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Passwords are encrypted and authenticated directly with Firebase Authentication.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kGrey),
                    ),
                    const SizedBox(height: 16),

                    // Current Password
                    _buildPasswordField(
                      controller: _currentPasswordCtrl,
                      label: 'Current Password',
                      obscure: _obscureCurrent,
                      onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your current password';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // New Password
                    _buildPasswordField(
                      controller: _newPasswordCtrl,
                      label: 'New Password',
                      obscure: _obscureNew,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Confirm Password
                    _buildPasswordField(
                      controller: _confirmPasswordCtrl,
                      label: 'Confirm New Password',
                      obscure: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v != _newPasswordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kLime,
                          foregroundColor: _kDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isChangingPassword ? null : _changePassword,
                        child: _isChangingPassword
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: _kDark, strokeWidth: 2),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: TextButton(
                        onPressed: _isSendingReset ? null : _sendPasswordReset,
                        child: Text(
                          _isSendingReset ? 'Sending reset link...' : 'Forgot current password?',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _kGrey,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── 3. Session & Security Info ───────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.shield_tick, color: _kLime, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Session & Data Protection',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Passwords are never stored in plain text or Firestore.\n• Sensitive account modifications require reauthentication.\n• All active sessions are token-verified and encrypted via TLS.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _kGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Poppins', fontSize: 13),
        filled: true,
        fillColor: _kCardSubBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Iconsax.eye_slash : Iconsax.eye,
            color: _kGrey,
            size: 18,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kLime),
        ),
      ),
      validator: validator,
    );
  }
}
