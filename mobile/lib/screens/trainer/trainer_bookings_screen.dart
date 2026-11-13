import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/booking_service.dart';
import '../../shared/models/booking_model.dart';

const Color _kDark = Color(0xFF141416);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kCardBg = Color(0xFF1C1C1E);

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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BookingModel> _applySearch(List<BookingModel> bookings) {
    if (_searchQuery.trim().isEmpty) return bookings;
    final q = _searchQuery.toLowerCase().trim();
    return bookings.where((b) {
      final name = b.displayClientName.toLowerCase();
      final id = b.id.toLowerCase();
      final plan = b.resolvedPackageName.toLowerCase();
      final location = (b.meetingLocation ?? '').toLowerCase();
      return name.contains(q) || id.contains(q) || plan.contains(q) || location.contains(q);
    }).toList();
  }

  void _openBookingDetails(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingDetailModalSheet(
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
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Scheduled Bookings',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
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
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by client, package, or booking ID...',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    prefixIcon: const Icon(Iconsax.search_normal, color: _kLime, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kLime),
                    ),
                  ),
                ),
              ),
              // Segmented TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: _kLime,
                indicatorWeight: 3,
                labelColor: _kLime,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontFamily: 'Syne', fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Syne', fontSize: 12, fontWeight: FontWeight.w500),
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
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.calendar_remove, size: 28, color: _kGrey),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
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
          color: isConfirmed
              ? _kLime.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
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
                      backgroundColor: _kLime.withValues(alpha: 0.2),
                      backgroundImage: (booking.clientPhotoUrl != null && booking.clientPhotoUrl!.isNotEmpty)
                          ? NetworkImage(booking.clientPhotoUrl!)
                          : null,
                      child: (booking.clientPhotoUrl == null || booking.clientPhotoUrl!.isEmpty)
                          ? Text(
                              _initials(booking.displayClientName),
                              style: const TextStyle(
                                fontFamily: 'Syne',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _kLime,
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
                              fontFamily: 'Syne',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ref #${booking.id}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _kGrey),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        booking.displayStatus,
                        style: TextStyle(
                          fontFamily: 'Syne',
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
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar_1, size: 15, color: _kLime),
                      const SizedBox(width: 8),
                      Text(
                        _formatFullDate(booking.sessionDate),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const Spacer(),
                      const Icon(Iconsax.clock, size: 15, color: _kLime),
                      const SizedBox(width: 6),
                      Text(
                        '${booking.startTime} - ${booking.endTime}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white70),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '60 min',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _kLime, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Location row (revealed ONLY if confirmed)
                Row(
                  children: [
                    Icon(
                      Iconsax.location,
                      size: 13,
                      color: isConfirmed ? Colors.lightBlueAccent : _kGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isConfirmed
                            ? (booking.meetingLocation ?? 'Client Home / Fitness Facility')
                            : 'Location address hidden until booking is confirmed',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: isConfirmed ? Colors.white70 : Colors.white38,
                          fontStyle: isConfirmed ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),

                // Cancellation note preview if cancelled
                if (booking.isCancelled && booking.cancellationReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.info_circle, size: 12, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reason: ${booking.cancellationReason}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Colors.redAccent),
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
        return _kLime;
      case BookingStatus.pending:
      case BookingStatus.reserved:
        return const Color(0xFFFFB300);
      case BookingStatus.completed:
        return Colors.greenAccent;
      case BookingStatus.cancelled:
      case BookingStatus.cancelledClientEarly:
      case BookingStatus.cancelledClientLate:
      case BookingStatus.cancelledTrainer:
      case BookingStatus.cancelledAdmin:
      case BookingStatus.rejected:
      case BookingStatus.expired:
        return Colors.redAccent;
      case BookingStatus.rescheduled:
        return Colors.lightBlueAccent;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  String _formatFullDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[dt.weekday - 1];
    return '$dayName, ${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

/// ── Booking Detail Modal Sheet with Actions ─────────────────────────────────
class _BookingDetailModalSheet extends StatefulWidget {
  final BookingModel booking;
  final String trainerId;
  final VoidCallback onSessionCompleted;
  final VoidCallback onSessionCancelled;

  const _BookingDetailModalSheet({
    required this.booking,
    required this.trainerId,
    required this.onSessionCompleted,
    required this.onSessionCancelled,
  });

  @override
  State<_BookingDetailModalSheet> createState() => _BookingDetailModalSheetState();
}

class _BookingDetailModalSheetState extends State<_BookingDetailModalSheet> {
  final BookingService _bookingService = BookingService.instance;
  bool _isLoading = false;

  Future<void> _handleCompleteSession() async {
    final notesCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Complete Training Session?',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark this 60-minute session with ${widget.booking.displayClientName} as completed?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.shield_tick, size: 16, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session Credit: 1 session credit will be authoritatively consumed from the client package ledger.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Workout notes (e.g. Completed chest routine, 30kg bench)...',
                hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.3), fontSize: 11.5),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kLime,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Completion', style: TextStyle(fontFamily: 'Syne', color: _kDark, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _bookingService.completeSession(
          bookingId: widget.booking.id,
          sessionNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        );
        widget.onSessionCompleted();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF2E7D32),
              content: Text('Session completed successfully! 1 credit consumed.', style: TextStyle(fontFamily: 'Poppins')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Error completing session: $e', style: const TextStyle(fontFamily: 'Poppins')),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCancelSession() async {
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Scheduled Session?',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you need to cancel this session with ${widget.booking.displayClientName}?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trainer Cancellation Policy: 1 session credit will be returned to the client and availability slot will be freed.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Cancellation reason (e.g. Schedule emergency, medical)...',
                hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.3), fontSize: 11.5),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back', style: TextStyle(color: _kGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for cancellation.')),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel Session', style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _bookingService.cancelBooking(
          bookingId: widget.booking.id,
          isTrainer: true,
          reason: reasonCtrl.text.trim(),
        );
        widget.onSessionCancelled();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: _kDark,
              content: Text('Session cancelled. Client credited and notified.', style: TextStyle(fontFamily: 'Poppins')),
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
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF141416),
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
        color: Color(0xFF1E1E22),
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
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),

              // Client Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _kLime.withValues(alpha: 0.2),
                    backgroundImage: (b.clientPhotoUrl != null && b.clientPhotoUrl!.isNotEmpty)
                        ? NetworkImage(b.clientPhotoUrl!)
                        : null,
                    child: (b.clientPhotoUrl == null || b.clientPhotoUrl!.isEmpty)
                        ? Text(
                            _initials(b.displayClientName),
                            style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: _kLime, fontSize: 16),
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
                          style: const TextStyle(fontFamily: 'Syne', fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Booking Ref: #${b.id}',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                        ),
                      ],
                    ),
                  ),
                  if (isConfirmed && b.clientPhone != null && b.clientPhone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Iconsax.call, color: _kLime, size: 20),
                      tooltip: 'Call Client',
                      onPressed: () => _callClient(b.clientPhone!),
                    ),
                ],
              ),
              const Divider(height: 28, color: Colors.white12),

              // Details Sections
              _detailRow('Status', b.displayStatus, isHighlight: true),
              _detailRow('Session Date', _formatDate(b.sessionDate)),
              _detailRow('Time & Duration', '${b.startTime} - ${b.endTime} (60 min)'),
              _detailRow(
                'Training Location',
                isConfirmed
                    ? (b.meetingLocation ?? 'Client Home / Fitness Facility')
                    : 'Location address hidden until booking is confirmed',
                isMuted: !isConfirmed,
              ),
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
                const Center(child: CircularProgressIndicator(color: _kLime))
              else ...[
                if (isConfirmed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleCancelSession,
                          icon: const Icon(Iconsax.close_circle, size: 16, color: Colors.redAccent),
                          label: const Text('Cancel Session', style: TextStyle(fontFamily: 'Syne', color: Colors.redAccent, fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleCompleteSession,
                          icon: const Icon(Iconsax.tick_circle, size: 16, color: _kDark),
                          label: const Text('Mark Completed', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: _kDark, fontSize: 12.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kLime,
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
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontWeight: FontWeight.w700)),
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
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: isHighlight ? 'Syne' : 'Poppins',
                fontSize: 12.5,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isAlert
                    ? Colors.redAccent
                    : isHighlight
                        ? _kLime
                        : isMuted
                            ? Colors.white38
                            : Colors.white,
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
