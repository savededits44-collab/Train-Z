import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/credit_service.dart';
import '../../../../shared/models/session_credit_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../../../widgets/logout_dialog.dart';

/// Clean Client Home foundation screen for TRAIN Z.
/// Displays client profile summary, gender matching status, and real-time credit ledger.
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.065).clamp(18.0, 28.0);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const AppLogo(fontSize: 16),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.logout, color: kDark),
            tooltip: 'Sign Out',
            onPressed: () => showLogoutDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: AuthService().currentUserProfileStream,
        builder: (context, userSnap) {
          final client = userSnap.data;
          final displayName = client?.displayName ?? user?.displayName ?? 'Athlete';
          final genderStr = client?.gender == Gender.female ? 'Female' : 'Male';

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Client Header ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: (26.0 * sf).clamp(22.0, 30.0),
                      backgroundColor: const Color(0xFF111111),
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (18.0 * sf).clamp(16.0, 22.0),
                          fontWeight: FontWeight.w800,
                          color: kLime,
                        ),
                      ),
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
                                  'Hello, $displayName',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (20.0 * sf).clamp(17.0, 24.0),
                                    fontWeight: FontWeight.w800,
                                    color: kDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 16, color: Color(0xFF16A34A)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            client?.email ?? user?.email ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.5 * sf).clamp(10.5, 13.0),
                              color: kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Gender Matching Banner (Section 5) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          client?.gender == Gender.female ? Icons.female : Icons.male,
                          size: 18,
                          color: kLime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Matching with $genderStr Coaches only',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (12.5 * sf).clamp(11.5, 14.0),
                                fontWeight: FontWeight.w700,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Strict 1-on-1 gender alignment enforced by TrainZ backend.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (10.5 * sf).clamp(9.5, 12.0),
                                color: kGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Real-time Session Credits Card (Section 8) ──
                StreamBuilder<SessionCreditModel?>(
                  stream: CreditService().streamClientCredits(uid),
                  builder: (context, creditSnap) {
                    final credits = creditSnap.data;
                    final available = credits?.availableBalance ?? 0;
                    final reserved = credits?.totalReserved ?? 0;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SESSION CREDITS',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: (11.0 * sf).clamp(10.0, 12.5),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFAAAAAA),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: kLime.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '60 Min / Session',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (10.0 * sf).clamp(9.0, 11.5),
                                    fontWeight: FontWeight.w600,
                                    color: kLime,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$available',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: (40.0 * sf).clamp(32.0, 48.0),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Available Sessions',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (13.5 * sf).clamp(12.0, 15.0),
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFCCCCCC),
                                ),
                              ),
                            ],
                          ),
                          if (reserved > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '$reserved session(s) currently reserved for upcoming workouts.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (11.0 * sf).clamp(10.0, 12.5),
                                color: const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Foundation Placeholders for Next Prompts ──
                Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (11.5 * sf).clamp(10.5, 13.0),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF888888),
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 12),

                _QuickActionTile(
                  icon: Iconsax.search_normal_1,
                  title: 'Discover 1-on-1 Coaches',
                  subtitle: 'Browse approved $genderStr personal trainers in your city.',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trainer discovery ready for Prompt 3!')),
                    );
                  },
                ),

                const SizedBox(height: 10),

                _QuickActionTile(
                  icon: Iconsax.calendar_1,
                  title: 'Training Schedule',
                  subtitle: 'View upcoming confirmed sessions & manage bookings.',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session scheduling ready for booking prompt!')),
                    );
                  },
                ),

                const SizedBox(height: 10),

                _QuickActionTile(
                  icon: Iconsax.card,
                  title: 'Packages & Memberships',
                  subtitle: 'Buy session packages from ₹500 (1 Day to 6-Month plans).',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Training plans ready for packages prompt!')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Icon(icon, size: 20, color: kDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (13.5 * sf).clamp(12.5, 15.0),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      color: kGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Iconsax.arrow_right_3, size: 16, color: Color(0xFF888888)),
          ],
        ),
      ),
    );
  }
}
