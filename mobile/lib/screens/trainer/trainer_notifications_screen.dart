import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/notification_service.dart';
import '../../shared/models/conversation_model.dart';
import '../../shared/models/notification_model.dart';
import 'trainer_bookings_screen.dart';
import 'trainer_certificates_screen.dart';
import 'trainer_conversation_screen.dart';
import 'trainer_earnings_screen.dart';
import 'trainer_messages_screen.dart';
import 'trainer_notification_preferences_screen.dart';
import 'trainer_package_management_screen.dart';
import 'trainer_reviews_screen.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

/// Dedicated Notification Centre for Trainers
class TrainerNotificationsScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerNotificationsScreen({
    super.key,
    this.trainerId,
  });

  @override
  State<TrainerNotificationsScreen> createState() =>
      _TrainerNotificationsScreenState();
}

class _TrainerNotificationsScreenState
    extends State<TrainerNotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  late final String _trainerId;
  NotificationCategory _selectedCategory = NotificationCategory.all;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
  }

  void _onCategorySelected(NotificationCategory category) {
    if (_selectedCategory == category) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    await _notificationService.markAllAsRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'All notifications marked as read',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: _kCardSubBg,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // 1. Mark as read
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
    }

    if (!mounted) return;

    final type = notification.type.toUpperCase();
    final data = notification.data;

    // 2. Route based on category / type
    if (notification.categoryEnum == NotificationCategory.bookings ||
        notification.categoryEnum == NotificationCategory.sessions ||
        type.startsWith('BOOKING_') ||
        type.contains('REMINDER')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainerBookingsScreen(trainerId: _trainerId),
        ),
      );
      return;
    }

    if (notification.categoryEnum == NotificationCategory.messages ||
        type == 'CHAT_MESSAGE' ||
        notification.conversationId != null) {
      final convId = notification.conversationId ?? '';
      final clientId = data['clientId'] as String? ?? data['senderId'] as String? ?? '';
      final clientName = data['clientName'] as String? ?? data['senderName'] as String? ?? 'Athlete';

      if (convId.isNotEmpty && clientId.isNotEmpty) {
        final conv = ConversationModel(
          id: convId,
          clientId: clientId,
          trainerId: _trainerId,
          trainerName: 'Trainer',
          clientName: clientName,
          lastMessage: notification.body,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrainerConversationScreen(
              conversation: conv,
              trainerId: _trainerId,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrainerMessagesScreen(trainerId: _trainerId),
          ),
        );
      }
      return;
    }

    if (notification.categoryEnum == NotificationCategory.packages ||
        type.startsWith('PACKAGE_')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainerPackageManagementScreen(trainerId: _trainerId),
        ),
      );
      return;
    }

    if (notification.categoryEnum == NotificationCategory.earnings ||
        type.startsWith('PAYOUT_') ||
        type.startsWith('EARNINGS_') ||
        type == 'PAYMENT_CONFIRMED') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainerEarningsScreen(trainerId: _trainerId),
        ),
      );
      return;
    }

    if (notification.categoryEnum == NotificationCategory.reviews ||
        type.startsWith('REVIEW_')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainerReviewsScreen(trainerId: _trainerId),
        ),
      );
      return;
    }

    if (type.startsWith('CERTIFICATE_') ||
        type.startsWith('VERIFICATION_') ||
        type.startsWith('SECURITY_')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainerCertificatesScreen(trainerId: _trainerId),
        ),
      );
      return;
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.bookings:
        return Iconsax.calendar_1;
      case NotificationCategory.messages:
        return Iconsax.message_text;
      case NotificationCategory.sessions:
        return Iconsax.clock;
      case NotificationCategory.packages:
        return Iconsax.box;
      case NotificationCategory.earnings:
        return Iconsax.wallet_money;
      case NotificationCategory.reviews:
        return Iconsax.star_1;
      case NotificationCategory.support:
        return Iconsax.headphone;
      case NotificationCategory.announcements:
      case NotificationCategory.all:
        return Iconsax.notification;
    }
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.bookings:
        return _kLime;
      case NotificationCategory.messages:
        return const Color(0xFF38BDF8); // Cyan
      case NotificationCategory.sessions:
        return const Color(0xFFFB923C); // Orange
      case NotificationCategory.packages:
        return const Color(0xFFA855F7); // Purple
      case NotificationCategory.earnings:
        return const Color(0xFF34D399); // Emerald
      case NotificationCategory.reviews:
        return const Color(0xFFFBBF24); // Amber
      case NotificationCategory.support:
        return const Color(0xFF60A5FA); // Blue
      case NotificationCategory.announcements:
      case NotificationCategory.all:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notification Centre',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all, color: Colors.white, size: 22),
            onPressed: _markAllAsRead,
          ),
          IconButton(
            tooltip: 'Notification Preferences',
            icon: const Icon(Iconsax.setting_2, color: Colors.white, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrainerNotificationPreferencesScreen(
                    trainerId: _trainerId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.streamNotificationsForTrainer(_trainerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _kLime),
            );
          }

          final allNotifications = snapshot.data ?? [];
          final filteredNotifications = _notificationService.filterByCategory(
            allNotifications,
            _selectedCategory,
          );
          final unreadCount = allNotifications.where((n) => !n.isRead).length;

          return Column(
            children: [
              // ── Top Summary Header ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${allNotifications.length}',
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _kLime.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kLime.withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: _kLime,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$unreadCount Unread',
                              style: const TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kLime,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (unreadCount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _markAllAsRead,
                        icon: const Icon(
                          Icons.done_all,
                          size: 15,
                          color: _kLime,
                        ),
                        label: const Text(
                          'Mark all read',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kLime,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Horizontal Category Filter Chips ────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: NotificationCategory.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = NotificationCategory.values[index];
                    final isSelected = _selectedCategory == cat;
                    final count = cat == NotificationCategory.all
                        ? allNotifications.length
                        : allNotifications.where((n) => n.categoryEnum == cat).length;

                    return ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => _onCategorySelected(cat),
                      backgroundColor: _kCardBg,
                      selectedColor: _kLime,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: isSelected ? _kLime : _kBorder,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat.displayName,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? _kDark : Colors.white,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _kDark.withAlpha(40)
                                    : _kCardSubBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? _kDark : _kGrey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Notification List ───────────────────────────
              Expanded(
                child: filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filteredNotifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredNotifications[index];
                          return _buildNotificationCard(item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: Icon(
                _getCategoryIcon(_selectedCategory),
                color: _kGrey,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == NotificationCategory.all
                  ? 'No Notifications'
                  : 'No ${_selectedCategory.displayName} Notifications',
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedCategory == NotificationCategory.all
                  ? 'You are all caught up! Updates regarding bookings, messages, payouts, and reviews will appear here.'
                  : 'You have no notifications under ${_selectedCategory.displayName.toLowerCase()} right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _kGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item) {
    final catColor = _getCategoryColor(item.categoryEnum);

    String? referenceLabel;
    if (item.bookingId != null) {
      referenceLabel = 'Booking #${item.bookingId!.length > 6 ? item.bookingId!.substring(0, 6) : item.bookingId}';
    } else if (item.packageId != null) {
      referenceLabel = 'Package #${item.packageId!.length > 6 ? item.packageId!.substring(0, 6) : item.packageId}';
    } else if (item.payoutId != null) {
      referenceLabel = 'Payout #${item.payoutId!.length > 6 ? item.payoutId!.substring(0, 6) : item.payoutId}';
    } else if (item.reviewId != null) {
      referenceLabel = 'Review';
    } else if (item.ticketId != null) {
      referenceLabel = 'Ticket #${item.ticketId!}';
    }

    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withAlpha(40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 24),
      ),
      onDismissed: (_) {
        _notificationService.deleteNotification(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notification removed',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            backgroundColor: _kCardSubBg,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(item),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.isRead ? _kCardBg : _kCardSubBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.isRead ? _kBorder : _kLime.withAlpha(120),
                width: item.isRead ? 1 : 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: catColor.withAlpha(60)),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.categoryEnum),
                    size: 18,
                    color: catColor,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 14,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _kLime,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            item.formattedDate,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _kGrey,
                            ),
                          ),
                          if (referenceLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _kCardBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Text(
                                referenceLabel,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _kLime,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            item.categoryEnum.displayName,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              color: catColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
