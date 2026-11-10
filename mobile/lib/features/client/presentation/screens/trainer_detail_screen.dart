import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/review_model.dart';
import '../../../../shared/models/trainer_availability_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../../../widgets/book_session_sheet.dart';

/// Detailed coach profile screen for TRAIN Z clients.
/// Displays coach bio, credentials, available slots, client reviews, and direct booking.
class TrainerDetailScreen extends StatelessWidget {
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

  void _openBooking(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final booked = await BookSessionSheet.show(
      context,
      trainerName: trainer.displayName,
      gymName: trainer.gymName,
      trainerId: trainer.uid,
      clientGender: clientGender,
      trainerGender: trainer.gender,
    );

    if (booked == true) {
      onBooked?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.065).clamp(18.0, 28.0);

    // ── STRICT SECURITY GUARD ──
    if (trainer.gender != clientGender) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 54, color: Color(0xFFDC2626)),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'TRAIN Z enforces strict 1-on-1 gender matching.\n${clientGender == Gender.female ? "Female" : "Male"} athletes may only view and book ${clientGender == Gender.female ? "female" : "male"} coaches.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kGrey),
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
          IconButton(
            icon: const Icon(Iconsax.share, color: kDark, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profile link copied: trainz.app/coach/${trainer.uid}')),
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
            // ── Hero Header ──
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
                  Text(
                    trainer.displayName,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (22.0 * sf).clamp(18.0, 26.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    trainer.gymName ?? 'TRAIN Z Certified Coach',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (12.5 * sf).clamp(11.5, 14.0),
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF555555),
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
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Text(
                          trainer.availabilityText,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Metric Badges Row ──
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
                    subtext: 'Verified Coach',
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

            // ── Bio & Coaching Philosophy ──
            _SectionHeading(title: 'COACHING PHILOSOPHY & BIO', sf: sf),
            const SizedBox(height: 8),
            Text(
              trainer.profile.bio != null && trainer.profile.bio!.isNotEmpty
                  ? trainer.profile.bio!
                  : 'Dedicated personal trainer focused on structured progressive overload, nutritional balance, and long-term functional longevity.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.5 * sf).clamp(11.5, 14.0),
                color: const Color(0xFF444444),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // ── Verified Certifications ──
            _SectionHeading(title: 'VERIFIED CREDENTIALS', sf: sf),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trainer.certifications.map((cert) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kLime.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF15803D)),
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

            const SizedBox(height: 20),

            // ── Specializations ──
            _SectionHeading(title: 'SPECIALIZATIONS & TARGET GOALS', sf: sf),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: trainer.specialties.map((spec) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      fontWeight: FontWeight.w500,
                      color: kDark,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Real-Time Availability Schedule ──
            _SectionHeading(title: 'UPCOMING AVAILABILITY & SLOTS', sf: sf),
            const SizedBox(height: 8),

            StreamBuilder<List<TrainerAvailabilityModel>>(
              stream: FirestoreService().streamTrainerAvailability(trainer.uid),
              builder: (context, availSnap) {
                final schedules = availSnap.data ?? [];
                final allSlots = <TimeSlot>[];
                for (final s in schedules) {
                  allSlots.addAll(s.timeSlots);
                }

                if (allSlots.isEmpty) {
                  // Fallback standard slots if trainer hasn't customized yet
                  allSlots.addAll([
                    const TimeSlot(start: '06:00 AM', end: '07:00 AM', isBooked: false),
                    const TimeSlot(start: '07:00 AM', end: '08:00 AM', isBooked: false),
                    const TimeSlot(start: '08:30 AM', end: '09:30 AM', isBooked: false),
                    const TimeSlot(start: '05:00 PM', end: '06:00 PM', isBooked: false),
                    const TimeSlot(start: '06:30 PM', end: '07:30 PM', isBooked: false),
                  ]);
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allSlots.take(6).map((slot) {
                    final isAvailable = !slot.isBooked;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAvailable ? const Color(0xFFF9FAFB) : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAvailable ? const Color(0xFFDDDDDD) : const Color(0xFFCCCCCC),
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

            // ── Client Reviews ──
            _SectionHeading(
              title: 'CLIENT REVIEWS (${trainer.totalReviews})',
              sf: sf,
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<ReviewModel>>(
              stream: FirestoreService().streamTrainerReviews(trainer.uid),
              builder: (context, reviewSnap) {
                final reviews = reviewSnap.data ?? [];

                if (reviews.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No written reviews yet. Be the first athlete to train and leave feedback for this coach!',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
                    ),
                  );
                }

                return Column(
                  children: reviews.take(3).map((r) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: List.generate(
                                  r.rating.round(),
                                  (i) => const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                                ),
                              ),
                              const Text(
                                'Verified Athlete',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.comment,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.5 * sf).clamp(10.5, 13.0),
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 90), // Space for bottom action bar
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
                  const Text('Rate per Session', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey)),
                  Text(
                    '₹${trainer.hourlyRate}',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (18.0 * sf).clamp(16.0, 22.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openBooking(context),
                  icon: const Icon(Iconsax.calendar_add, size: 16, color: kDark),
                  label: const Text(
                    'Book 1-on-1 Session',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLime,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (10.0 * sf).clamp(9.0, 11.5),
            color: kGrey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (14.0 * sf).clamp(12.5, 16.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtext,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (9.5 * sf).clamp(8.5, 11.0),
            color: const Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final double sf;

  const _SectionHeading({required this.title, required this.sf});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Syne',
        fontSize: (11.0 * sf).clamp(10.0, 12.5),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF888888),
        letterSpacing: 0.8,
      ),
    );
  }
}

