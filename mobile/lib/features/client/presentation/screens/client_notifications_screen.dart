import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../shared/models/conversation_model.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_booking_detail_screen.dart';
import 'client_chat_screen.dart';

/// Comprehensive Client Notification Centre for TRAIN Z.
/// Displays real-time updates for bookings, session reminders, trainer messages,
/// and payment confirmations with deep navigation and mark-as-read functionality.
class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  int _selectedFilterIndex = 0; // 0 = All, 1 = Unread

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    return ListenableBuilder(
      listenable: _notificationService,
      builder: (context, _) {
        final allNotifs = _notificationService.notifications;
        final unreadNotifs = allNotifs.where((n) => !n.isRead).toList();
        final displayList = _selectedFilterIndex == 0 ? allNotifs : unreadNotifs;
        final unreadCount = unreadNotifs.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Notification Centre',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (17.0 * sf).clamp(16.0, 19.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            actions: [
              if (unreadCount > 0)
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _notificationService.markAllAsRead();
                  },
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(10.5, 13.0),
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    _buildFilterChip('All (${allNotifs.length})', 0, sf),
                    const SizedBox(width: 8),
                    _buildFilterChip('Unread ($unreadCount)', 1, sf),
                  ],
                ),
              ),
            ),
          ),
          body: displayList.isEmpty
              ? _buildEmptyState(sf, isUnreadFilter: _selectedFilterIndex == 1)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    return _buildNotificationCard(item, sf);
                  },
                ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, int index, double sf) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kDark : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (11.5 * sf).clamp(10.5, 12.5),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? kLime : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, double sf) {
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
      case 'CHAT_MESSAGE':
        icon = Iconsax.message;
        iconBg = const Color(0xFFE0F2FE);
        iconColor = const Color(0xFF0284C7);
        break;
      case 'PAYMENT_CONFIRMED':
      case 'PACKAGE_PURCHASED':
        icon = Iconsax.wallet_check;
        iconBg = const Color(0xFFECFDF5);
        iconColor = const Color(0xFF059669);
        break;
      default:
        icon = Iconsax.info_circle;
        iconBg = const Color(0xFFF3F4F6);
        iconColor = kDark;
    }

    final dateStr = notif.createdAt != null ? _formatDateTime(notif.createdAt!) : 'Recent update';

    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? const Color(0xFFEEEEEE) : kDark.withValues(alpha: 0.18),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: notif.isRead ? 0.02 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                            fontSize: (13.0 * sf).clamp(12.0, 14.5),
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
                      fontSize: (11.0 * sf).clamp(10.5, 12.0),
                      color: const Color(0xFF4B5563),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (9.5 * sf).clamp(9.0, 10.5),
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (notif.isBookingRelated || notif.isChatRelated)
                        Row(
                          children: [
                            Text(
                              notif.isChatRelated ? 'Open Chat' : 'View Booking',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (10.0 * sf).clamp(9.5, 11.0),
                                fontWeight: FontWeight.w600,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right, size: 14, color: kDark),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notif) async {
    HapticFeedback.lightImpact();
    if (!notif.isRead) {
      await _notificationService.markAsRead(notif.id);
    }

    if (!mounted) return;

    // 1. Chat navigation
    if (notif.isChatRelated || notif.conversationId != null) {
      final convId = notif.conversationId ?? '';
      String currentUid = '';
      String clientName = 'Athlete';
      try {
        final user = FirebaseAuth.instance.currentUser;
        currentUid = user?.uid ?? '';
        clientName = user?.displayName ?? 'Athlete';
      } catch (_) {}
      final trainerId = notif.trainerId ?? '';
      final trainerName = notif.trainerName ?? 'Personal Trainer';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientChatScreen(
            conversation: ConversationModel(
              id: convId.isNotEmpty ? convId : ConversationModel.generateId(currentUid, trainerId),
              clientId: currentUid,
              trainerId: trainerId,
              trainerName: trainerName,
              clientName: clientName,
            ),
          ),
        ),
      );
      return;
    }

    // 2. Booking navigation
    final bookingId = notif.bookingId;
    if (bookingId != null && bookingId.isNotEmpty) {
      try {
        final booking = await FirestoreService().getBooking(bookingId);
        if (booking != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientBookingDetailScreen(booking: booking),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error navigating to booking: $e');
      }
    }
  }

  Widget _buildEmptyState(double sf, {required bool isUnreadFilter}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnreadFilter ? Iconsax.tick_circle : Iconsax.notification_bing,
                size: 42,
                color: kDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isUnreadFilter ? 'All Caught Up' : 'No Notifications Yet',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (16.0 * sf).clamp(15.0, 18.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isUnreadFilter
                  ? 'You have read all your notifications.'
                  : 'You will receive real-time updates for booking confirmations, reminders, and trainer messages here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.5 * sf).clamp(10.5, 12.5),
                color: kGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final timeStr = _formatTime(dt);

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today • $timeStr';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Yesterday • $timeStr';
    } else {
      return '${dt.day} ${_monthName(dt.month)} • $timeStr';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }
}
