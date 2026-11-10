import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../../../widgets/book_session_sheet.dart';

/// Premium card displaying an approved, gender-matched personal trainer.
class ClientTrainerCard extends StatelessWidget {
  final TrainerDisplayModel trainer;
  final Gender clientGender;
  final VoidCallback? onBooked;

  const ClientTrainerCard({
    super.key,
    required this.trainer,
    required this.clientGender,
    this.onBooked,
  });

  void _openBookingSheet(BuildContext context) async {
    HapticFeedback.lightImpact();
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openBookingSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Avatar, Name, Verified Badge & Rating ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: (26.0 * sf).clamp(22.0, 30.0),
                      backgroundColor: const Color(0xFF111111),
                      backgroundImage: (trainer.photoUrl != null && trainer.photoUrl!.isNotEmpty)
                          ? NetworkImage(trainer.photoUrl!)
                          : null,
                      child: (trainer.photoUrl == null || trainer.photoUrl!.isEmpty)
                          ? Text(
                              trainer.displayName.isNotEmpty
                                  ? trainer.displayName[0].toUpperCase()
                                  : 'C',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (18.0 * sf).clamp(16.0, 22.0),
                                fontWeight: FontWeight.w800,
                                color: kLime,
                              ),
                            )
                          : null,
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
                                  trainer.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (15.5 * sf).clamp(14.0, 17.5),
                                    fontWeight: FontWeight.w800,
                                    color: kDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trainer.gymName ?? 'TRAIN Z Certified Coach',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.5 * sf).clamp(10.5, 13.0),
                              color: kGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rating Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            trainer.ratingText,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (11.5 * sf).clamp(10.5, 13.0),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '(${trainer.totalReviews})',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (9.5 * sf).clamp(8.5, 11.0),
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Specialties & Experience Pills ──
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kLime.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        trainer.experienceText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (10.0 * sf).clamp(9.0, 11.5),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                    ),
                    ...trainer.specialties.take(3).map((spec) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: Text(
                            spec,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (10.0 * sf).clamp(9.0, 11.5),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF555555),
                            ),
                          ),
                        )),
                  ],
                ),

                if (trainer.profile.bio != null && trainer.profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    trainer.profile.bio!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      color: const Color(0xFF666666),
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Bottom Action Row: Pricing & Book CTA ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Starting from',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (10.0 * sf).clamp(9.0, 11.5),
                            color: kGrey,
                          ),
                        ),
                        Text(
                          '₹${trainer.hourlyRate} / Session',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (13.5 * sf).clamp(12.5, 15.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openBookingSheet(context),
                      icon: const Icon(Iconsax.calendar_add, size: 16, color: kDark),
                      label: const Text(
                        'Book Session',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLime,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

