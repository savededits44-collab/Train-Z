import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/client_settings_service.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_login_screen.dart';

const Color kDanger = Color(0xFFDC2626);

class ClientAccountDeletionScreen extends StatefulWidget {
  final String clientId;
  final String clientEmail;

  const ClientAccountDeletionScreen({
    super.key,
    required this.clientId,
    required this.clientEmail,
  });

  @override
  State<ClientAccountDeletionScreen> createState() =>
      _ClientAccountDeletionScreenState();
}

class _ClientAccountDeletionScreenState
    extends State<ClientAccountDeletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientSettingsService _settingsService = ClientSettingsService.instance;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmTextController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _obscurePassword = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmTextController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isConfirmationValid =>
      _confirmTextController.text.trim().toUpperCase() == 'DELETE';

  Future<void> _handleDeleteAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isConfirmationValid) {
      setState(() {
        _errorMessage = 'Please type "DELETE" in the confirmation field to proceed.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Final Confirmation',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kDanger, fontSize: 18),
        ),
        content: const Text(
          'This action cannot be undone. Your active sessions will be cancelled, your credentials deleted, and personal files erased.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Account', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Yes, Delete', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await _settingsService.requestAccountDeletion(
        uid: widget.clientId,
        currentPassword: _passwordController.text,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Account Deleted', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kDark, fontSize: 18)),
          content: const Text(
            'Your account and personal data have been removed. Thank you for being a part of TRAIN Z.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF4B5563)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: kDark, foregroundColor: Colors.white),
              child: const Text('Continue', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDanger,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Danger Callout Banner ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: kDanger, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Irreversible Account Action',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w800,
                              fontSize: (14.0 * sf).clamp(13.0, 15.5),
                              color: kDanger,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Deleting your account permanently revokes your access to TRAIN Z and purges your profile data.',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF7F1D1D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── 2. What Happens Summary ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens when you delete your account:',
                      style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: kDark),
                    ),
                    SizedBox(height: 10),
                    _DeletionBullet(
                      text: 'Your athlete profile, avatar, emergency contacts, and residential addresses are permanently erased.',
                    ),
                    _DeletionBullet(
                      text: 'Any upcoming confirmed training sessions are automatically cancelled.',
                    ),
                    _DeletionBullet(
                      text: 'Your sign-in credentials and authentication sessions are permanently revoked.',
                    ),
                    _DeletionBullet(
                      text: 'Past transaction histories and GST invoices are preserved in an anonymized ledger per statutory tax auditing requirements (Section 35 of CGST Act).',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
                      const Icon(Icons.error_outline, color: kDanger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kDanger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── 3. Reason for Leaving (Optional) ──
              _buildInputLabel('Reason for Leaving (Optional)', sf),
              TextFormField(
                controller: _reasonController,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                decoration: _buildInputDecoration(
                  hint: 'Help us understand how we can improve...',
                  icon: Iconsax.edit_2,
                ),
              ),

              const SizedBox(height: 16),

              // ── 4. Re-authentication Password ──
              _buildInputLabel('Confirm Current Password *', sf),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (v) => (v == null || v.isEmpty) ? 'Current password is required to verify identity.' : null,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                decoration: InputDecoration(
                  hintText: 'Enter your current account password',
                  hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFA0A0A0)),
                  prefixIcon: const Icon(Iconsax.key, size: 18, color: kDark),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF6B7280)),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDanger, width: 1.5)),
                ),
              ),

              const SizedBox(height: 16),

              // ── 5. Confirmation Phrase Input ──
              _buildInputLabel('Type "DELETE" to Confirm *', sf),
              TextFormField(
                controller: _confirmTextController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().toUpperCase() != 'DELETE') {
                    return 'Please enter "DELETE" to confirm.';
                  }
                  return null;
                },
                style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 14, color: kDanger, letterSpacing: 1.2),
                decoration: _buildInputDecoration(
                  hint: 'Type DELETE here',
                  icon: Iconsax.danger,
                ),
              ),

              const SizedBox(height: 28),

              // ── 6. Permanent Delete Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isProcessing || !_isConfirmationValid) ? null : _handleDeleteAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDanger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFFCA5A5),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(
                          'Permanently Delete My Account',
                          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, double sf) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Syne',
          fontSize: (12.0 * sf).clamp(11.0, 13.5),
          fontWeight: FontWeight.w700,
          color: kDark,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFA0A0A0)),
      prefixIcon: Icon(icon, size: 18, color: kDark),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDanger, width: 1.5)),
    );
  }
}

class _DeletionBullet extends StatelessWidget {
  final String text;

  const _DeletionBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kDanger, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, height: 1.5, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }
}
