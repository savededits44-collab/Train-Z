import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/conversation_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../widgets/client_reschedule_modal.dart';
import 'client_chat_screen.dart';
import 'client_payment_receipt_screen.dart';

/// Detailed screen displaying full session booking metrics,
/// 60-minute duration, training address, verified status,
/// 12-hour cancellation policy actions, and session rescheduling.
class ClientBookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const ClientBookingDetailScreen({
    super.key,
    required this.booking,
  });

  @override
  State<ClientBookingDetailScreen> createState() => _ClientBookingDetailScreenState();
}

class _ClientBookingDetailScreenState extends State<ClientBookingDetailScreen> {
  final _firestoreService = FirestoreService();
  late BookingModel _currentBooking;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
  }

  /// Cancels booking per Section 8:
  /// >= 12 hours: credit returned
  /// < 12 hours: credit forfeited
  Future<void> _handleCancelBooking() async {
    final hoursUntil = _currentBooking.hoursUntilSession;
    final isEarly = _currentBooking.isCancellationCreditRefundable;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEarly ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEarly ? Iconsax.info_circle : Iconsax.warning_2,
                color: isEarly ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cancel Session?',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEarly
                  ? 'You are cancelling ${hoursUntil.toStringAsFixed(1)} hours before your workout.'
                  : 'You are cancelling only ${hoursUntil.toStringAsFixed(1)} hours before your workout.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: kDark),
            ),
            const SizedBox(height: 10),
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
                    isEarly ? Iconsax.tick_circle : Icons.error_outline,
                    size: 16,
                    color: isEarly ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEarly
                          ? 'Full Credit Return: Since this is >= 12h before start, 1 session credit will be returned to your account balance.'
                          : 'Late Cancellation Penalty: Cancellations within 12h forfeit the session credit per Section 8 policy.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: isEarly ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your trainer will be notified immediately.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking', style: TextStyle(fontFamily: 'Poppins', color: kDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Confirm Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() => _isCancelling = true);
    HapticFeedback.mediumImpact();

    try {
      final returned = await _firestoreService.cancelBookingAsClient(
        bookingId: _currentBooking.id,
        clientId: _currentBooking.clientId,
      );

      if (!mounted) return;

      setState(() {
        _isCancelling = false;
        _currentBooking = _currentBooking.copyWith(
          status: returned ? BookingStatus.cancelledClientEarly : BookingStatus.cancelledClientLate,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            returned
                ? 'Booking cancelled. 1 session credit returned to your balance.'
                : 'Booking cancelled. Credit forfeited due to late cancellation (<12h).',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: returned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancellation failed: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _handleReschedule() {
    HapticFeedback.mediumImpact();
    ClientRescheduleModal.show(
      context,
      booking: _currentBooking,
      onRescheduled: () async {
        final updated = await _firestoreService.getBooking(_currentBooking.id);
        if (updated != null && mounted) {
          setState(() => _currentBooking = updated);
        }
      },
    );
  }

  void _handleViewReceipt() {
    final payment = PaymentModel(
      id: _currentBooking.paymentTransactionId ?? 'pay_${_currentBooking.id}',
      clientId: _currentBooking.clientId,
      planId: _currentBooking.resolvedPackageId,
      packageName: _currentBooking.resolvedPackageName,
      sessionsCount: _currentBooking.sessionsCount ?? _currentBooking.resolvedTotalSessions,
      validityDays: _currentBooking.validityDays ?? _currentBooking.resolvedTotalDays,
      amount: _currentBooking.packagePrice ?? 10799,
      status: PaymentStatus.success,
      gatewayOrderId: 'order_${_currentBooking.id}',
      receiptNumber: 'REC-${_currentBooking.id.substring(0, 8).toUpperCase()}',
      bookingId: _currentBooking.id,
      trainerId: _currentBooking.trainerId,
      trainerName: _currentBooking.displayTrainerName,
      creditsGranted: true,
      verifiedAt: _currentBooking.createdAt,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientPaymentReceiptScreen(payment: payment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return StreamBuilder<BookingModel?>(
      stream: _firestoreService.streamBooking(widget.booking.id),
      initialData: _currentBooking,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _currentBooking = snapshot.data!;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Booking Details',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (16.5 * sf).clamp(15.0, 18.0),
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
                // ── 0. CANCELLATION OUTCOME BANNER (IF CANCELLED) ──
                _buildCancellationOutcomeBanner(sf),

                // ── 1. TRAINER IDENTITY CARD ──
                _buildTrainerCard(sf),
                const SizedBox(height: 16),

                // ── 2. DATE, TIME & 60-MIN DURATION CARD ──
                _buildTimingCard(sf),
                const SizedBox(height: 16),

                // ── 3. TRAINING LOCATION ──
                _buildLocationCard(sf),
                const SizedBox(height: 16),

                // ── 4. PACKAGE & PAYMENT STATUS CARD ──
                _buildPackageStatusCard(sf),
                const SizedBox(height: 16),

                // ── 5. SECTION 8 CANCELLATION ADVISORY CARD ──
                _buildPolicyAdvisoryCard(sf),
              ],
            ),
          ),
          bottomSheet: _buildBottomActions(sf, hPad),
        );
      },
    );
  }

  Widget _buildCancellationOutcomeBanner(double sf) {
    if (!_currentBooking.isCancelled) return const SizedBox.shrink();

    final isReturned = _currentBooking.isCreditReturned;
    final isForfeited = _currentBooking.isCreditForfeited;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReturned ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReturned ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReturned ? Iconsax.tick_circle : Iconsax.warning_2,
            size: 20,
            color: isReturned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReturned
                      ? 'Session Cancelled • 1 Credit Returned'
                      : (isForfeited
                          ? 'Session Cancelled • 1 Credit Forfeited'
                          : 'Session Cancelled'),
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.0 * sf).clamp(12.0, 14.5),
                    fontWeight: FontWeight.w800,
                    color: isReturned ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isReturned
                      ? 'Because this session was cancelled >= 12h before start (or by trainer/platform), 1 session credit has been safely returned to your available balance.'
                      : 'Because this session was cancelled within 12h of workout start, 1 session credit was forfeited in accordance with Section 8 policy.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (11.0 * sf).clamp(10.0, 12.0),
                    color: isReturned ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: kDark,
            backgroundImage: _currentBooking.trainerPhotoUrl != null &&
                    _currentBooking.trainerPhotoUrl!.isNotEmpty
                ? NetworkImage(_currentBooking.trainerPhotoUrl!)
                : null,
            child: _currentBooking.trainerPhotoUrl == null ||
                    _currentBooking.trainerPhotoUrl!.isEmpty
                ? Text(
                    _currentBooking.displayTrainerName.isNotEmpty
                        ? _currentBooking.displayTrainerName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(fontFamily: 'Syne', fontSize: 20, color: kLime, fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _currentBooking.displayTrainerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (16.0 * sf).clamp(14.5, 17.5),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_currentBooking.displayWorkoutType} • Personal Trainer',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (11.5 * sf).clamp(10.5, 12.5),
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Certified Personal Trainer • Verified',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.0 * sf).clamp(9.0, 11.0),
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientChatScreen(
                          conversation: ConversationModel(
                            id: ConversationModel.generateId(_currentBooking.clientId, _currentBooking.trainerId),
                            clientId: _currentBooking.clientId,
                            trainerId: _currentBooking.trainerId,
                            bookingId: _currentBooking.id,
                            trainerName: _currentBooking.displayTrainerName,
                            trainerPhotoUrl: _currentBooking.trainerPhotoUrl,
                            clientName: FirebaseAuth.instance.currentUser?.displayName ?? 'Athlete',
                          ),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.message, size: 13, color: kLime),
                        SizedBox(width: 5),
                        Text(
                          'Message Trainer',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingCard(double sf) {
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
                'WORKOUT SCHEDULE',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(10.0, 12.0),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kLime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '60 Mins',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Iconsax.calendar_1,
            label: 'Session Date',
            value: _formatFullDate(_currentBooking.sessionDate),
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Iconsax.clock,
            label: 'Session Time',
            value: '${_currentBooking.startTime} - ${_currentBooking.endTime}',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Iconsax.timer_1,
            label: 'Duration',
            value: _currentBooking.sessionDurationDisplay,
            sf: sf,
          ),
          if (_currentBooking.isRescheduled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.refresh, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rescheduled from ${_formatShortDate(_currentBooking.previousSessionDate)} (${_currentBooking.previousStartTime ?? "prev slot"})',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(double sf) {
    final meetingLoc = _currentBooking.meetingLocation ??
        _currentBooking.locationReference ??
        'Training Location';

    final isHomeAddress = meetingLoc.toLowerCase().contains('flat') ||
        meetingLoc.toLowerCase().contains('apartment') ||
        meetingLoc.toLowerCase().contains('house') ||
        meetingLoc.toLowerCase().contains('home') ||
        meetingLoc.toLowerCase().contains('residence') ||
        meetingLoc.toLowerCase().contains('villa') ||
        meetingLoc.toLowerCase().contains('tower') ||
        meetingLoc.toLowerCase().contains('floor');

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
              Row(
                children: [
                  const Icon(Iconsax.location, size: 16, color: kDark),
                  const SizedBox(width: 8),
                  Text(
                    'TRAINING ADDRESS',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (11.0 * sf).clamp(10.0, 12.0),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF888888),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (isHomeAddress)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 11, color: Color(0xFF16A34A)),
                      SizedBox(width: 3),
                      Text(
                        'Private Residence',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meetingLoc,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (12.5 * sf).clamp(11.5, 13.5),
              fontWeight: FontWeight.w600,
              color: kDark,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isHomeAddress
                        ? 'Athlete\'s Private Residence • Protected • Disclosed only to your booked trainer'
                        : 'Verified service area • Private client address protected',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.0 * sf).clamp(9.0, 11.0),
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageStatusCard(double sf) {
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
                'PACKAGE & STATUS DETAILS',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(10.0, 12.0),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _currentBooking.bookingReference));
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking reference copied to clipboard!'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      _currentBooking.bookingReference,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Iconsax.copy, size: 12, color: Color(0xFF6B7280)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Iconsax.card,
            label: 'Training Package',
            value: _currentBooking.resolvedPackageName,
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Iconsax.calendar_tick,
            label: 'Package Validity',
            value: '${_currentBooking.resolvedTotalDays} Days (${_currentBooking.resolvedDaysRemaining} days left)',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Iconsax.ticket,
            label: 'Session Allowance',
            value: '${_currentBooking.resolvedSessionsCompleted} done / ${_currentBooking.resolvedTotalSessions} total',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Iconsax.verify,
            label: 'Booking Status',
            valueWidget: _buildBookingStatusChip(_currentBooking),
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Iconsax.wallet_check,
            label: 'Payment Status',
            valueWidget: _buildPaymentStatusChip(_currentBooking),
            sf: sf,
          ),
          if (_currentBooking.packagePrice != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Iconsax.receipt,
              label: 'Package Price',
              value: '₹${_currentBooking.packagePrice}',
              sf: sf,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPolicyAdvisoryCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.info_circle, size: 18, color: kDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '12-Hour Cancellation Rule (Section 8)',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (11.5 * sf).clamp(10.5, 12.5),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '• Cancellations 12+ hours before session: full credit returned.\n• Cancellations < 12 hours: session credit forfeited.\n• Trainer or platform cancellation: credit returned.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (10.5 * sf).clamp(9.5, 11.5),
                    color: const Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    required double sf,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.5 * sf).clamp(10.5, 12.5),
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        if (valueWidget != null)
          valueWidget
        else if (value != null)
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (12.5 * sf).clamp(11.5, 13.5),
              fontWeight: FontWeight.w700,
              color: kDark,
            ),
          ),
      ],
    );
  }

  Widget _buildBookingStatusChip(BookingModel booking) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        booking.displayStatus,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(BookingModel booking) {
    final isPaid = booking.paymentStatus == PaymentStatus.completed ||
        booking.paymentStatus == PaymentStatus.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPaid ? 'Paid & Verified' : 'Pending Payment',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        ),
      ),
    );
  }

  Widget? _buildBottomActions(double sf, double hPad) {
    final canModify = _currentBooking.status == BookingStatus.confirmed ||
        _currentBooking.status == BookingStatus.pending;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          if (canModify) ...[
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _handleCancelBooking,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                      )
                    : const Text(
                        'Cancel Session',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Reschedule button
            Expanded(
              child: ElevatedButton(
                onPressed: _handleReschedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  foregroundColor: kLime,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Reschedule',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: kLime,
                  ),
                ),
              ),
            ),
          ] else ...[
            // View Receipt button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleViewReceipt,
                icon: const Icon(Iconsax.receipt, size: 16, color: kDark),
                label: const Text(
                  'View Payment Receipt',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: kDark,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLime,
                  foregroundColor: kDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatFullDate(DateTime dt) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return 'previous date';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
