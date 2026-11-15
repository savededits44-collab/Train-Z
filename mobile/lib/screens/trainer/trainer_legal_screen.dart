import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);

class TrainerLegalScreen extends StatelessWidget {
  const TrainerLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Legal Information',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLegalTile(
            context,
            icon: Iconsax.document_text,
            title: 'Trainer Service Agreement',
            subtitle: 'Platform obligations, commission structures, and dispute resolution.',
            content:
                'Trainers operate on TRAIN Z as verified independent fitness professionals. All payments are securely processed through TRAIN Z escrow and transferred in accordance with platform commission terms. Independent coaching off-platform with clients acquired via TRAIN Z without authorization is strictly prohibited.',
          ),
          _buildLegalTile(
            context,
            icon: Iconsax.shield_tick,
            title: 'Coach Code of Conduct & Safety',
            subtitle: 'Professional boundaries, punctuality, and client wellness rules.',
            content:
                'Coaches must uphold respectful, non-discriminatory, and purely athletic relationships. Sessions must adhere strictly to agreed training locations and safety guidelines. Zero-tolerance policy applies to harassment, unauthorized physical contact, or unprofessional conduct.',
          ),
          _buildLegalTile(
            context,
            icon: Iconsax.lock,
            title: 'Privacy & Data Retention Policy',
            subtitle: 'How personal information, certificates, and financial records are handled.',
            content:
                'TRAIN Z stores personal and credential documents under rigorous encryption. When account deletion is requested, public profiles are deactivated while legally mandatory financial, payment, and tax records are retained in compliance with applicable laws.',
          ),
          _buildLegalTile(
            context,
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
                    color: _kCardSubBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Text(
                    'TRAIN Z Coach • v1.0.0 (Build 100)',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '© 2026 TRAIN Z Fitness Technologies. All rights reserved.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
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

  Widget _buildLegalTile(
    BuildContext context, {
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
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: _kDark,
            collapsedIconColor: _kGrey,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(icon, color: _kDark, size: 20),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                color: _kGrey,
              ),
            ),
            children: [
              Text(
                content,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  color: Color(0xFF4B5563),
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
