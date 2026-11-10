import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Card displaying a client's confirmed upcoming workout session with cancellation handling.
class ClientUpcomingSessionCard extends StatelessWidget {
  final BookingModel booking;
  final String clientId;
  final VoidCallback? onCancelled;

  const ClientUpcomingSessionCard({
    super.key,
    required this.booking,
    required this.clientId,
    this.onCancelled,
  });

  void _showCancelDialog(BuildContext context) {
    final sf = scaleFactor(context);
    final now = DateTime.now();
    final difference = booking.sessionDate.difference(now);
    final hoursRemaining = difference.inHours;
    final isEarly = hoursRemaining >= AppConstants.cancellationWindowHours;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEarly ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.close_circle,
                  color: isEarly ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cancel Session?',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (18.0 * sf).clamp(16.0, 20.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session on ${_formatDate(booking.sessionDate)} at ${booking.startTime}.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEarly ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEarly ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isEarly ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      size: 18,
                      color: isEarly ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEarly
                            ? '12+ Hours Policy Met: Your 1 session credit will be refunded to your available balance.'
                            : 'Late Cancellation Warning (< 12 hours): Your session credit will be forfeited per platform policy.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isEarly ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Keep Session', style: TextStyle(fontFamily: 'Poppins', color: kGrey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                HapticFeedback.heavyImpact();
                final returned = await FirestoreService().cancelBookingAsClient(
                  bookingId: booking.id,
                  clientId: clientId,
                );

                if (!context.mounted) return;
                onCancelled?.call();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      returned
                          ? 'Session cancelled. 1 session credit returned to your balance.'
                          : 'Session cancelled. Credit forfeited due to late cancellation (< 12 hours).',
                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                    ),
                    backgroundColor: returned ? const Color(0xFF16A34A) : const Color(0xFF1E1E24),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Confirm Cancellation',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Workout type & Status badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.displayWorkoutType,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.5 * sf).clamp(13.0, 16.5),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      booking.status == BookingStatus.confirmed ? 'CONFIRMED' : booking.status.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Trainer Info Row ──
          Row(
            children: [
              const Icon(Iconsax.user, size: 15, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Coach: ${booking.displayTrainerName}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Date & Time Row ──
          Row(
            children: [
              const Icon(Iconsax.calendar_1, size: 15, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text(
                '${_formatDate(booking.sessionDate)} • ${booking.startTime} - ${booking.endTime}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  color: const Color(0xFF555555),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (booking.meetingLocation != null && booking.meetingLocation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Iconsax.location, size: 15, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.meetingLocation!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(10.5, 13.0),
                      color: kGrey,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── Action Row: Cancel with policy notice ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '60-min personal session',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (10.5 * sf).clamp(9.5, 12.0),
                  color: kGrey,
                ),
              ),
              InkWell(
                onTap: () => _showCancelDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: const [
                      Icon(Iconsax.close_circle, size: 13, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

