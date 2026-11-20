import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/booking_service.dart';
import '../../shared/models/booking_model.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kGrey = Color(0xFF6B7280);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kBorder = Color(0xFFE5E7EB);

enum BookingFilterTab { upcoming, pending, completed, cancelled }

/// Dedicated Trainer-side Bookings & Session Management Screen
class TrainerBookingsScreen extends StatefulWidget {
  final String? trainerId;
  final BookingFilterTab initialTab;

  const TrainerBookingsScreen({
    super.key,
    this.trainerId,
    this.initialTab = BookingFilterTab.upcoming,
  });

  @override
  State<TrainerBookingsScreen> createState() => _TrainerBookingsScreenState();
}

class _TrainerBookingsScreenState extends State<TrainerBookingsScreen> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService.instance;
  late final String _trainerId;
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    final int initialIndex = BookingFilterTab.values.indexOf(widget.initialTab);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BookingModel> _applySearch(List<BookingModel> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((b) {
      final name = b.displayClientName.toLowerCase();
      final pkg = b.resolvedPackageName.toLowerCase();
      final id = b.id.toLowerCase();
      return name.contains(q) || pkg.contains(q) || id.contains(q);
    }).toList();
  }

  void _openBookingDetails(BookingModel booking) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailModal(
        booking: booking,
        trainerId: _trainerId,
        onSessionCompleted: () {
          setState(() {});
        },
        onSessionCancelled: () {
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kDark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Scheduled Bookings',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by client, package, or booking ID...',
                    hintStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(Iconsax.search_normal, color: _kDark, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _kCardSubBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kDark),
                    ),
                  ),
                ),
              ),
              // Segmented TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: _kDark,
                indicatorWeight: 2.5,
                labelColor: _kDark,
                unselectedLabelColor: _kGrey,
                labelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12.5, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<BookingModel>>(
          stream: _bookingService.streamBookingsForTrainer(_trainerId),
          builder: (context, snapshot) {
            final upcoming = _applySearch(_bookingService.upcomingBookingsForTrainer(_trainerId));
            final pending = _applySearch(_bookingService.pendingBookingsForTrainer(_trainerId));
            final completed = _applySearch(_bookingService.completedBookingsForTrainer(_trainerId));
            final cancelled = _applySearch(_bookingService.cancelledBookingsForTrainer(_trainerId));

            return TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(upcoming, 'No Upcoming Sessions', 'You have no confirmed sessions scheduled.'),
                _buildBookingsList(pending, 'No Pending Requests', 'There are no pending booking holds at this moment.'),
                _buildBookingsList(completed, 'No Completed Sessions', 'Completed sessions will appear here in your workout history.'),
                _buildBookingsList(cancelled, 'No Cancelled Sessions', 'Cancelled sessions and refund audit records appear here.'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, String emptyTitle, String emptySubtitle) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.calendar_remove, size: 28, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: _kDark),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: _kGrey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        return _buildBookingCard(b);
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final statusColor = _getStatusColor(booking.status);
    final isConfirmed = booking.status == BookingStatus.confirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed ? const Color(0xFFBBF7D0) : _kBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openBookingDetails(booking),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Client info & Status Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _kCardSubBg,
                      backgroundImage: (booking.clientPhotoUrl != null && booking.clientPhotoUrl!.isNotEmpty)
                          ? NetworkImage(booking.clientPhotoUrl!)
                          : null,
                      child: (booking.clientPhotoUrl == null || booking.clientPhotoUrl!.isEmpty)
                          ? Text(
                              _initials(booking.displayClientName),
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _kDark,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.displayClientName,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ref #${booking.id}',
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 10.5, color: _kGrey),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        booking.displayStatus,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date, Time & Duration row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar_1, size: 15, color: _kDark),
                      const SizedBox(width: 8),
                      Text(
                        _formatFullDate(booking.sessionDate),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
                      ),
                      const Spacer(),
                      const Icon(Iconsax.clock, size: 15, color: _kDark),
                      const SizedBox(width: 6),
                      Text(
                        '${booking.startTime} - ${booking.endTime}',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Package and Location Info
                Row(
                  children: [
                    const Icon(Iconsax.box, size: 13, color: _kGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.resolvedPackageName,
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: Color(0xFF4B5563)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kCardSubBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '60 min',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 10.5, color: _kDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Commercial Gym Location & Distance
                Row(
                  children: [
                    const Icon(
                      Iconsax.building,
                      size: 13,
                      color: Color(0xFF15803D),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.displayGymName,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _kDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (booking.trainerTravelDistanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Text(
                          '${booking.trainerTravelDistanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                  ],
                ),
                if (booking.displayGymAddress.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Iconsax.location, size: 12, color: _kGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.displayGymAddress,
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 10.5, color: _kGrey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action buttons for pending requests
                if (booking.status == BookingStatus.pending) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openBookingDetails(booking),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _kBorder),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('View Request', style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: _kDark, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            await _bookingService.acceptBooking(booking.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: _kDark,
                                  content: Text('Accepted! 15-minute checkout hold created for ${booking.displayClientName}.', style: const TextStyle(fontFamily: 'Outfit', color: Colors.white)),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kDark,
                            foregroundColor: const Color(0xFFD4E7C5),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Accept (15m)', style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],

                // Cancellation note preview if cancelled
                if (booking.isCancelled && booking.cancellationReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.info_circle, size: 12, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reason: ${booking.cancellationReason}',
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 10.5, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return const Color(0xFF15803D);
      case BookingStatus.pending:
      case BookingStatus.reserved:
        return const Color(0xFFD97706);
      case BookingStatus.completed:
        return const Color(0xFF2563EB);
      case BookingStatus.rescheduled:
        return const Color(0xFF7C3AED);
      case BookingStatus.cancelled:
      case BookingStatus.cancelledClientEarly:
      case BookingStatus.cancelledClientLate:
      case BookingStatus.cancelledTrainer:
      case BookingStatus.cancelledAdmin:
      case BookingStatus.rejected:
      case BookingStatus.expired:
        return const Color(0xFFDC2626);
    }
  }

  String _formatFullDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]}';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }
}

// ── Booking Detail Bottom Modal ─────────────────────────────────────────────
class _BookingDetailModal extends StatefulWidget {
  final BookingModel booking;
  final String trainerId;
  final VoidCallback onSessionCompleted;
  final VoidCallback onSessionCancelled;

  const _BookingDetailModal({
    required this.booking,
    required this.trainerId,
    required this.onSessionCompleted,
    required this.onSessionCancelled,
  });

  @override
  State<_BookingDetailModal> createState() => _BookingDetailModalState();
}

class _BookingDetailModalState extends State<_BookingDetailModal> {
  final BookingService _bookingService = BookingService.instance;
  bool _isLoading = false;

  Future<void> _handleAcceptRequest() async {
    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();
    try {
      await _bookingService.acceptBooking(widget.booking.id);
      if (mounted) {
        widget.onSessionCompleted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _kDark,
            content: Text(
              'Request accepted! 15-minute checkout hold created for ${widget.booking.displayClientName}.',
              style: const TextStyle(fontFamily: 'Outfit', color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text('Decline Session Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: _kDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Decline request from ${widget.booking.displayClientName}? Client will be notified immediately without charge.',
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: _kGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Reason (e.g. Schedule full, beyond travel radius)...',
                hintStyle: const TextStyle(fontFamily: 'Outfit', color: Color(0xFF9CA3AF), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back', style: TextStyle(fontFamily: 'Outfit', color: _kGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Decline Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      HapticFeedback.heavyImpact();
      try {
        await _bookingService.rejectBooking(
          widget.booking.id,
          reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
        );
        if (mounted) {
          widget.onSessionCancelled();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: _kDark,
              content: Text('Session request declined. Client notified.', style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text('Confirm Session Completion', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: _kDark)),
        content: Text(
          'Mark session with ${widget.booking.displayClientName} as completed?\n\nThis will record session attendance, disburse trainer earnings to your ledger, and decrement client package balance.',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: _kGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: _kGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Completion', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      await _bookingService.completeSession(
        bookingId: widget.booking.id,
      );

      if (mounted) {
        widget.onSessionCompleted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF15803D),
            content: Text('Session completed! Revenue has been credited to your earnings.', style: TextStyle(fontFamily: 'Outfit')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleCancelSession() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text('Cancel Scheduled Session', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: _kDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancelling this session will immediately release the time slot and return a session credit to the client.',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: _kGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Reason for cancellation (optional)...',
                hintStyle: const TextStyle(fontFamily: 'Outfit', color: Color(0xFF9CA3AF), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDark)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back', style: TextStyle(fontFamily: 'Outfit', color: _kGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Session', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      HapticFeedback.heavyImpact();

      try {
        await _bookingService.cancelBooking(
          bookingId: widget.booking.id,
          isTrainer: true,
          reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Cancelled by trainer',
        );

        if (mounted) {
          widget.onSessionCancelled();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: _kDark,
              content: Text('Session cancelled. Client credited and notified.', style: TextStyle(fontFamily: 'Outfit')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _callClient(String phone) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contact $phone copied to clipboard!',
          style: const TextStyle(fontFamily: 'Outfit', color: Colors.white),
        ),
        backgroundColor: _kDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isConfirmed = b.status == BookingStatus.confirmed;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),

              // Client Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _kCardSubBg,
                    backgroundImage: (b.clientPhotoUrl != null && b.clientPhotoUrl!.isNotEmpty)
                        ? NetworkImage(b.clientPhotoUrl!)
                        : null,
                    child: (b.clientPhotoUrl == null || b.clientPhotoUrl!.isEmpty)
                        ? Text(
                            _initials(b.displayClientName),
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: _kDark, fontSize: 16),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.displayClientName,
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.w600, color: _kDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Booking Ref: #${b.id}',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: _kGrey),
                        ),
                      ],
                    ),
                  ),
                  if (isConfirmed && b.clientPhone != null && b.clientPhone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Iconsax.call, color: _kDark, size: 20),
                      tooltip: 'Call Client',
                      onPressed: () => _callClient(b.clientPhone!),
                    ),
                ],
              ),
              const Divider(height: 28, color: Color(0xFFEEEEEE)),

              // Details Sections
              _detailRow('Status', b.displayStatus, isHighlight: true),
              _detailRow('Session Date', _formatDate(b.sessionDate)),
              _detailRow('Time & Duration', '${b.startTime} - ${b.endTime} (60 min)'),
              _detailRow('Commercial Gym', b.displayGymName),
              _detailRow('Gym Address', b.displayGymAddress),
              if (b.trainerTravelDistanceKm != null)
                _detailRow('Travel Distance', '${b.trainerTravelDistanceKm!.toStringAsFixed(1)} km from your active location'),
              if (b.googleMapsUrl.isNotEmpty)
                _detailRow('Google Maps Link', b.googleMapsUrl),
              _detailRow('Package Plan', b.resolvedPackageName),

              if (b.fitnessGoal != null && b.fitnessGoal!.isNotEmpty)
                _detailRow('Client Fitness Goal', b.fitnessGoal!),

              if (b.notes != null && b.notes!.isNotEmpty)
                _detailRow('Client Goals / Notes', b.notes!),

              if (b.status == BookingStatus.completed && b.completedAt != null)
                _detailRow('Completed At', _formatDateTime(b.completedAt!)),

              if (b.isCancelled && b.cancellationReason != null)
                _detailRow('Cancellation Details', b.cancellationReason!, isAlert: true),

              const SizedBox(height: 20),

              // Action Buttons
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: _kDark))
              else ...[
                if (b.status == BookingStatus.pending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleDeclineRequest,
                          icon: const Icon(Iconsax.close_circle, size: 16, color: Color(0xFFDC2626)),
                          label: const Text('Decline', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _handleAcceptRequest,
                          icon: const Icon(Iconsax.tick_circle, size: 16, color: _kDark),
                          label: const Text('Accept (15m Hold)', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: _kDark, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4E7C5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else if (isConfirmed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleCancelSession,
                          icon: const Icon(Iconsax.close_circle, size: 16, color: Color(0xFFDC2626)),
                          label: const Text('Cancel Session', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFFDC2626), fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleCompleteSession,
                          icon: const Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
                          label: const Text('Mark Completed', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Colors.white, fontSize: 12.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kDark,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(fontFamily: 'Outfit', color: _kDark, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false, bool isMuted = false, bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: _kGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isAlert
                    ? const Color(0xFFDC2626)
                    : isHighlight
                        ? const Color(0xFF15803D)
                        : isMuted
                            ? const Color(0xFF9CA3AF)
                            : _kDark,
                fontStyle: isMuted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  String _formatDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year} at $hour:$min';
  }
}
