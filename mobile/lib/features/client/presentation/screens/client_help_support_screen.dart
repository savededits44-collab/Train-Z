import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/support_service.dart';
import '../../../../shared/models/support_ticket_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_submit_ticket_screen.dart';
import 'client_support_tickets_screen.dart';

/// Comprehensive Help & Support section for TRAIN Z Clients.
/// Provides categorized FAQs, policy guides, complaint submission,
/// and support ticket tracking.
class ClientHelpSupportScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String? clientEmail;

  const ClientHelpSupportScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientEmail,
  });

  @override
  State<ClientHelpSupportScreen> createState() => _ClientHelpSupportScreenState();
}

class _ClientHelpSupportScreenState extends State<ClientHelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Top Quick Action Banners ──
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Iconsax.message_question,
                    title: 'Raise a Request',
                    subtitle: 'Report an issue or complaint',
                    color: kDark,
                    iconColor: kLime,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientSubmitTicketScreen(
                            clientId: widget.clientId,
                            clientName: widget.clientName,
                            clientEmail: widget.clientEmail,
                          ),
                        ),
                      );
                    },
                    sf: sf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<List<SupportTicketModel>>(
                    stream: SupportService.instance.streamClientTickets(widget.clientId),
                    builder: (context, snapshot) {
                      final tickets = snapshot.data ?? [];
                      final activeCount = tickets.where((t) => t.isActive).length;

                      return _buildActionTile(
                        icon: Iconsax.ticket,
                        title: 'My Tickets',
                        subtitle: activeCount > 0 ? '$activeCount Active' : 'View history',
                        color: const Color(0xFFF9FAFB),
                        iconColor: kDark,
                        badgeCount: activeCount,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        isDark: false,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientSupportTicketsScreen(
                                clientId: widget.clientId,
                                clientName: widget.clientName,
                                clientEmail: widget.clientEmail,
                              ),
                            ),
                          );
                        },
                        sf: sf,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── 2. Search Field ──
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search help articles, policies, FAQs...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.0),
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(Iconsax.search_normal_1, size: 18, color: Color(0xFF6B7280)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.5 * sf).clamp(11.5, 13.5),
                  color: kDark,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 3. Frequently Asked Questions (Categorized) ──
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (11.5 * sf).clamp(10.5, 12.5),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF888888),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            ..._buildFaqSections(sf),

            const SizedBox(height: 24),

            // ── 4. Contact Support Callout Banner ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
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
                        child: const Icon(Iconsax.headphone, size: 20, color: kLime),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Still Need Assistance?',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (14.0 * sf).clamp(13.0, 15.5),
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Our support team typically reviews requests within 24 business hours.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientSubmitTicketScreen(
                              clientId: widget.clientId,
                              clientName: widget.clientName,
                              clientEmail: widget.clientEmail,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDark,
                        foregroundColor: kLime,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Submit a Support Request',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kLime,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required double sf,
    int badgeCount = 0,
    BoxBorder? border,
    bool isDark = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 24, color: iconColor),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (14.0 * sf).clamp(13.0, 15.5),
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : kDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (10.5 * sf).clamp(9.5, 11.5),
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFaqSections(double sf) {
    final List<Map<String, dynamic>> allFaqs = [
      {
        'category': 'Booking & Scheduling',
        'icon': Iconsax.calendar_tick,
        'items': [
          {
            'q': 'How long are training sessions on TRAIN Z?',
            'a': 'Every personal training session on TRAIN Z is structured for exactly 60 minutes of intensive 1-on-1 coaching, form correction, and workout execution.',
          },
          {
            'q': 'How do I choose and book a Personal Trainer?',
            'a': 'You can browse certified trainers via the "Find Trainer" tab, filter by training venue (commercial gym or home residence), review credentials, and select your preferred 60-minute time slot.',
          },
          {
            'q': 'What happens if two athletes pick the same slot simultaneously?',
            'a': 'TRAIN Z utilizes atomic real-time slot reservation locks. A selected slot is placed in a 15-minute checkout hold for you, preventing any double-booking.',
          },
        ],
      },
      {
        'category': 'Packages & Payments',
        'icon': Iconsax.wallet_check,
        'items': [
          {
            'q': 'What payment methods are supported?',
            'a': 'All packages are billed in Indian Rupees (INR) via Razorpay. We support UPI (Google Pay, PhonePe, Paytm), Net Banking across all major banks, Credit Cards, and Debit Cards.',
          },
          {
            'q': 'How do package session credits work?',
            'a': 'When you purchase a training package (e.g. 1 Month / 12 Sessions), session credits are added to your balance. 1 credit is temporarily reserved upon booking, and deducted upon completed coaching.',
          },
          {
            'q': 'What happens when my package expires?',
            'a': 'Packages have set validity periods (e.g. 30 days for 1 Month packages). Sessions must be scheduled and completed before package expiration.',
          },
        ],
      },
      {
        'category': 'Cancellations & Refunds (Section 8 Policy)',
        'icon': Iconsax.info_circle,
        'items': [
          {
            'q': 'What is the 12-Hour Cancellation Rule?',
            'a': 'Per TRAIN Z Section 8 policy, if you cancel a session 12 or more hours before start time, 1 session credit is returned to your available balance. If cancelled with less than 12 hours notice, the session credit is forfeited to respect your trainer\'s reserved time.',
          },
          {
            'q': 'What if my trainer cancels or reschedules?',
            'a': 'If a session is cancelled by the trainer or platform, your session credit is always 100% returned to your balance immediately, regardless of notice time.',
          },
          {
            'q': 'Can I reschedule an existing booking?',
            'a': 'Yes, you can reschedule an upcoming session directly from the Booking Details screen by selecting an alternate open time slot from your trainer\'s calendar.',
          },
        ],
      },
      {
        'category': 'Account, Safety & Privacy',
        'icon': Iconsax.shield_security,
        'items': [
          {
            'q': 'How is my private address protected?',
            'a': 'Your residential address is strictly confidential. It is never displayed publicly on reviews, profiles, or public trainer listings, and is disclosed solely to your confirmed trainer for coaching arrival.',
          },
          {
            'q': 'What is the Strict Gender Policy?',
            'a': 'TRAIN Z maintains strict gender matching: male clients train exclusively with male trainers, and female clients train exclusively with female trainers.',
          },
          {
            'q': 'How do I edit my athlete profile?',
            'a': 'Navigate to the Profile tab on your bottom navigation bar, tap "Edit" in the top right, and update your name, photo, phone number, and fitness goals.',
          },
        ],
      },
    ];

    final filteredSections = <Widget>[];

    for (final section in allFaqs) {
      final items = (section['items'] as List<Map<String, String>>).where((item) {
        if (_searchQuery.isEmpty) return true;
        final q = item['q']!.toLowerCase();
        final a = item['a']!.toLowerCase();
        return q.contains(_searchQuery) || a.contains(_searchQuery);
      }).toList();

      if (items.isEmpty) continue;

      filteredSections.add(
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
              initiallyExpanded: _searchQuery.isNotEmpty || section['category'] == 'Booking & Scheduling',
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(section['icon'] as IconData, size: 18, color: kDark),
              ),
              title: Text(
                section['category'] as String,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (13.5 * sf).clamp(12.5, 15.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: items.map((faq) {
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Q: ', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kDark)),
                          Expanded(
                            child: Text(
                              faq['q']!,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (12.0 * sf).clamp(11.0, 13.0),
                                fontWeight: FontWeight.w700,
                                color: kDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        faq['a']!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          color: const Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ));
    }

    if (filteredSections.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(Iconsax.info_circle, size: 36, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 8),
                Text(
                  'No matching FAQs found for "$_searchQuery"',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return filteredSections;
  }
}
