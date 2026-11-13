import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/trainer_profile_model.dart';
import '../../widgets/logout_dialog.dart';
import 'trainer_account_deletion_screen.dart';
import 'trainer_account_security_screen.dart';
import 'trainer_help_support_screen.dart';
import 'trainer_legal_screen.dart';
import 'trainer_notification_preferences_screen.dart';
import 'trainer_personal_info_screen.dart';
import 'trainer_privacy_documents_screen.dart';
import 'trainer_profile_setup_screen.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);
const Color _kDanger = Color(0xFFEF4444);

/// Dedicated Trainer Settings & Account Management Screen
class TrainerSettingsScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerSettingsScreen({super.key, this.trainerId});

  @override
  State<TrainerSettingsScreen> createState() => _TrainerSettingsScreenState();
}

class _TrainerSettingsScreenState extends State<TrainerSettingsScreen> {
  final TrainerProfileService _profileService = TrainerProfileService.instance;
  late final String _trainerId;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        AuthService().currentUser?.uid ??
        '';
    _profileService.loadProfile(_trainerId);
  }

  void _onLogout() async {
    HapticFeedback.lightImpact();
    await showLogoutDialog(context, isTrainer: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isAdvanced = _profileService.category == TrainerCategory.advancedTrainer;
    final isApproved = _profileService.verificationStatus == TrainerVerificationStatus.approved;
    final displayName = _profileService.fullName ?? user?.displayName ?? 'Trainer';
    final photoUrl = _profileService.photoUrl ?? user?.photoURL;
    final email = user?.email ?? '';

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
          'Settings & Account',
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
          // ── Profile Overview Header ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _kCardSubBg,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _kLime,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (isApproved)
                            const Icon(Icons.verified, color: _kLime, size: 18),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isNotEmpty ? email : 'Verified Coach',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _kGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdvanced ? const Color(0xFFE65100).withAlpha(30) : _kLime.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAdvanced ? const Color(0xFFE65100).withAlpha(80) : _kLime.withAlpha(80),
                          ),
                        ),
                        child: Text(
                          isAdvanced ? 'ADVANCED TRAINER' : 'STANDARD TRAINER',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isAdvanced ? const Color(0xFFFB8C00) : _kLime,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section 1: Personal & Professional Profile ──────
          _buildSectionHeader('Profile & Coaching Details'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Iconsax.user,
              title: 'Personal Information',
              subtitle: 'Full name, contact phone, gender, date of birth, photo',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrainerPersonalInfoScreen(trainerId: _trainerId),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: _kBorder),
            _SettingsTile(
              icon: Iconsax.briefcase,
              title: 'Professional Profile',
              subtitle: 'Bio, specialisations, service locations, and coaching approach',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TrainerProfileSetupScreen(),
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ── Section 2: Account & Security ───────────────────
          _buildSectionHeader('Account & Security'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Iconsax.lock,
              title: 'Account & Security',
              subtitle: 'Change password, email verification, session security',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TrainerAccountSecurityScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: _kBorder),
            _SettingsTile(
              icon: Iconsax.notification,
              title: 'Notification Preferences',
              subtitle: 'Configure alerts for bookings, payouts, messages & reviews',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrainerNotificationPreferencesScreen(trainerId: _trainerId),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: _kBorder),
            _SettingsTile(
              icon: Iconsax.shield_security,
              title: 'Privacy & Documents',
              subtitle: 'Certificate records, private documents, verification status',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrainerPrivacyDocumentsScreen(trainerId: _trainerId),
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ── Section 3: Support & Legal ──────────────────────
          _buildSectionHeader('Support & Legal'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Iconsax.message_question,
              title: 'Help & Support',
              subtitle: 'Frequently asked questions, coach desk contact',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TrainerHelpSupportScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: _kBorder),
            _SettingsTile(
              icon: Iconsax.info_circle,
              title: 'Legal Information',
              subtitle: 'Service agreement, conduct standards, privacy policy',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TrainerLegalScreen(),
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 24),

          // ── Section 4: Log Out ──────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _onLogout,
              icon: const Icon(Iconsax.logout, size: 18, color: Colors.white),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Section 5: Danger Zone (Account Deletion) ────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kDanger.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kDanger.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.trash, color: _kDanger, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Account',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kDanger,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Deactivate profile and request closure of coaching account',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerAccountDeletionScreen(trainerId: _trainerId),
                      ),
                    );
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      color: _kDanger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Syne',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _kGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kCardSubBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _kLime, size: 18),
              ),
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
              const Icon(Icons.arrow_forward_ios, color: _kGrey, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
