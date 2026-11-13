import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';

class ClientLegalScreen extends StatefulWidget {
  final int initialTabIndex;

  const ClientLegalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ClientLegalScreen> createState() => _ClientLegalScreenState();
}

class _ClientLegalScreenState extends State<ClientLegalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: Colors.white,
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
          'Legal & Compliance',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: kDark,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          labelStyle: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13),
          indicatorColor: kDark,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Terms & Conditions'),
            Tab(text: 'Privacy Policy'),
            Tab(text: 'Cancellations & Refunds'),
            Tab(text: 'Community Guidelines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsTab(sf),
          _buildPrivacyTab(sf),
          _buildCancellationTab(sf),
          _buildGuidelinesTab(sf),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.headphone, size: 18, color: kDark),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Legal & compliance questions: legal@trainz.fit',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsTab(double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegalHeader('TRAIN Z Athlete Platform Agreement', 'Last Updated: November 2026', sf),
          _buildParagraph(
            'Welcome to TRAIN Z. By accessing or using the TRAIN Z mobile application, you agree to be bound by these Terms and Conditions. TRAIN Z connects verified athletes with certified personal fitness trainers for customized 1-on-1 coaching sessions.',
          ),
          _buildSectionTitle('1. Training Sessions & Duration', sf),
          _buildParagraph(
            'All personal training sessions booked on TRAIN Z are structured for exactly 60 minutes of intensive physical instruction, form correction, and workout coaching. Trainers and clients are required to be present at the agreed venue at the designated start time.',
          ),
          _buildSectionTitle('2. Health & Medical Readiness', sf),
          _buildParagraph(
            'Physical exercise involves inherent physiological demands. You warrant that you are in suitable physical health to engage in intensive workouts and have obtained medical clearance where required. Athletes must disclose relevant injuries or physical limitations to their trainer prior to session commencement.',
          ),
          _buildSectionTitle('3. Strict Gender Matching Policy', sf),
          _buildParagraph(
            'To uphold comfort, safety, and operational standards, TRAIN Z enforces a strict gender-aligned coaching model: male clients train exclusively with male trainers, and female clients train exclusively with female trainers.',
          ),
          _buildSectionTitle('4. Training Packages & Payments', sf),
          _buildParagraph(
            'All training packages are billed in Indian Rupees (INR) via Razorpay. Packages carry defined validity periods (e.g. 30 days for 1-Month / 12-session packages). Session credits must be consumed prior to package expiry.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab(double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegalHeader('TRAIN Z Privacy & Data Protection Policy', 'Effective: November 2026', sf),
          _buildParagraph(
            'Your privacy is foundational to our platform. This policy explains how TRAIN Z collects, safeguards, and processes personal information.',
          ),
          _buildSectionTitle('1. Information We Collect', sf),
          _buildParagraph(
            'We collect your full name, email address, phone number, gender, fitness goals, and selected workout venue. For residential workouts, your street address is captured to facilitate coach navigation.',
          ),
          _buildSectionTitle('2. Address Confidentiality Guarantee', sf),
          _buildParagraph(
            'Your residential address is strictly confidential. It is NEVER displayed publicly on trainer listings, reviews, or promotional materials. It is transmitted solely to your confirmed coach for coaching arrival.',
          ),
          _buildSectionTitle('3. Review Identity Protection', sf),
          _buildParagraph(
            'To protect athlete privacy, all public session reviews automatically mask client surnames (e.g., "Rahul Sharma" appears as "Rahul S.").',
          ),
          _buildSectionTitle('4. Statutory Data Retention', sf),
          _buildParagraph(
            'In accordance with Section 35 of the Central Goods and Services Tax (CGST) Act and Indian financial regulations, transaction histories and GST invoices are preserved in an anonymized archive ledger upon account closure.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCancellationTab(double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegalHeader('Cancellation & Refund Policy (Section 8 Policy)', 'Applicable Platform-Wide', sf),
          _buildParagraph(
            'TRAIN Z operates a fair and transparent cancellation policy designed to respect both athlete flexibility and trainer scheduled time.',
          ),
          _buildSectionTitle('1. The 12-Hour Cancellation Rule', sf),
          _buildParagraph(
            '• Notice of 12 Hours or More: If you cancel an upcoming confirmed session 12 or more hours prior to scheduled start time, 1 session credit is returned 100% to your available balance immediately.\n'
            '• Notice of Less Than 12 Hours: If you cancel with less than 12 hours notice, the reserved session credit is forfeited to compensate the trainer for their reserved coaching block.',
          ),
          _buildSectionTitle('2. Trainer-Initiated Cancellations', sf),
          _buildParagraph(
            'If a personal trainer or the platform cancels a confirmed session for any reason, your session credit is 100% returned to your balance immediately, regardless of time of notice.',
          ),
          _buildSectionTitle('3. Rescheduling Sessions', sf),
          _buildParagraph(
            'Athletes may reschedule an upcoming session directly via the app up to 12 hours before start time without any penalty by selecting an open slot on their trainer’s availability calendar.',
          ),
          _buildSectionTitle('4. Package Expiration & Financial Refunds', sf),
          _buildParagraph(
            'Platform packages are non-refundable once session credits have been partially consumed. Exceptional refund requests are evaluated by customer support per statutory guidelines.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGuidelinesTab(double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegalHeader('TRAIN Z Community & Professional Standards', 'Zero-Tolerance Policy', sf),
          _buildParagraph(
            'TRAIN Z is committed to providing a safe, respectful, and strictly professional fitness coaching environment for all athletes and trainers.',
          ),
          _buildSectionTitle('1. Strictly Professional Fitness Domain', sf),
          _buildParagraph(
            'TRAIN Z is exclusively a personal fitness coaching platform. We enforce a zero-tolerance policy against any form of romantic, dating, or inappropriate social conduct. Any harassment or non-professional solicitation results in immediate and permanent account termination.',
          ),
          _buildSectionTitle('2. Mutual Respect & Punctuality', sf),
          _buildParagraph(
            'Both athletes and trainers must arrive promptly for the scheduled 60-minute session. Safe gym attire and appropriate training footwear are required at all times.',
          ),
          _buildSectionTitle('3. Reporting Violations', sf),
          _buildParagraph(
            'If you experience any form of unprofessional behavior or policy breach, please report the incident immediately via the "Support Requests & Complaints" section in the app.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegalHeader(String title, String subtitle, double sf) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (16.0 * sf).clamp(15.0, 18.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const Divider(height: 24, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, double sf) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Syne',
          fontSize: (13.5 * sf).clamp(12.5, 15.0),
          fontWeight: FontWeight.w700,
          color: kDark,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        height: 1.6,
        color: Color(0xFF4B5563),
      ),
    );
  }
}
