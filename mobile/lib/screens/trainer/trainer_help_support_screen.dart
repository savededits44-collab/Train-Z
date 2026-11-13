import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

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
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Help & Support',
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
                        color: _kLime.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.headphone, color: _kLime, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRAIN Z Coach Support',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Priority coach assistance desk',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kGrey),
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
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kLime,
                          side: const BorderSide(color: _kLime),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Support desk email: support@trainz.fit',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                              ),
                              backgroundColor: _kCardSubBg,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Iconsax.sms, size: 16),
                        label: const Text(
                          'support@trainz.fit',
                          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── FAQ Accordion Section ─────────────────────────
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
                  data: ThemeData.dark().copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    iconColor: _kLime,
                    collapsedIconColor: _kGrey,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    children: [
                      Text(
                        faq['answer']!,
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
          }),
        ],
      ),
    );
  }
}
