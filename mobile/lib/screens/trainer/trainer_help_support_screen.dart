import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/utils/support_email_helper.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);

class TrainerHelpSupportScreen extends StatelessWidget {
  const TrainerHelpSupportScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'question': 'How does platform commission work?',
      'answer':
          'TRAIN Z deducts a transparent platform commission (typically 15-20% as determined by platform administration) on eligible completed sessions to cover secure payment processing, marketing, customer support, and insurance coverage. Net earnings are computed authoritatively on the backend.',
    },
    {
      'question': 'When are trainer payouts transferred?',
      'answer':
          'Completed training sessions accumulate in your earnings ledger. Payouts are batched and transferred directly to your verified bank account according to the regular platform payout schedule (usually weekly or bi-weekly).',
    },
    {
      'question': 'What is the 12-Hour session cancellation policy?',
      'answer':
          'Athletes must cancel or reschedule at least 12 hours before a scheduled session to receive a session credit return. If an athlete cancels within 12 hours or fails to attend, the session credit is forfeited and credited to your earnings according to policy.',
    },
    {
      'question': 'How can I become an Advanced Trainer?',
      'answer':
          'Standard Trainers can submit professional certifications (e.g. CSCS, ACE, NASM, ISSA) and verify 3.5+ years of coaching experience in the Certificate Management section. Once approved by Admin, you can set custom session rates and create bespoke training plans.',
    },
    {
      'question': 'How are client disputes and safety issues handled?',
      'answer':
          'TRAIN Z maintains strict professional standards. If an issue arises with an athlete or location, report the incident immediately via Help & Support. Our 24/7 trust and safety team reviews reports impartially.',
    },
  ];

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
          'Help & Support',
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
          // ── Contact Support Section ───────────────────────
          const Text(
            'Contact Support',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // ── Contact Support Card ──────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kCardSubBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.headphone, color: _kDark, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                SupportEmailHelper.officialSupportIdentity,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _kDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kCardSubBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TRAIN Z Coach Support',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: _kGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Priority coach assistance desk',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: _kGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Have an issue regarding payouts, booking schedules, account verification, or athlete conduct? Our dedicated coach desk is available 7 days a week.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Clickable Email Support Tile ──
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    SupportEmailHelper.launchSupportEmail(
                      context: context,
                      subject: 'TRAIN Z Coach Support Request',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _kCardSubBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.sms, color: _kDark, size: 18),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Support',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  color: _kGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                SupportEmailHelper.officialSupportEmail,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _kDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.export_1, size: 14, color: _kDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── FAQ Accordion Section ─────────────────────────
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 12),

          ..._faqs.map((faq) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Material(
                color: Colors.transparent,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    iconColor: _kDark,
                    collapsedIconColor: _kGrey,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    children: [
                      Text(
                        faq['answer']!,
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
          }),
        ],
      ),
    );
  }
}
