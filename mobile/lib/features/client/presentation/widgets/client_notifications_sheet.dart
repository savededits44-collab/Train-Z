import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../screens/client_booking_detail_screen.dart';

/// Modal bottom sheet displaying real-time booking confirmations,
/// upcoming session reminders, cancellation updates, and rescheduling alerts.
class ClientNotificationsSheet extends StatelessWidget {
  final String clientId;

  const ClientNotificationsSheet({
    super.key,
    required this.clientId,
  });

  static Future<void> show(BuildContext context, {required String clientId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientNotificationsSheet(clientId: clientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final firestoreService = FirestoreService();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.notification, color: kLime, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Session Notifications',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (16.0 * sf).clamp(15.0, 18.0),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: kDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Notifications List
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: firestoreService.streamUserNotifications(clientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kDark),
                  );
                }

                final notifs = snapshot.data ?? [];

                if (notifs.isEmpty) {
                  return _buildEmptyState(context, sf);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: notifs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = notifs[index];
                    return _buildNotificationCard(context, item, sf, firestoreService);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notif,
    double sf,
    FirestoreService firestoreService,
  ) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (notif.type) {
      case 'BOOKING_CONFIRMED':
        icon = Iconsax.calendar_tick;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        break;
      case 'BOOKING_RESCHEDULED':
        icon = Iconsax.clock;
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        break;
      case 'BOOKING_CANCELLED':
        icon = Iconsax.calendar_remove;
        iconBg = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFDC2626);
        break;
      case 'UPCOMING_REMINDER':
        icon = Iconsax.notification;
        iconBg = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF9333EA);
        break;
      default:
        icon = Iconsax.info_circle;
        iconBg = const Color(0xFFF3F4F6);
        iconColor = kDark;
    }

    final dateStr = notif.createdAt != null
        ? '${notif.createdAt!.day} ${_monthName(notif.createdAt!.month)} • ${_formatTime(notif.createdAt!)}'
        : 'Recent update';

    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (!notif.isRead) {
          await firestoreService.markNotificationRead(notif.id);
        }

        final bookingId = notif.data['bookingId'] as String?;
        if (bookingId != null && bookingId.isNotEmpty && context.mounted) {
          final booking = await firestoreService.getBooking(bookingId);
          if (booking != null && context.mounted) {
            Navigator.pop(context); // Close sheet
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientBookingDetailScreen(booking: booking),
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? const Color(0xFFEEEEEE) : kDark.withValues(alpha: 0.15),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (12.5 * sf).clamp(11.5, 14.0),
                            fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.0),
                      color: const Color(0xFF4B5563),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (9.5 * sf).clamp(9.0, 10.5),
                      color: const Color(0xFF9CA3AF),
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

  Widget _buildEmptyState(BuildContext context, double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.notification_bing, size: 36, color: kDark),
          ),
          const SizedBox(height: 16),
          Text(
            'No New Notifications',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (15.0 * sf).clamp(14.0, 17.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Booking confirmations, 12-hour session reminders, cancellation updates, and rescheduling alerts will appear here in real time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10.5, 12.5),
              color: kGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // Information guide cards
          _buildInfoGuide(
            icon: Iconsax.calendar_tick,
            title: 'Booking Confirmations',
            description: 'Notified instantly once session payment is verified on the backend.',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoGuide(
            icon: Iconsax.clock,
            title: 'Rescheduling Updates',
            description: 'Subject to trainer availability with automatic double-booking locks.',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoGuide(
            icon: Iconsax.calendar_remove,
            title: '12-Hour Cancellation Rule',
            description: '>= 12h: session credit returned. < 12h: session credit forfeited.',
            sf: sf,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGuide({
    required IconData icon,
    required String title,
    required String description,
    required double sf,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (11.5 * sf).clamp(10.5, 12.5),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                Text(
                  description,
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
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }
}
