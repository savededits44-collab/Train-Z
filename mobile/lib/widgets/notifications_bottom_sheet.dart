import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../services/notification_service.dart';
import '../shared/models/notification_model.dart';
import 'app_widgets.dart';

/// Interactive bottom sheet presenting the user's live real-time notifications.
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final h = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.78),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (18.0 * sf).clamp(16.0, 22.0),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: NotificationService.instance,
                      builder: (context, _) {
                        final unread = NotificationService.instance.unreadCount;
                        if (unread == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread New',
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    NotificationService.instance.markAllAsRead();
                  },
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),

          // Notification List
          Expanded(
            child: ListenableBuilder(
              listenable: NotificationService.instance,
              builder: (context, _) {
                final list = NotificationService.instance.notifications;
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: kField,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.notification, size: 36, color: kGrey),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Live updates on your bookings, payments, and schedules will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _NotificationTile(item: item, sf: sf);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel item;
  final double sf;

  const _NotificationTile({required this.item, required this.sf});

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (item.type) {
      case 'BOOKING_RECEIVED':
        icon = Iconsax.calendar_1;
        iconColor = const Color(0xFFD97706);
        iconBg = const Color(0xFFFEF3C7);
        break;
      case 'BOOKING_CONFIRMED':
        icon = Iconsax.calendar_tick;
        iconColor = const Color(0xFF16A34A);
        iconBg = const Color(0xFFDCFCE7);
        break;
      case 'BOOKING_REJECTED':
      case 'BOOKING_CANCELLED':
        icon = Iconsax.calendar_remove;
        iconColor = const Color(0xFFDC2626);
        iconBg = const Color(0xFFFEE2E2);
        break;
      case 'BOOKING_RESCHEDULED':
        icon = Iconsax.calendar_edit;
        iconColor = const Color(0xFF7C3AED);
        iconBg = const Color(0xFFEDE9FE);
        break;
      case 'PAYMENT_SUCCESS':
      case 'PACKAGE_PURCHASED':
      case 'PACKAGE_ACTIVATED':
        icon = Iconsax.card_tick;
        iconColor = const Color(0xFF059669);
        iconBg = const Color(0xFFD1FAE5);
        break;
      case 'WORKOUT_COMPLETED':
        icon = Iconsax.weight;
        iconColor = kDark;
        iconBg = kLime;
        break;
      default:
        icon = Iconsax.notification;
        iconColor = kDark;
        iconBg = kField;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (!item.isRead) {
          NotificationService.instance.markAsRead(item.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6),
            width: isUnread ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
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
                          item.title,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (13.5 * sf).clamp(12.0, 15.0),
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: kDark,
                          ),
                        ),
                      ),
                      if (isUnread)
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
                    item.body,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(10.5, 12.5),
                      color: isUnread ? const Color(0xFF374151) : kGrey,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(item.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
