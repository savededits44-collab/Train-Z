import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/client_settings_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/client_profile_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_account_deletion_screen.dart';
import 'client_account_security_screen.dart';
import 'client_help_support_screen.dart';
import 'client_legal_screen.dart';
import 'client_login_screen.dart';
import 'client_notification_preferences_screen.dart';
import 'client_personal_info_screen.dart';
import 'client_privacy_settings_screen.dart';
import 'client_support_tickets_screen.dart';

/// Master Settings Screen for TRAIN Z Clients.
/// Organised into Personal Info, Account Security, Notifications, Privacy, Help, Legal, and Account Actions.
class ClientSettingsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String? clientEmail;

  const ClientSettingsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientEmail,
  });

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final ClientSettingsService _settingsService = ClientSettingsService.instance;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  ClientProfileModel? _clientProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getUserModel(widget.clientId);
      final profile = await _firestoreService.getClientProfile(widget.clientId);
      if (mounted) {
        setState(() {
          _userModel = user;
          _clientProfile = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Sign Out',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kDark, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to sign out of TRAIN Z? You will need your credentials to log back in.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Sign Out', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      await _settingsService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.25);
    final displayName = _userModel?.displayName ?? widget.clientName;
    final email = _userModel?.email ?? widget.clientEmail ?? '';
    final photoUrl = _userModel?.photoUrl;
    final isEmailVerified = _userModel?.isEmailVerified ?? false;

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
          'Settings & Account',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kDark))
          : RefreshIndicator(
              onRefresh: _loadUserData,
              color: kDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Profile Summary Card ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: kDark,
                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                                    style: const TextStyle(fontFamily: 'Syne', fontSize: 22, color: kLime, fontWeight: FontWeight.w800),
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
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontFamily: 'Syne',
                                          fontSize: (16.0 * sf).clamp(14.0, 18.0),
                                          fontWeight: FontWeight.w800,
                                          color: kDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      isEmailVerified ? Icons.verified : Icons.error_outline,
                                      size: 16,
                                      color: isEmailVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF6B7280)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'TRAIN Z Athlete',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: kDark.withValues(alpha: 0.8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── 2. Section: Personal Information ──
                    _buildSectionHeader('Personal Information', sf),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Iconsax.user_edit,
                        title: 'Edit Personal Details',
                        subtitle: 'Name, profile photo, phone number & fitness targets',
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientPersonalInfoScreen(
                                clientId: widget.clientId,
                                userModel: _userModel,
                                profileModel: _clientProfile,
                              ),
                            ),
                          );
                          if (updated == true) _loadUserData();
                        },
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── 3. Section: Account & Security ──
                    _buildSectionHeader('Account & Security', sf),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Iconsax.shield_security,
                        title: 'Password & Credentials',
                        subtitle: 'Change password, security recovery, email verification',
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientAccountSecurityScreen(
                                clientId: widget.clientId,
                                userEmail: email,
                                isEmailVerified: isEmailVerified,
                              ),
                            ),
                          );
                          if (updated == true) _loadUserData();
                        },
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── 4. Section: Preferences ──
                    _buildSectionHeader('Preferences', sf),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Iconsax.notification,
                        title: 'Notification Preferences',
                        subtitle: 'Session reminders, booking alerts, and trainer messages',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientNotificationPreferencesScreen(
                                clientId: widget.clientId,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                      _buildSettingsTile(
                        icon: Iconsax.lock,
                        title: 'Privacy & Data Protection',
                        subtitle: 'Address confidentiality, name masking & data usage',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientPrivacySettingsScreen(
                                clientId: widget.clientId,
                              ),
                            ),
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── 5. Section: Support & Legal ──
                    _buildSectionHeader('Support & Legal', sf),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Iconsax.info_circle,
                        title: 'Help & Support Center',
                        subtitle: 'FAQs, booking guides & platform policies',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientHelpSupportScreen(
                                clientId: widget.clientId,
                                clientName: displayName,
                                clientEmail: email,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                      _buildSettingsTile(
                        icon: Iconsax.ticket,
                        title: 'My Support Requests',
                        subtitle: 'Track your raised complaints and tickets',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientSupportTicketsScreen(
                                clientId: widget.clientId,
                                clientName: displayName,
                                clientEmail: email,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                      _buildSettingsTile(
                        icon: Iconsax.document_text,
                        title: 'Legal Information & Policies',
                        subtitle: 'Terms, Privacy Policy, Section 8 Refund Policy',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ClientLegalScreen(),
                            ),
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── 6. Section: Account Actions ──
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Iconsax.logout,
                        iconColor: const Color(0xFFDC2626),
                        title: 'Log Out',
                        titleColor: const Color(0xFFDC2626),
                        subtitle: 'Sign out of your active session on this device',
                        onTap: _handleLogout,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF3F4F6)),
                      _buildSettingsTile(
                        icon: Iconsax.trash,
                        iconColor: const Color(0xFFDC2626),
                        title: 'Delete Account',
                        titleColor: const Color(0xFFDC2626),
                        subtitle: 'Permanently remove profile & personal data',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientAccountDeletionScreen(
                                clientId: widget.clientId,
                                clientEmail: email,
                              ),
                            ),
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 32),

                    // ── 7. Version & Brand Footer ──
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'TRAIN Z',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.5,
                              color: kDark.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Personal Training Platform • Version 1.0.0+1',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Strict 1-on-1 Fitness Coaching • Indian Rupee Billing',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Color(0xFFB0B7C3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, double sf) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Syne',
          fontSize: (11.0 * sf).clamp(10.0, 12.5),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? kDark).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? kDark),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Syne',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: titleColor ?? kDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF6B7280)),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
