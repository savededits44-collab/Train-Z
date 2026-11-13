import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/credit_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/review_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/models/review_model.dart';
import '../../../../shared/models/session_credit_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../widgets/client_review_modal.dart';
import 'client_booking_detail_screen.dart';
import 'client_notifications_screen.dart';

/// Complete My Bookings section for clients to track, manage, reschedule,
/// and review their 60-minute training sessions.
class ClientMyBookingsScreen extends StatefulWidget {
  final String clientId;
  final VoidCallback? onBookNew;
  final bool isEmbedded;

  const ClientMyBookingsScreen({
    super.key,
    required this.clientId,
    this.onBookNew,
    this.isEmbedded = false,
  });

  @override
  State<ClientMyBookingsScreen> createState() => _ClientMyBookingsScreenState();
}

class _ClientMyBookingsScreenState extends State<ClientMyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  final _creditService = CreditService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _firestoreService.streamUserNotifications(widget.clientId),
      builder: (context, snapshot) {
        final notifs = snapshot.data ?? [];
        final unreadCount = notifs.where((n) => !n.isRead).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Iconsax.notification, color: kDark, size: 22),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientNotificationsScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    final content = Column(
      children: [
        if (widget.isEmbedded)
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Bookings',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (20.0 * sf).clamp(18.0, 24.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
                _buildNotificationBell(),
              ],
            ),
          ),

        // ── 1. SESSION CREDITS OVERVIEW CARD ──
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
          child: _buildSessionCreditsSummary(sf),
        ),

        // ── 2. REAL-TIME BOOKINGS STREAM & 4 TABS ──
        Expanded(
          child: StreamBuilder<List<BookingModel>>(
            stream: _firestoreService.streamClientBookings(widget.clientId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kDark));
              }

              final allBookings = snapshot.data ?? [];

              // Categorize bookings per platform specifications
              final upcoming = allBookings.where((b) => b.isUpcoming).toList();
              final pending = allBookings.where((b) => b.isPending).toList();
              final completed = allBookings.where((b) => b.isCompleted).toList();
              final cancelled = allBookings.where((b) => b.isCancelled).toList();

              return Column(
                children: [
                  // Segmented TabBar
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: hPad),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: kDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: kLime,
                      unselectedLabelColor: const Color(0xFF6B7280),
                      labelStyle: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.all(3),
                      tabs: [
                        _buildTabItem('Upcoming', upcoming.length),
                        _buildTabItem('Pending', pending.length),
                        _buildTabItem('Done', completed.length),
                        _buildTabItem('Cancelled', cancelled.length),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookingsList(
                          bookings: upcoming,
                          emptyTitle: 'No Upcoming Sessions',
                          emptySubtitle: 'Your confirmed 60-min personal training workouts will appear here.',
                          isUpcomingTab: true,
                          sf: sf,
                          hPad: hPad,
                        ),
                        _buildBookingsList(
                          bookings: pending,
                          emptyTitle: 'No Pending Bookings',
                          emptySubtitle: 'Sessions pending trainer confirmation or checkout reservation appear here.',
                          isUpcomingTab: false,
                          sf: sf,
                          hPad: hPad,
                        ),
                        _buildBookingsList(
                          bookings: completed,
                          emptyTitle: 'No Completed Sessions Yet',
                          emptySubtitle: 'Your workout history and completed training sessions will be saved here.',
                          isUpcomingTab: false,
                          sf: sf,
                          hPad: hPad,
                        ),
                        _buildBookingsList(
                          bookings: cancelled,
                          emptyTitle: 'No Cancelled Sessions',
                          emptySubtitle: 'Cancelled sessions and refund credit audit logs appear here.',
                          isUpcomingTab: false,
                          sf: sf,
                          hPad: hPad,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Container(color: Colors.white, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'My Bookings',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 13, color: kDark),
                const SizedBox(width: 4),
                Text(
                  LocationService.instance.currentFormattedLocation,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildNotificationBell(),
          SizedBox(width: hPad - 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildTabItem(String label, int count) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 1. SESSION CREDITS CARD (DOUBLE-ENTRY TRUTH FROM FIREBASE) ──
  Widget _buildSessionCreditsSummary(double sf) {
    return StreamBuilder<SessionCreditModel?>(
      stream: _creditService.streamClientCredits(widget.clientId),
      builder: (context, snapshot) {
        final credits = snapshot.data;
        final available = credits?.availableBalance ?? 0;
        final purchased = credits?.totalPurchased ?? 0;
        final reserved = credits?.totalReserved ?? 0;
        final consumed = credits?.totalConsumed ?? 0;
        final forfeited = credits?.totalForfeited ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.ticket, size: 15, color: kLime),
                      const SizedBox(width: 6),
                      Text(
                        'SESSION CREDITS',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (10.5 * sf).clamp(9.5, 12.0),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF999999),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kLime.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '60 Min / Session',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (9.5 * sf).clamp(8.5, 10.5),
                        fontWeight: FontWeight.w700,
                        color: kLime,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$available',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (32.0 * sf).clamp(26.0, 38.0),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Available to Book',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFF262626),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCreditSubRow('Total Purchased', '$purchased', sf),
                        const SizedBox(height: 3),
                        _buildCreditSubRow('Reserved (In Hold)', '$reserved', sf),
                        const SizedBox(height: 3),
                        _buildCreditSubRow('Completed / Consumed', '$consumed', sf),
                        if (forfeited > 0) ...[
                          const SizedBox(height: 3),
                          _buildCreditSubRow('Late Forfeited (<12h)', '$forfeited', sf, isWarning: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (credits?.activePackageName != null || credits?.packageExpiryDate != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFF262626)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Iconsax.box_1, size: 13, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              credits?.activePackageName ?? 'TRAIN Z Package',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (credits?.packageExpiryDate != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: credits!.isPackageExpired
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          credits.isPackageExpired
                              ? 'Package Expired'
                              : 'Expires ${_formatDate(credits.packageExpiryDate!)} (${credits.daysUntilExpiry}d left)',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: credits.isPackageExpired ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreditSubRow(String label, String value, double sf, {bool isWarning = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (10.0 * sf).clamp(9.0, 11.0),
              color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (11.0 * sf).clamp(10.0, 12.0),
            fontWeight: FontWeight.w700,
            color: isWarning ? const Color(0xFFEF4444) : Colors.white,
          ),
        ),
      ],
    );
  }

  // ── 2. BOOKINGS LIST PER TAB ──
  Widget _buildBookingsList({
    required List<BookingModel> bookings,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isUpcomingTab,
    required double sf,
    required double hPad,
  }) {
    if (bookings.isEmpty) {
      return _buildEmptyState(emptyTitle, emptySubtitle, sf);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking, isUpcomingTab, sf);
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking, bool isUpcoming, double sf) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientBookingDetailScreen(booking: booking),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            // Top Row: Trainer avatar, name, status chip
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kDark,
                  backgroundImage: booking.trainerPhotoUrl != null &&
                          booking.trainerPhotoUrl!.isNotEmpty
                      ? NetworkImage(booking.trainerPhotoUrl!)
                      : null,
                  child: booking.trainerPhotoUrl == null ||
                          booking.trainerPhotoUrl!.isEmpty
                      ? Text(
                          booking.displayTrainerName.isNotEmpty
                              ? booking.displayTrainerName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(fontFamily: 'Syne', color: kLime, fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              booking.displayTrainerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (14.0 * sf).clamp(13.0, 15.5),
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                        ],
                      ),
                      Text(
                        booking.resolvedPackageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(booking),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),

            // Date, Time & 60-Min Structure
            Row(
              children: [
                const Icon(Iconsax.calendar_1, size: 14, color: kDark),
                const SizedBox(width: 6),
                Text(
                  _formatDate(booking.sessionDate),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (11.5 * sf).clamp(10.5, 12.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Iconsax.clock, size: 14, color: kDark),
                const SizedBox(width: 6),
                Text(
                  '${booking.startTime} - ${booking.endTime}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (11.5 * sf).clamp(10.5, 12.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '60 Mins',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: kDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Location Tag
            Row(
              children: [
                const Icon(Iconsax.location, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.meetingLocation ?? 'Training Location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.0),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),

            if (booking.isCompleted) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.ticket, size: 12, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text(
                      '1 Session Credit Consumed',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<ReviewModel?>(
                stream: ReviewService.instance.streamReviewForBooking(booking.id),
                builder: (context, reviewSnap) {
                  final review = reviewSnap.data;
                  if (review != null) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                'Reviewed ★ ${review.ratingText}',
                                style: const TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ClientReviewModal.show(
                                context,
                                booking: booking,
                                existingReview: review,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 13, color: Color(0xFF92400E)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Edit Review',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ClientReviewModal.show(
                          context,
                          booking: booking,
                        );
                      },
                      icon: const Icon(Icons.star_outline_rounded, size: 15, color: kDark),
                      label: const Text(
                        'Rate & Review Session',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLime,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  );
                },
              ),
            ] else if (booking.isCreditReturned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.ticket, size: 12, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      '1 Session Credit Returned to Balance',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (booking.isCreditForfeited) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.ticket_expired, size: 12, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text(
                      '1 Session Credit Forfeited (<12h cancellation)',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (booking.isRescheduled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.refresh, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      'Rescheduled session',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (10.0 * sf).clamp(9.0, 11.0),
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  booking.bookingReference,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '60-Min Training',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: kGrey.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BookingModel booking) {
    Color bg;
    Color fg;

    switch (booking.status) {
      case BookingStatus.confirmed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case BookingStatus.pending:
      case BookingStatus.reserved:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case BookingStatus.completed:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case BookingStatus.rescheduled:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4F46E5);
        break;
      case BookingStatus.cancelled:
      case BookingStatus.cancelledClientEarly:
      case BookingStatus.cancelledTrainer:
      case BookingStatus.cancelledAdmin:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
      case BookingStatus.cancelledClientLate:
      case BookingStatus.rejected:
      case BookingStatus.expired:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        booking.displayStatus,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.calendar_2, size: 36, color: kDark),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (15.0 * sf).clamp(14.0, 17.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10.5, 12.5),
              color: kGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.onBookNew,
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              foregroundColor: kLime,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Find a Trainer',
              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
