import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../shared/models/conversation_model.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_account_security_screen.dart';
import 'client_booking_detail_screen.dart';
import 'client_chat_screen.dart';
import 'client_payment_history_screen.dart';
import 'client_support_tickets_screen.dart';

/// Comprehensive Client Notification Centre for TRAIN Z.
/// Displays real-time updates for bookings, session reminders, trainer messages,
/// package & payment records, reviews, support updates, and platform announcements.
class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;

  String _selectedCategory = 'All';
  bool _showOnlyUnread = false;

  static const List<String> _categories = [
    'All',
    'Bookings',
    'Sessions and reminders',
    'Trainer messages',
    'Packages and payments',
    'Reviews and feedback',
    'Support updates',
    'Platform announcements',
  ];

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    return ListenableBuilder(
      listenable: _notificationService,
      builder: (context, _) {
        final allNotifs = _notificationService.notifications;
        final unreadTotal = allNotifs.where((n) => !n.isRead).length;

        // Apply filters
        var filteredList = allNotifs;
        if (_selectedCategory != 'All') {
          filteredList = filteredList.where((n) => n.category == _selectedCategory).toList();
        }
        if (_showOnlyUnread) {
          filteredList = filteredList.where((n) => !n.isRead).toList();
        }

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
              if (unreadTotal > 0)
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
              preferredSize: const Size.fromHeight(88),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Column(
                  children: [
                    // Row 1: Unread toggle & total counter
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredList.length} ${filteredList.length == 1 ? "notification" : "notifications"}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.0),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _showOnlyUnread = !_showOnlyUnread);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _showOnlyUnread ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showOnlyUnread ? Icons.check_circle : Icons.circle_outlined,
                                    size: 13,
                                    color: _showOnlyUnread ? Colors.white : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Unread ($unreadTotal)',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: (10.5 * sf).clamp(9.5, 11.5),
                                      fontWeight: _showOnlyUnread ? FontWeight.w600 : FontWeight.w500,
                                      color: _showOnlyUnread ? Colors.white : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Row 2: Horizontal scrollable categories
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final cat = _categories[idx];
                          final isSelected = _selectedCategory == cat;

                          // Count for this category
                          final catCount = cat == 'All'
                              ? allNotifs.length
                              : allNotifs.where((n) => n.category == cat).length;
                          final chipLabel = cat == 'All'
                              ? 'All (${allNotifs.length})'
                              : (catCount > 0 ? '$cat ($catCount)' : cat);

                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? kDark : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                chipLabel,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (11.0 * sf).clamp(10.0, 12.0),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? kLime : const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: filteredList.isEmpty
              ? _buildEmptyState(sf)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return _buildDismissibleNotificationCard(item, sf);
                  },
                ),
        );
      },
    );
  }

  Widget _buildDismissibleNotificationCard(NotificationModel notif, double sf) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _notificationService.deleteNotification(notif.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notification removed',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      child: _buildNotificationCard(notif, sf),
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
      case 'PAYMENT_FAILED':
        icon = Iconsax.card_remove;
        iconBg = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFDC2626);
        break;
      case 'SUPPORT_TICKET_UPDATE':
      case 'SUPPORT_RESPONSE':
        icon = Iconsax.ticket;
        iconBg = const Color(0xFFECFEFF);
        iconColor = const Color(0xFF0891B2);
        break;
      case 'REVIEW_REQUEST':
      case 'REVIEW_RECEIVED':
        icon = Iconsax.star;
        iconBg = const Color(0xFFFFFBEB);
        iconColor = const Color(0xFFD97706);
        break;
      case 'SECURITY_ALERT':
      case 'ACCOUNT_SECURITY':
        icon = Iconsax.shield_tick;
        iconBg = const Color(0xFFEEF2FF);
        iconColor = const Color(0xFF4F46E5);
        break;
      default:
        icon = Iconsax.info_circle;
        iconBg = const Color(0xFFF3F4F6);
        iconColor = kDark;
    }

    final dateStr = notif.createdAt != null ? _formatDateTime(notif.createdAt!) : 'Recent update';
    final ref = notif.referenceLabel;

    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
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

                  // Reference label chip & action button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (ref != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                ref,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (9.0 * sf).clamp(8.5, 10.0),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (9.5 * sf).clamp(9.0, 10.5),
                              color: const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      _buildActionIndicator(notif, sf),
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

  Widget _buildActionIndicator(NotificationModel notif, double sf) {
    String label = '';
    if (notif.isChatRelated) {
      label = 'Open Chat';
    } else if (notif.isBookingRelated) {
      label = 'View Booking';
    } else if (notif.isSupportRelated || notif.ticketId != null) {
      label = 'View Ticket';
    } else if (notif.isPaymentRelated || notif.paymentId != null) {
      label = 'View Receipt';
    } else if (notif.type.contains('SECURITY')) {
      label = 'Security';
    }

    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
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
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notif) async {
    HapticFeedback.lightImpact();
    if (!notif.isRead) {
      await _notificationService.markAsRead(notif.id);
    }

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid ?? '';
    final clientName = user?.displayName ?? 'Athlete';
    final clientEmail = user?.email ?? '';
    final isEmailVerified = user?.emailVerified ?? false;

    // 1. Chat navigation
    if (notif.isChatRelated || notif.conversationId != null) {
      final convId = notif.conversationId ?? '';
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
          return;
        }
      } catch (e) {
        debugPrint('Error navigating to booking: $e');
      }
    }

    if (!mounted) return;

    // 3. Support ticket navigation
    if (notif.isSupportRelated || notif.ticketId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientSupportTicketsScreen(
            clientId: currentUid,
            clientName: clientName,
            clientEmail: clientEmail,
          ),
        ),
      );
      return;
    }

    // 4. Payment / Package navigation
    if (notif.isPaymentRelated || notif.paymentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPaymentHistoryScreen(clientId: currentUid),
        ),
      );
      return;
    }

    // 5. Account Security navigation
    if (notif.type.contains('SECURITY')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientAccountSecurityScreen(
            clientId: currentUid,
            userEmail: clientEmail,
            isEmailVerified: isEmailVerified,
          ),
        ),
      );
      return;
    }
  }

  Widget _buildEmptyState(double sf) {
    String title = 'No Notifications Yet';
    String description =
        'You will receive real-time updates for booking confirmations, reminders, and trainer messages here.';

    if (_showOnlyUnread) {
      title = 'All Caught Up';
      description = _selectedCategory == 'All'
          ? 'You have read all your notifications.'
          : 'You have no unread notifications under "$_selectedCategory".';
    } else if (_selectedCategory != 'All') {
      title = 'No $_selectedCategory';
      description = 'You have no notifications in this category yet.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showOnlyUnread ? Iconsax.tick_circle : Iconsax.notification_bing,
                size: 42,
                color: kDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (16.0 * sf).clamp(15.0, 18.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
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
