import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/trainer_account_service.dart';
import '../../shared/models/account_deletion_model.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kDanger = Color(0xFFEF4444);

/// Screen for Trainers to request account deletion.
/// Enforces business checks: blocks deletion if active bookings or pending payouts exist.
/// Preserves required financial and transaction records.
class TrainerAccountDeletionScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerAccountDeletionScreen({super.key, this.trainerId});

  @override
  State<TrainerAccountDeletionScreen> createState() =>
      _TrainerAccountDeletionScreenState();
}

class _TrainerAccountDeletionScreenState
    extends State<TrainerAccountDeletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TrainerAccountService _accountService = TrainerAccountService.instance;

  late final String _trainerId;
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isCheckingEligibility = true;
  bool _isSubmitting = false;
  bool _confirmedRisk = false;
  bool _obscurePassword = true;
  TrainerDeletionEligibilityResult? _eligibility;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        AuthService().currentUser?.uid ??
        '';
    _checkEligibility();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    setState(() => _isCheckingEligibility = true);
    final result = await _accountService.checkDeletionEligibility(_trainerId);
    if (!mounted) return;
    setState(() {
      _eligibility = result;
      _isCheckingEligibility = false;
    });
  }

  Future<void> _requestDeletion() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmedRisk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm that you understand the deletion terms.'),
          backgroundColor: _kDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      await _accountService.requestAccountDeletion(
        trainerId: _trainerId,
        reason: _reasonCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isNotEmpty ? _passwordCtrl.text.trim() : null,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Show completion dialog and sign out
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _kBorder),
          ),
          title: const Row(
            children: [
              Icon(Iconsax.info_circle, color: Color(0xFF15803D), size: 22),
              SizedBox(width: 8),
              Text(
                'Request Submitted',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: _kDark),
              ),
            ],
          ),
          content: const Text(
            'Your account deletion request has been submitted to platform administrators. Your coach profile is now deactivated.\n\nAll historical financial, booking, and payout ledger entries will be preserved for required audit and tax compliance.',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: _kGrey, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDark,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await AuthService().signOut();
                if (!mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Log Out & Exit', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isGoogleAuth = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
      ),
      body: _isCheckingEligibility
          ? const Center(child: CircularProgressIndicator(color: _kDark))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Danger Banner ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Iconsax.warning_2, color: _kDanger, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Permanent Account Action',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kDanger,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Requesting deletion will immediately deactivate your public coach profile and remove you from athlete search results. You will no longer receive session bookings or client inquiries.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            color: Color(0xFF991B1B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Active Blockers Check ─────────────────────────
                  if (_eligibility != null && !_eligibility!.canDelete) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kDanger),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.block, color: _kDanger, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Account Deletion Restricted',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kDanger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _eligibility!.blockerReason ?? 'Account cannot be deleted at this time.',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              color: Color(0xFF991B1B),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_eligibility!.hasActiveBookings)
                            const Text(
                              '• All upcoming sessions must be completed or settled.\n• Notify booked athletes prior to resolving sessions.',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: _kGrey, height: 1.4),
                            ),
                          if (_eligibility!.hasPendingPayouts)
                            const Text(
                              '• Wait for pending bank payouts to complete successfully.',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: _kGrey, height: 1.4),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Data Retention Notice ─────────────────────────
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
                            Icon(Iconsax.receipt_2, color: _kDark, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Financial & Audit Record Retention',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kDark,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'To comply with financial regulations and tax requirements, your historical transaction records, completed booking references, and payout statements will be preserved securely in our audit ledger and cannot be erased.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: _kGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Deletion Reason ───────────────────────────────
                  const Text(
                    'Reason for leaving (Optional)',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Please share your feedback or reason for closing your account...',
                      hintStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit', fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kDark),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Password Reauthentication (if Email auth) ─────
                  if (!isGoogleAuth) ...[
                    const Text(
                      'Reauthenticate with Password',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontFamily: 'Outfit', color: _kDark),
                      decoration: InputDecoration(
                        hintText: 'Enter your current password to confirm',
                        hintStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit', fontSize: 12),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                            color: _kGrey,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kDanger),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter your password to confirm identity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Risk Confirmation Checkbox ────────────────────
                  CheckboxListTile(
                    value: _confirmedRisk,
                    onChanged: (_eligibility != null && !_eligibility!.canDelete)
                        ? null
                        : (val) => setState(() => _confirmedRisk = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    activeColor: _kDanger,
                    title: const Text(
                      'I understand that my trainer profile will be permanently deactivated and I will lose access to my coaching profile.',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: _kDark),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  const SizedBox(height: 24),

                  // ── Submit Deletion Button ────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kDanger,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: (_isSubmitting || (_eligibility != null && !_eligibility!.canDelete))
                          ? null
                          : _requestDeletion,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Request Account Deletion',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
