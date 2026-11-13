import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/review_service.dart';
import '../../../../shared/models/review_model.dart';
import '../../../../shared/models/trainer_availability_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_package_selection_screen.dart';

/// Detailed Trainer Profile screen for TRAIN Z clients.
/// Displays header, bio, credentials, specializations, services, location,
/// live availability, verified reviews, favourite toggle, and Book Trainer navigation.
class TrainerDetailScreen extends StatefulWidget {
  final TrainerDisplayModel trainer;
  final Gender clientGender;
  final String clientId;
  final VoidCallback? onBooked;

  const TrainerDetailScreen({
    super.key,
    required this.trainer,
    required this.clientGender,
    required this.clientId,
    this.onBooked,
  });

  @override
  State<TrainerDetailScreen> createState() => _TrainerDetailScreenState();
}

class _TrainerDetailScreenState extends State<TrainerDetailScreen> {
  int _selectedDateOffset = 0; // 0 = Today, 1 = Tomorrow, etc.

  void _navigateToPackageSelection(BuildContext context) {
    if (widget.trainer.category == TrainerCategory.professionalTrainer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Professional Trainer packages are coming soon!'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientPackageSelectionScreen(
          trainer: widget.trainer,
          clientGender: widget.clientGender,
          clientId: widget.clientId,
        ),
      ),
    );
  }

  Future<void> _showReportReviewDialog(BuildContext context, ReviewModel review) async {
    String selectedReason = 'Inappropriate or Offensive Language';
    final detailsController = TextEditingController();
    bool isReporting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag, color: Color(0xFFDC2626), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Report Review',
                    style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help keep TRAIN Z a professional training community. Please tell us why you are reporting this review:',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Inappropriate or Offensive Language',
                      child: Text('Inappropriate or Offensive Language', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'Harassment or Spam',
                      child: Text('Harassment or Spam', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'False or Misleading Information',
                      child: Text('False or Misleading Information', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'Privacy Violation',
                      child: Text('Privacy Violation', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text('Other Policy Violation', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedReason = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
              ),
              ElevatedButton(
                onPressed: isReporting
                    ? null
                    : () async {
                        setDialogState(() => isReporting = true);
                        try {
                          await ReviewService.instance.reportReview(
                            reviewId: review.id,
                            reporterId: widget.clientId,
                            reason: selectedReason,
                            details: detailsController.text,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted. Thank you for keeping our community safe.'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          }
                        } catch (_) {
                          setDialogState(() => isReporting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isReporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Report', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.065).clamp(18.0, 28.0);
    final trainer = widget.trainer;

    // ── STRICT SECURITY GUARD: 1-ON-1 GENDER MATCHING ──
    if (trainer.gender != widget.clientGender) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: kDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, size: 52, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (22.0 * sf).clamp(18.0, 26.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This trainer profile is not eligible for booking with your current account profile. Only verified eligible personal trainers can be booked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.5 * sf).clamp(11.5, 14.0),
                    color: const Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Return to Trainers',
                    style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: kDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          trainer.displayName,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (16.0 * sf).clamp(15.0, 18.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          // ── Favourite Toggle Button (Synced with Firestore) ──
          StreamBuilder<bool>(
            stream: FirestoreService().streamIsTrainerFavorite(
              clientId: widget.clientId,
              trainerId: trainer.uid,
            ),
            builder: (context, favSnap) {
              final isFav = favSnap.data ?? false;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? const Color(0xFFEF4444) : kDark,
                  size: 22,
                ),
                tooltip: isFav ? 'Remove from Favourites' : 'Save to Favourites',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final nowFav = await FirestoreService().toggleFavoriteTrainer(
                    clientId: widget.clientId,
                    trainerId: trainer.uid,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nowFav
                              ? 'Saved ${trainer.displayName} to your favourites.'
                              : 'Removed ${trainer.displayName} from favourites.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),

          // ── Share Profile Button ──
          IconButton(
            icon: const Icon(Iconsax.share, color: kDark, size: 20),
            tooltip: 'Share Trainer Profile',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://trainz.app/trainer/${trainer.uid}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trainer profile link copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Profile Header ──
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: (52.0 * sf).clamp(44.0, 60.0),
                    backgroundColor: const Color(0xFF111111),
                    backgroundImage: (trainer.photoUrl != null && trainer.photoUrl!.isNotEmpty)
                        ? NetworkImage(trainer.photoUrl!)
                        : null,
                    child: (trainer.photoUrl == null || trainer.photoUrl!.isEmpty)
                        ? Text(
                            trainer.displayName.isNotEmpty ? trainer.displayName[0].toUpperCase() : 'C',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (36.0 * sf).clamp(30.0, 42.0),
                              fontWeight: FontWeight.w800,
                              color: kLime,
                            ),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified, size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          trainer.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (22.0 * sf).clamp(18.0, 26.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: Color(0xFF16A34A)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    trainer.gymName ?? 'Certified Personal Trainer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (12.5 * sf).clamp(11.5, 14.0),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: trainer.category == TrainerCategory.advancedTrainer
                          ? const Color(0xFFDCFCE7)
                          : trainer.category == TrainerCategory.professionalTrainer
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trainer.category == TrainerCategory.advancedTrainer
                          ? 'Advanced Trainer'
                          : trainer.category == TrainerCategory.professionalTrainer
                              ? 'Professional Trainer • Coming Soon'
                              : 'Trainer',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: trainer.category == TrainerCategory.advancedTrainer
                            ? const Color(0xFF15803D)
                            : trainer.category == TrainerCategory.professionalTrainer
                                ? const Color(0xFFB45309)
                                : kDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.location, size: 14, color: kGrey),
                      const SizedBox(width: 4),
                      Text(
                        trainer.displayLocation,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.5 * sf).clamp(10.5, 13.0),
                          color: kGrey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: trainer.hasAvailableSlots
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: trainer.hasAvailableSlots
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: trainer.hasAvailableSlots
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trainer.availabilityText,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: trainer.hasAvailableSlots
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 2. Metric Badges Row ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MetricPill(
                    label: 'Rating',
                    value: '★ ${trainer.ratingText}',
                    subtext: '${trainer.totalReviews} reviews',
                    sf: sf,
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFFE5E5E5)),
                  _MetricPill(
                    label: 'Experience',
                    value: trainer.experienceText,
                    subtext: 'Verified Trainer',
                    sf: sf,
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFFE5E5E5)),
                  _MetricPill(
                    label: 'Per Session',
                    value: '₹${trainer.hourlyRate}',
                    subtext: '60 Minutes',
                    sf: sf,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── 3. About Trainer & Biography ──
            _SectionHeading(title: 'ABOUT TRAINER & BACKGROUND', sf: sf),
            const SizedBox(height: 8),
            Text(
              trainer.profile.bio != null && trainer.profile.bio!.isNotEmpty
                  ? trainer.profile.bio!
                  : 'Dedicated personal fitness trainer specializing in structured progressive overload, nutritional balance, movement longevity, and athletic conditioning.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.5 * sf).clamp(11.5, 14.0),
                color: const Color(0xFF444444),
                height: 1.55,
              ),
            ),

            const SizedBox(height: 14),

            // Coaching Principles Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                children: [
                  _buildPrincipleRow(
                    icon: Icons.check_circle_outline,
                    title: 'Progressive Overload Methodology',
                    subtitle: 'Weekly tracked weight, volume, and recovery progressions.',
                    sf: sf,
                  ),
                  const SizedBox(height: 10),
                  _buildPrincipleRow(
                    icon: Icons.fitness_center_outlined,
                    title: 'Compound Lift Biomechanics',
                    subtitle: 'Precision instruction for squat, bench, deadlift, and accessories.',
                    sf: sf,
                  ),
                  const SizedBox(height: 10),
                  _buildPrincipleRow(
                    icon: Icons.shield_outlined,
                    title: 'Injury Prevention & Mobility',
                    subtitle: 'Dedicated warm-up, active mobility, and joint health longevity.',
                    sf: sf,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── 4. Verified Qualifications & Certifications ──
            if (trainer.verifiedQualifications.isNotEmpty || trainer.certifications.isNotEmpty) ...[
              _SectionHeading(title: 'VERIFIED CREDENTIALS & CERTIFICATIONS', sf: sf),
              const SizedBox(height: 8),
              if (trainer.verifiedQualifications.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: trainer.verifiedQualifications.map((vq) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kLime.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.verified_outlined, size: 16, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vq.certificateName,
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (12.5 * sf).clamp(11.5, 14.0),
                                    fontWeight: FontWeight.w700,
                                    color: kDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${vq.courseName} • ${vq.issuingOrganization} (${vq.yearOfCompletion})',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (11.0 * sf).clamp(10.0, 12.0),
                                    color: const Color(0xFF444444),
                                  ),
                                ),
                                if (vq.qualificationDetails != null && vq.qualificationDetails!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    vq.qualificationDetails!,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: (10.5 * sf).clamp(9.5, 11.5),
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: trainer.certifications.map((cert) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kLime.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_outlined, size: 15, color: Color(0xFF15803D)),
                          const SizedBox(width: 6),
                          Text(
                            cert,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.5),
                              fontWeight: FontWeight.w600,
                              color: kDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 22),
            ],

            // ── 5. Specializations ──
            _SectionHeading(title: 'FITNESS SPECIALIZATIONS', sf: sf),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: trainer.specialties.map((spec) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Text(
                    spec,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── 6. Training Services & Available Formats ──
            _SectionHeading(title: 'TRAINING SERVICES OFFERED', sf: sf),
            const SizedBox(height: 8),

            _buildServiceCard(
              title: '1-on-1 In-Person Coaching',
              format: 'Private In-Person',
              duration: '60 Minutes',
              description: 'Custom hands-on personal training tailored specifically to your fitness level, goals, and biomechanical parameters.',
              icon: Iconsax.personalcard,
              sf: sf,
            ),
            const SizedBox(height: 10),
            _buildServiceCard(
              title: 'Biomechanical Form Correction',
              format: 'Compound Lift Focus',
              duration: 'Included in Session',
              description: 'Real-time barbell, dumbbell, and machine movement analysis to optimize muscular engagement and prevent injury.',
              icon: Iconsax.weight,
              sf: sf,
            ),
            const SizedBox(height: 10),
            _buildServiceCard(
              title: 'Custom Program & Volume Tracking',
              format: 'Weekly Periodization',
              duration: 'Ongoing Strategy',
              description: 'Continuous progression tracking in TRAIN Z to ensure consistent progressive overload and sustained results.',
              icon: Iconsax.chart_2,
              sf: sf,
            ),
            const SizedBox(height: 10),
            _buildServiceCard(
              title: 'Body Composition & Nutrition Guidance',
              format: 'Lifestyle Alignment',
              duration: 'Nutrition Coaching',
              description: 'Targeted caloric and nutritional guidance aligned with your hypertrophy, fat loss, or stamina goals.',
              icon: Iconsax.activity,
              sf: sf,
            ),

            const SizedBox(height: 24),

            // ── 7. Service Location & Privacy Guarantee ──
            _SectionHeading(title: 'SERVICE LOCATION & VENUES', sf: sf),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
                      const Icon(Iconsax.location, color: kDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trainer.displayLocation,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (14.0 * sf).clamp(13.0, 16.0),
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Available for 1-on-1 training across commercial gyms, residential clubhouses, and private partner studios in ${trainer.displayLocation}.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(10.5, 13.0),
                      color: const Color(0xFF555555),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Privacy Shield Callout
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Strict Privacy: Client home addresses and trainer personal phone numbers are never shared or made public.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (10.0 * sf).clamp(9.0, 11.5),
                              color: const Color(0xFF4B5563),
                              fontWeight: FontWeight.w500,
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

            // ── 8. Real-Time Availability Schedule ──
            _SectionHeading(title: 'UPCOMING DATES & LIVE SLOTS', sf: sf),
            const SizedBox(height: 8),

            // Date selector tabs: Today, Tomorrow, Day 3, Day 4
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(4, (index) {
                  final now = DateTime.now().add(Duration(days: index));
                  final label = index == 0
                      ? 'Today'
                      : index == 1
                          ? 'Tomorrow'
                          : '${now.day}/${now.month}';
                  final isSelected = _selectedDateOffset == index;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: kDark,
                      backgroundColor: const Color(0xFFF7F7F7),
                      labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.0 * sf).clamp(10.0, 12.5),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : kDark,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? kDark : const Color(0xFFE5E5E5),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDateOffset = index);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 12),

            StreamBuilder<List<TrainerAvailabilityModel>>(
              stream: FirestoreService().streamTrainerAvailability(trainer.uid),
              builder: (context, availSnap) {
                final schedules = availSnap.data ?? [];
                final allSlots = <TimeSlot>[];
                for (final s in schedules) {
                  allSlots.addAll(s.timeSlots);
                }

                if (allSlots.isEmpty) {
                  allSlots.addAll([
                    const TimeSlot(start: '06:00 AM', end: '07:00 AM', isBooked: false),
                    const TimeSlot(start: '07:00 AM', end: '08:00 AM', isBooked: false),
                    const TimeSlot(start: '08:30 AM', end: '09:30 AM', isBooked: true),
                    const TimeSlot(start: '05:00 PM', end: '06:00 PM', isBooked: false),
                    const TimeSlot(start: '06:30 PM', end: '07:30 PM', isBooked: false),
                  ]);
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allSlots.map((slot) {
                    final isAvailable = !slot.isBooked;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isAvailable ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAvailable ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: isAvailable ? kDark : kGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${slot.start} - ${slot.end}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.5),
                              fontWeight: isAvailable ? FontWeight.w600 : FontWeight.w400,
                              color: isAvailable ? kDark : kGrey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAvailable ? const Color(0xFF16A34A) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── 9. Verified Client Reviews ──
            StreamBuilder<List<ReviewModel>>(
              stream: ReviewService.instance.streamTrainerReviews(trainer.uid),
              builder: (context, reviewSnap) {
                final reviews = reviewSnap.data ?? [];
                final reviewCount = reviews.length;
                final avgRating = reviewCount > 0
                    ? ((reviews.fold<double>(0.0, (acc, r) => acc + r.rating) / reviewCount) * 10).round() / 10
                    : trainer.ratingAvg;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeading(
                      title: 'VERIFIED CLIENT REVIEWS ($reviewCount)',
                      sf: sf,
                    ),
                    const SizedBox(height: 10),

                    if (reviews.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Iconsax.star, size: 28, color: Color(0xFFB0B0B0)),
                            const SizedBox(height: 8),
                            Text(
                              'No written reviews yet',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (13.5 * sf).clamp(12.5, 15.0),
                                fontWeight: FontWeight.w700,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Be the first athlete to complete a session and leave a review for this trainer!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Aggregate Rating Summary Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      avgRating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontFamily: 'Syne',
                                        fontSize: (28.0 * sf).clamp(24.0, 32.0),
                                        fontWeight: FontWeight.w800,
                                        color: kDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ 5.0',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: (11.0 * sf).clamp(10.0, 12.0),
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 16,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Container(width: 1, height: 44, color: const Color(0xFFE5E7EB)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$reviewCount Verified Athlete ${reviewCount == 1 ? 'Review' : 'Reviews'}',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (12.5 * sf).clamp(11.5, 13.5),
                                      fontWeight: FontWeight.w700,
                                      color: kDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ratings submitted following verified 60-minute training sessions.',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: (10.0 * sf).clamp(9.0, 11.0),
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List of Review Cards
                      ...reviews.take(10).map((r) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: kDark,
                                    backgroundImage: r.clientPhotoUrl != null && r.clientPhotoUrl!.isNotEmpty
                                        ? NetworkImage(r.clientPhotoUrl!)
                                        : null,
                                    child: r.clientPhotoUrl == null || r.clientPhotoUrl!.isEmpty
                                        ? Text(
                                            r.clientName.isNotEmpty ? r.clientName[0].toUpperCase() : 'A',
                                            style: const TextStyle(
                                              fontFamily: 'Syne',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: kLime,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.clientName,
                                          style: TextStyle(
                                            fontFamily: 'Syne',
                                            fontSize: (12.5 * sf).clamp(11.5, 13.5),
                                            fontWeight: FontWeight.w700,
                                            color: kDark,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.verified, size: 11, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 3),
                                            const Text(
                                              'Verified Athlete',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 9.5,
                                                color: Color(0xFF16A34A),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '• ${r.formattedDate}',
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 9.5,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD97706)),
                                            const SizedBox(width: 2),
                                            Text(
                                              r.ratingText,
                                              style: const TextStyle(
                                                fontFamily: 'Syne',
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.flag_outlined, size: 15, color: Color(0xFF9CA3AF)),
                                        tooltip: 'Report Review',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () => _showReportReviewDialog(context, r),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (r.categories.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: r.categories.map((cat) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cat,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                '"${r.comment}"',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (11.5 * sf).clamp(10.5, 12.5),
                                  color: const Color(0xFF333333),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 100), // Space for sticky bottom bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Starting from', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey)),
                  Text(
                    '₹${trainer.hourlyRate} / Session',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (16.0 * sf).clamp(15.0, 20.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Prominent "Book Trainer" button (or "Coming Soon" for Professional Trainer)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isProfessional = trainer.category == TrainerCategory.professionalTrainer;
                    return ElevatedButton.icon(
                      onPressed: () => _navigateToPackageSelection(context),
                      icon: Icon(
                        isProfessional ? Icons.timer_outlined : Iconsax.calendar_tick,
                        size: 18,
                        color: isProfessional ? const Color(0xFF92400E) : kDark,
                      ),
                      label: Text(
                        isProfessional ? 'Coming Soon' : 'Book Trainer',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isProfessional ? const Color(0xFF92400E) : kDark,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isProfessional ? const Color(0xFFFEF3C7) : kLime,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrincipleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required double sf,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF16A34A)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (10.0 * sf).clamp(9.0, 11.5),
                  color: kGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String format,
    required String duration,
    required String description,
    required IconData icon,
    required double sf,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: kDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: kLime),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (13.0 * sf).clamp(12.0, 14.5),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          format,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: kGrey)),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            color: kGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(10.0, 12.5),
              color: const Color(0xFF555555),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final double sf;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.subtext,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (9.0 * sf).clamp(8.0, 10.5),
            fontWeight: FontWeight.w600,
            color: kGrey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (15.0 * sf).clamp(13.5, 17.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        Text(
          subtext,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (9.5 * sf).clamp(8.5, 11.0),
            color: kGrey,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final double sf;

  const _SectionHeading({
    required this.title,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Syne',
        fontSize: (11.5 * sf).clamp(10.5, 13.0),
        fontWeight: FontWeight.w800,
        color: kDark,
        letterSpacing: 1.1,
      ),
    );
  }
}
