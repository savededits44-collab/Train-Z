import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_notification_preferences_service.dart';
import '../../shared/models/trainer_notification_preferences_model.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

/// Screen allowing Trainers to manage optional notification categories
/// while keeping essential security and verification alerts permanently active.
class TrainerNotificationPreferencesScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerNotificationPreferencesScreen({
    super.key,
    this.trainerId,
  });

  @override
  State<TrainerNotificationPreferencesScreen> createState() =>
      _TrainerNotificationPreferencesScreenState();
}

class _TrainerNotificationPreferencesScreenState
    extends State<TrainerNotificationPreferencesScreen> {
  final TrainerNotificationPreferencesService _prefsService =
      TrainerNotificationPreferencesService.instance;
  late final String _trainerId;

  TrainerNotificationPreferencesModel _prefs =
      const TrainerNotificationPreferencesModel();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _prefsService.getPreferences(_trainerId);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _isLoading = false;
    });
  }

  Future<void> _updatePref(TrainerNotificationPreferencesModel updated) async {
    setState(() => _prefs = updated);
    HapticFeedback.lightImpact();
    await _prefsService.updatePreferences(_trainerId, updated);
  }

  @override
  Widget build(BuildContext context) {
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
          'Notification Preferences',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kLime))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 1. Essential Notifications (Mandatory / Locked) ───────────
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
                              Icon(Iconsax.shield_security, color: _kLime, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Essential Notifications',
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
                              color: const Color(0xFF64B5F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ALWAYS ON',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64B5F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Account security, password changes, and administrator certificate verification status notifications cannot be disabled to protect your account.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: _kGrey,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildLockedItem(
                        icon: Iconsax.lock,
                        title: 'Account Security & Sign-in Alerts',
                        subtitle: 'Critical unauthorized access detection & password changes',
                      ),
                      const SizedBox(height: 10),
                      _buildLockedItem(
                        icon: Iconsax.award,
                        title: 'Certificate & Account Verification',
                        subtitle: 'Official Admin verification and compliance status notices',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── 2. Optional Notification Channels ────────────────────────
                const Text(
                  'Optional Notification Channels',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Customize which optional notification categories you receive on your registered devices.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kGrey),
                ),
                const SizedBox(height: 14),

                Container(
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    children: [
                      _buildToggleItem(
                        icon: Iconsax.calendar_tick,
                        title: 'Booking Updates',
                        subtitle: 'New session requests, cancellations, and reschedules',
                        value: _prefs.bookings,
                        onChanged: (val) => _updatePref(_prefs.copyWith(bookings: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.clock,
                        title: 'Session Reminders',
                        subtitle: 'Upcoming training alerts 24h and 1h prior to sessions',
                        value: _prefs.sessionReminders,
                        onChanged: (val) => _updatePref(_prefs.copyWith(sessionReminders: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.message,
                        title: 'Client Messages',
                        subtitle: 'Direct 1-on-1 chats from booked athletes',
                        value: _prefs.messages,
                        onChanged: (val) => _updatePref(_prefs.copyWith(messages: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.box,
                        title: 'Package Approvals',
                        subtitle: 'Admin approvals or feedback on custom training plans',
                        value: _prefs.packageApprovals,
                        onChanged: (val) => _updatePref(_prefs.copyWith(packageApprovals: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.wallet_money,
                        title: 'Earnings & Payouts',
                        subtitle: 'Completed session credits, payouts, and transfers',
                        value: _prefs.payouts,
                        onChanged: (val) => _updatePref(_prefs.copyWith(payouts: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.star,
                        title: 'Reviews & Feedback',
                        subtitle: 'New athlete star ratings, written reviews, and reports',
                        value: _prefs.reviews,
                        onChanged: (val) => _updatePref(_prefs.copyWith(reviews: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.headphone,
                        title: 'Support Updates',
                        subtitle: 'Customer support ticket responses and help desk inquiries',
                        value: _prefs.support,
                        onChanged: (val) => _updatePref(_prefs.copyWith(support: val)),
                      ),
                      const Divider(height: 1, color: _kBorder),
                      _buildToggleItem(
                        icon: Iconsax.notification,
                        title: 'Promotional Announcements',
                        subtitle: 'Platform feature updates, coaching tips, and news',
                        value: _prefs.promotions,
                        onChanged: (val) => _updatePref(_prefs.copyWith(promotions: val)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reset to Defaults Button
                TextButton.icon(
                  onPressed: () {
                    _updatePref(const TrainerNotificationPreferencesModel());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preferences reset to recommended defaults.')),
                    );
                  },
                  icon: const Icon(Iconsax.refresh, size: 16, color: _kGrey),
                  label: const Text(
                    'Reset to Recommended Defaults',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kGrey,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildLockedItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardSubBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64B5F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.lock, size: 16, color: _kGrey),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? _kLime : _kGrey),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: _kDark,
            activeTrackColor: _kLime,
            inactiveThumbColor: _kGrey,
            inactiveTrackColor: _kCardSubBg,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
