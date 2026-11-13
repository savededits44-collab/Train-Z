import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

class TrainerLegalScreen extends StatelessWidget {
  const TrainerLegalScreen({super.key});

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
          'Legal Information',
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
          _buildLegalTile(
            icon: Iconsax.document_text,
            title: 'Trainer Service Agreement',
            subtitle: 'Platform obligations, commission structures, and dispute resolution.',
            content:
                'Trainers operate on TRAIN Z as verified independent fitness professionals. All payments are securely processed through TRAIN Z escrow and transferred in accordance with platform commission terms. Independent coaching off-platform with clients acquired via TRAIN Z without authorization is strictly prohibited.',
          ),
          _buildLegalTile(
            icon: Iconsax.shield_tick,
            title: 'Coach Code of Conduct & Safety',
            subtitle: 'Professional boundaries, punctuality, and client wellness rules.',
            content:
                'Coaches must uphold respectful, non-discriminatory, and purely athletic relationships. Sessions must adhere strictly to agreed training locations and safety guidelines. Zero-tolerance policy applies to harassment, unauthorized physical contact, or unprofessional conduct.',
          ),
          _buildLegalTile(
            icon: Iconsax.lock,
            title: 'Privacy & Data Retention Policy',
            subtitle: 'How personal information, certificates, and financial records are handled.',
            content:
                'TRAIN Z stores personal and credential documents under rigorous encryption. When account deletion is requested, public profiles are deactivated while legally mandatory financial, payment, and tax records are retained in compliance with applicable laws.',
          ),
          _buildLegalTile(
            icon: Iconsax.copyright,
            title: 'Intellectual Property & Licenses',
            subtitle: 'Brand assets, package designs, and proprietary workout content.',
            content:
                'TRAIN Z logos, interface elements, and platform packages are proprietary property. Coaches retain intellectual property rights over their bespoke training notes and custom session routines.',
          ),

          const SizedBox(height: 24),

          // App Version Info
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Text(
                    'TRAIN Z Coach • v1.0.0 (Build 100)',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '© 2026 TRAIN Z Fitness Technologies. All rights reserved.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: _kLime,
            collapsedIconColor: _kGrey,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(icon, color: _kLime, size: 20),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: _kGrey,
              ),
            ),
            children: [
              Text(
                content,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
