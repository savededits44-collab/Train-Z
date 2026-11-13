import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/client_settings_service.dart';
import '../../../../shared/models/notification_preferences_model.dart';
import '../../../../widgets/app_widgets.dart';

class ClientNotificationPreferencesScreen extends StatefulWidget {
  final String clientId;

  const ClientNotificationPreferencesScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientNotificationPreferencesScreen> createState() =>
      _ClientNotificationPreferencesScreenState();
}

class _ClientNotificationPreferencesScreenState
    extends State<ClientNotificationPreferencesScreen> {
  final ClientSettingsService _settingsService = ClientSettingsService.instance;
  NotificationPreferencesModel _currentPrefs = const NotificationPreferencesModel();
  bool _isInitialized = false;

  Future<void> _updatePreference(NotificationPreferencesModel updated) async {
    HapticFeedback.lightImpact();
    setState(() => _currentPrefs = updated);
    await _settingsService.updateNotificationPreferences(widget.clientId, updated);
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
          'Notification Preferences',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
      ),
      body: StreamBuilder<NotificationPreferencesModel>(
        stream: _settingsService.streamNotificationPreferences(widget.clientId),
        builder: (context, snapshot) {
          if (snapshot.hasData && !_isInitialized) {
            _currentPrefs = snapshot.data!;
            _isInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Subtitle Header ──
                Text(
                  'Choose which notifications you wish to receive. We prioritize your focus and only send vital personal training alerts.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    color: const Color(0xFF4B5563),
                  ),
                ),

                const SizedBox(height: 18),

                // ── 1. Mandatory Security Banner ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Iconsax.shield_tick, size: 18, color: kLime),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Account Security Alerts',
                                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12.5, color: kDark),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '(Mandatory)',
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Password changes, logins from new devices, and transaction invoices are always delivered for security compliance.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 2. Category Switches Card ──
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'SESSION & BOOKING CHANNELS',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Iconsax.calendar_tick,
                          title: 'Booking Updates',
                          subtitle: 'Confirmations, reschedules, and cancellation notices',
                          value: _currentPrefs.bookingUpdates,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(bookingUpdates: val)),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                        _buildSwitchTile(
                          icon: Iconsax.clock,
                          title: 'Session Reminders',
                          subtitle: 'Helpful alerts at 12 hours, 2 hours, and 1 hour before coaching',
                          value: _currentPrefs.sessionReminders,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(sessionReminders: val)),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                        _buildSwitchTile(
                          icon: Iconsax.message,
                          title: 'Trainer Messages',
                          subtitle: 'Direct workout guidance and arrivals from your personal coach',
                          value: _currentPrefs.trainerMessages,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(trainerMessages: val)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 3. Billing & Support Channels ──
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'PAYMENTS & PLATFORM',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Iconsax.wallet_3,
                          title: 'Payment & Package Updates',
                          subtitle: 'Purchase receipts, credit deductions, and expiration warnings',
                          value: _currentPrefs.paymentUpdates,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(paymentUpdates: val)),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                        _buildSwitchTile(
                          icon: Iconsax.star,
                          title: 'Reviews & Feedback',
                          subtitle: 'Session feedback requests and trainer response updates',
                          value: _currentPrefs.reviewsAndFeedback,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(reviewsAndFeedback: val)),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                        _buildSwitchTile(
                          icon: Iconsax.ticket,
                          title: 'Support Ticket Updates',
                          subtitle: 'Customer specialist responses and complaint resolution status',
                          value: _currentPrefs.supportUpdates,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(supportUpdates: val)),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                        _buildSwitchTile(
                          icon: Iconsax.notification,
                          title: 'Platform Announcements',
                          subtitle: 'New training features, trainer roster expansions & workout advice',
                          value: _currentPrefs.platformAnnouncements,
                          onChanged: (val) => _updatePreference(_currentPrefs.copyWith(platformAnnouncements: val)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Notification Infrastructure Notice ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Iconsax.info_circle, size: 16, color: Color(0xFF6B7280)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Preferences are synchronized across your devices in real-time. Disabled categories will be suppressed immediately.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: kLime,
      activeTrackColor: kDark,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kDark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: kDark),
      ),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13, color: kDark),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF6B7280)),
      ),
    );
  }
}
