import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_account_deletion_screen.dart';
import 'client_legal_screen.dart';

class ClientPrivacySettingsScreen extends StatelessWidget {
  final String clientId;

  const ClientPrivacySettingsScreen({
    super.key,
    required this.clientId,
  });

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
          'Privacy & Data Protection',
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
            // ── Subtitle ──
            Text(
              'Your privacy is fundamental to the TRAIN Z coaching model. We ensure total transparency in how your data is handled.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.0 * sf).clamp(11.0, 13.5),
                color: const Color(0xFF4B5563),
              ),
            ),

            const SizedBox(height: 18),

            // ── 1. Address Confidentiality Card ──
            _buildPrivacyCard(
              icon: Iconsax.shield_tick,
              title: 'Private Residential Address Protection',
              badge: 'Confidential',
              badgeColor: const Color(0xFF16A34A),
              description:
                  'Your residential address and home location details are strictly private. They are never published on trainer profiles, community forums, or review lists. Your address is disclosed solely to your confirmed 1-on-1 coach for training arrival.',
              sf: sf,
            ),

            const SizedBox(height: 14),

            // ── 2. Review Anonymity & Masking Card ──
            _buildPrivacyCard(
              icon: Iconsax.eye_slash,
              title: 'Athlete Name Masking on Reviews',
              badge: 'Automated',
              badgeColor: const Color(0xFF2563EB),
              description:
                  'When you review a session, your full surname is automatically masked (e.g. "Rahul Sharma" appears publicly as "Rahul S."). This protects your identity while preserving genuine community feedback.',
              sf: sf,
            ),

            const SizedBox(height: 14),

            // ── 3. Personal Data Usage Card ──
            _buildPrivacyCard(
              icon: Iconsax.document_filter,
              title: 'How We Use Your Personal Data',
              description:
                  'We collect and process your fitness goals, gender, and contact details strictly for:\n'
                  '• Strict gender-aligned 1-on-1 personal training matching.\n'
                  '• Coordinating 60-minute coaching slots and schedule locks.\n'
                  '• Processing secure INR payments and invoices via Razorpay.\n'
                  '• Direct trainer-to-athlete communication and support inquiries.',
              sf: sf,
            ),

            const SizedBox(height: 14),

            // ── 4. Data Deletion & Retention Information ──
            _buildPrivacyCard(
              icon: Iconsax.archive_book,
              title: 'Data Deletion & Retention Policy',
              description:
                  'When an athlete account is closed:\n'
                  '• Profile photos, phone numbers, and emergency contacts are permanently erased.\n'
                  '• In accordance with Indian tax laws and GST statutory compliance (Section 35 of CGST Act), past financial transactions and invoice records are preserved in an anonymized ledger for statutory audit purposes.\n'
                  '• You retain the right to request full account closure at any time.',
              sf: sf,
            ),

            const SizedBox(height: 24),

            // ── 5. Privacy Policy Action Button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientLegalScreen(initialTabIndex: 1)),
                  );
                },
                icon: const Icon(Iconsax.document_text, size: 18, color: kDark),
                label: const Text(
                  'View Complete Privacy Policy',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13, color: kDark),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── 6. Account Deletion Action Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientAccountDeletionScreen(
                        clientId: clientId,
                        clientEmail: '',
                      ),
                    ),
                  );
                },
                icon: const Icon(Iconsax.trash, size: 18, color: Color(0xFFDC2626)),
                label: const Text(
                  'Request Account Deletion',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFDC2626)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    required String description,
    required double sf,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: kLime),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.5, 15.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF16A34A)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              height: 1.5,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
