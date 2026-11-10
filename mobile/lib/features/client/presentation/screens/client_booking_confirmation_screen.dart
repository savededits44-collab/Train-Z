import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Screen displaying the temporary reservation status or final confirmed booking.
/// For pending payments: clearly explains the booking is NOT yet confirmed,
/// shows 15-minute countdown timer, preparation hook for payment module, and slot cancellation.
/// For confirmed bookings: displays booking details, verified credentials, and navigation to bookings.
class ClientBookingConfirmationScreen extends StatefulWidget {
  final BookingModel booking;
  final TrainerDisplayModel trainer;
  final TrainingPlanModel plan;

  const ClientBookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.trainer,
    required this.plan,
  });

  @override
  State<ClientBookingConfirmationScreen> createState() => _ClientBookingConfirmationScreenState();
}

class _ClientBookingConfirmationScreenState extends State<ClientBookingConfirmationScreen> {
  final _firestoreService = FirestoreService();
  late BookingModel _currentBooking;
  Timer? _countdownTimer;
  int _secondsLeft = 900; // 15 mins default
  bool _isProcessingPayment = false;
  bool _isCancelling = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    _secondsLeft = _currentBooking.secondsRemaining > 0 ? _currentBooking.secondsRemaining : 900;

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _currentBooking = _currentBooking.copyWith(
            status: BookingStatus.expired,
            paymentStatus: PaymentStatus.failed,
          );
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _formattedCountdown {
    final mins = _secondsLeft ~/ 60;
    final secs = _secondsLeft % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Hook connecting to the payment module (implemented separately).
  /// Verifies backend confirmation before treating booking as confirmed.
  Future<void> _handleProceedToPayment() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessingPayment = true;
      _statusMessage = 'Connecting to payment module...';
    });

    // Simulate payment module handshake & verification via backend Cloud Function
    await Future.delayed(const Duration(seconds: 2));

    try {
      final confirmed = await _firestoreService.confirmBookingPayment(
        bookingId: _currentBooking.id,
        paymentTransactionId: 'PAY_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      _countdownTimer?.cancel();
      setState(() {
        _isProcessingPayment = false;
        _currentBooking = confirmed;
        _statusMessage = null;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingPayment = false;
        _statusMessage = 'Payment verification failed: $e';
      });
    }
  }

  /// Releases the temporary slot reservation immediately if client cancels or backs out
  Future<void> _handleCancelReservation() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Reservation?', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
        content: const Text(
          'Releasing this reservation will free up the time slot for other athletes.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Slot', style: TextStyle(fontFamily: 'Poppins', color: kDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
            ),
            child: const Text('Release Slot', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() => _isCancelling = true);
    HapticFeedback.mediumImpact();

    try {
      await _firestoreService.releaseBookingReservation(
        bookingId: _currentBooking.id,
        reason: 'USER_CANCELLED',
      );

      if (!mounted) return;
      _countdownTimer?.cancel();
      Navigator.pop(context); // Return to scheduling screen
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);
    final isConfirmed = _currentBooking.status == BookingStatus.confirmed &&
        _currentBooking.paymentStatus == PaymentStatus.completed;
    final isExpired = _currentBooking.status == BookingStatus.expired || _secondsLeft == 0;

    return PopScope(
      canPop: isConfirmed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleCancelReservation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 20, color: kDark),
            onPressed: () {
              if (isConfirmed) {
                Navigator.popUntil(context, (route) => route.isFirst);
              } else {
                _handleCancelReservation();
              }
            },
          ),
          title: Text(
            isConfirmed ? 'Booking Confirmed' : 'Checkout & Hold',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (18.0 * sf).clamp(16.0, 21.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. STATUS HEADER CARD ──
              if (isConfirmed)
                _buildConfirmedHeader(sf)
              else if (isExpired)
                _buildExpiredHeader(sf)
              else
                _buildPendingPaymentHeader(sf),

              const SizedBox(height: 20),

              // ── 2. BOOKING DETAILS CARD ──
              _buildBookingDetailsCard(sf, isConfirmed),

              const SizedBox(height: 20),

              // ── 3. TRAINING PACKAGE & PRICING CARD ──
              _buildPackagePricingCard(sf),

              const SizedBox(height: 20),

              // ── 4. LOCATION & PRIVACY CARD ──
              _buildLocationInfoCard(sf),

              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ],
          ),
        ),
        // ── BOTTOM ACTION BAR ──
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: isConfirmed
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE5E5E5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Home Dashboard', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.popUntil(context, (r) => r.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDark,
                            foregroundColor: kLime,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('View in My Bookings', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kLime)),
                        ),
                      ),
                    ],
                  )
                : isExpired
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Select Another Slot', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isProcessingPayment || _isCancelling ? null : _handleProceedToPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kDark,
                                foregroundColor: kLime,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _isProcessingPayment
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Verifying Payment...', style: TextStyle(fontFamily: 'Syne', color: kLime, fontWeight: FontWeight.w700)),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Iconsax.card_tick, size: 18, color: kLime),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pay ₹${widget.plan.price} & Confirm',
                                          style: TextStyle(
                                            fontFamily: 'Syne',
                                            fontSize: (14.5 * sf).clamp(13.0, 16.5),
                                            fontWeight: FontWeight.w800,
                                            color: kLime,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isCancelling ? null : _handleCancelReservation,
                            child: _isCancelling
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text(
                                    'Cancel & Release Slot',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  // ── Confirmed Booking Banner ──
  Widget _buildConfirmedHeader(double sf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Booking Confirmed!',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (20.0 * sf).clamp(18.0, 24.0),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14532D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Payment verified. Your coach is notified & scheduled.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10.5, 13.0),
              color: const Color(0xFF166534),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              'REF: ${_currentBooking.id.toUpperCase()}',
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pending Payment Banner with Countdown ──
  Widget _buildPendingPaymentHeader(double sf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SLOT TEMPORARILY RESERVED',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  Text(
                    _formattedCountdown,
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Booking Not Yet Confirmed',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (17.0 * sf).clamp(15.0, 20.0),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your time slot is held for 15 minutes. Complete payment to confirm the appointment. If unpaid, the slot automatically releases.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(10.0, 12.5),
              color: const Color(0xFF78350F),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Expired Reservation Banner ──
  Widget _buildExpiredHeader(double sf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.alarm_off, size: 32, color: Color(0xFFDC2626)),
          const SizedBox(height: 8),
          const Text(
            'Reservation Expired',
            style: TextStyle(fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'The 15-minute checkout window has elapsed and the time slot was released.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF7F1D1D)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 2. Booking Details ──
  Widget _buildBookingDetailsCard(double sf, bool isConfirmed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coach Info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF3F4F6),
                  child: (widget.trainer.photoUrl != null && widget.trainer.photoUrl!.isNotEmpty)
                      ? Image.network(widget.trainer.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Iconsax.user))
                      : const Icon(Iconsax.user),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trainer.displayName,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (14.5 * sf).clamp(13.0, 16.5),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                    Text(
                      'Personal Performance Coach',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isConfirmed ? 'CONFIRMED' : 'RESERVED',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isConfirmed ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildInfoRow(Iconsax.calendar_1, 'Session Date', '${_currentBooking.sessionDate.day} ${_getShortMonth(_currentBooking.sessionDate.month)} ${_currentBooking.sessionDate.year}'),
          const SizedBox(height: 10),
          _buildInfoRow(Iconsax.clock, 'Session Time', '${_currentBooking.startTime} - ${_currentBooking.endTime} (60 min)'),
          const SizedBox(height: 10),
          _buildInfoRow(Iconsax.location, 'Meeting Location', _currentBooking.meetingLocation ?? 'Client Selected Venue'),
        ],
      ),
    );
  }

  // ── 3. Package & Pricing Breakdown ──
  Widget _buildPackagePricingCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Package',
                style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w800, color: kDark),
              ),
              Text(
                widget.plan.title,
                style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w800, color: kDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSummaryLine('Sessions Included', '${widget.plan.sessionsCount} Sessions (60 mins each)'),
          _buildSummaryLine('Package Validity', '${widget.plan.validityDays} Days'),
          _buildSummaryLine('Rate Per Session', '₹${widget.plan.pricePerSession.round()}/session'),
          const Divider(height: 18, color: Color(0xFFF0F0F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.w800, color: kDark)),
              Text('₹${widget.plan.price}', style: const TextStyle(fontFamily: 'Syne', fontSize: 17, fontWeight: FontWeight.w800, color: kDark)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Location & Cancellation Policy ──
  Widget _buildLocationInfoCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.shield_tick, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Privacy & Policy Terms', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11.5, color: kDark)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Exact residential address is kept private and accessible only to your assigned trainer.\n• Cancel at least 12 hours prior to start time to retain session credit.\n• Platform credit allocation is processed upon verified payment.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF555555), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kDark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: kGrey)),
              Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: kDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey)),
          Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: kDark)),
        ],
      ),
    );
  }

  String _getShortMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }
}
