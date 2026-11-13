import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../routing/app_router.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/payment_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_payment_receipt_screen.dart';

/// Available distinct payment status outcomes
enum PaymentStatusType {
  success,
  failed,
  cancelled,
  pendingVerification;

  String get title {
    switch (this) {
      case PaymentStatusType.success:
        return 'Payment Successful!';
      case PaymentStatusType.failed:
        return 'Payment Failed';
      case PaymentStatusType.cancelled:
        return 'Payment Cancelled';
      case PaymentStatusType.pendingVerification:
        return 'Payment Pending Verification';
    }
  }

  String get subtitle {
    switch (this) {
      case PaymentStatusType.success:
        return 'Your transaction is verified and your package is now active.';
      case PaymentStatusType.failed:
        return 'We were unable to complete your transaction with Razorpay.';
      case PaymentStatusType.cancelled:
        return 'The checkout process was cancelled or dismissed.';
      case PaymentStatusType.pendingVerification:
        return 'Awaiting authoritative verification from your bank / Razorpay.';
    }
  }
}

/// Comprehensive screen handling all post-checkout states:
/// - Payment successful
/// - Payment failed
/// - Payment cancelled
/// - Payment pending verification
/// - Package activated
/// - Booking confirmed
/// - Payment retry
class ClientPaymentStatusScreen extends StatefulWidget {
  final PaymentStatusType initialStatus;
  final PaymentModel? payment;
  final TrainingPlanModel? plan;
  final TrainerDisplayModel? trainer;
  final BookingModel? booking;
  final String? errorMessage;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final VoidCallback? onRetry;

  const ClientPaymentStatusScreen({
    super.key,
    required this.initialStatus,
    this.payment,
    this.plan,
    this.trainer,
    this.booking,
    this.errorMessage,
    required this.clientId,
    this.clientName = 'TRAIN Z Athlete',
    this.clientEmail = 'athlete@trainz.com',
    this.clientPhone = '+91 98201 54321',
    this.onRetry,
  });

  @override
  State<ClientPaymentStatusScreen> createState() => _ClientPaymentStatusScreenState();
}

class _ClientPaymentStatusScreenState extends State<ClientPaymentStatusScreen> {
  late PaymentStatusType _currentStatus;
  PaymentModel? _payment;
  StreamSubscription<PaymentModel?>? _paymentSub;
  bool _isRetrying = false;
  String? _retryError;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;
    _payment = widget.payment;

    // If pending verification, listen to Firestore updates for automatic transition
    if (_currentStatus == PaymentStatusType.pendingVerification && _payment != null) {
      _listenForPaymentFinalization();
    }
  }

  void _listenForPaymentFinalization() {
    if (_payment == null) return;
    _paymentSub = FirestoreService()
        .streamClientPayments(widget.clientId)
        .map((list) => list.firstWhere(
              (p) => p.id == _payment!.id,
              orElse: () => _payment!,
            ))
        .listen((updated) {
      if (updated.isSuccess && mounted) {
        setState(() {
          _payment = updated;
          _currentStatus = PaymentStatusType.success;
        });
        HapticFeedback.heavyImpact();
      } else if (updated.isFailed && mounted) {
        setState(() {
          _payment = updated;
          _currentStatus = PaymentStatusType.failed;
        });
      }
    });
  }

  @override
  void dispose() {
    _paymentSub?.cancel();
    super.dispose();
  }

  Future<void> _handleRetryPayment() async {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }

    if (widget.plan == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isRetrying = true;
      _retryError = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await PaymentService.instance.createOrder(
        packageId: widget.plan!.id,
        clientId: widget.clientId,
        bookingId: widget.booking?.id,
        trainerId: widget.trainer?.uid,
        trainerName: widget.trainer?.displayName,
      );

      setState(() => _isRetrying = false);

      if (!mounted) return;

      // Pop back to payment screen or restart checkout
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        _retryError = 'Retry failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          _currentStatus.title,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (17.0 * sf).clamp(15.0, 19.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: kDark),
            tooltip: 'Dismiss',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 120),
        child: Column(
          children: [
            // Status Icon Header
            _buildStatusHeader(sf),
            const SizedBox(height: 24),

            // Content according to current status
            if (_currentStatus == PaymentStatusType.success) ...[
              _buildSuccessPackageCard(sf),
              const SizedBox(height: 16),
              if (widget.booking != null) ...[
                _buildBookingConfirmedCard(sf),
                const SizedBox(height: 16),
              ],
              _buildTransactionCard(sf),
            ] else if (_currentStatus == PaymentStatusType.failed) ...[
              _buildFailedDetailsCard(sf),
              const SizedBox(height: 16),
              _buildNoDeductionBanner(sf),
            ] else if (_currentStatus == PaymentStatusType.cancelled) ...[
              _buildCancelledDetailsCard(sf),
              const SizedBox(height: 16),
              _buildNoDeductionBanner(sf),
            ] else if (_currentStatus == PaymentStatusType.pendingVerification) ...[
              _buildPendingVerificationCard(sf),
            ],

            if (_retryError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _retryError!,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomSheet: _buildBottomActionBar(sf, hPad),
    );
  }

  Widget _buildStatusHeader(double sf) {
    Color iconBg;
    Color iconColor;
    IconData icon;

    switch (_currentStatus) {
      case PaymentStatusType.success:
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        icon = Iconsax.tick_circle;
        break;
      case PaymentStatusType.failed:
        iconBg = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFDC2626);
        icon = Iconsax.close_circle;
        break;
      case PaymentStatusType.cancelled:
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        icon = Iconsax.info_circle;
        break;
      case PaymentStatusType.pendingVerification:
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        icon = Iconsax.clock;
        break;
    }

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 38),
        ),
        const SizedBox(height: 16),
        Text(
          _currentStatus.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (22.0 * sf).clamp(19.0, 25.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _currentStatus.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: kGrey,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ── Success: Package Activated Card ──
  Widget _buildSuccessPackageCard(double sf) {
    final pkgName = _payment?.displayPackageName ?? widget.plan?.title ?? 'Training Package';
    final sessions = _payment?.sessionsCount ?? widget.plan?.sessionsCount ?? 1;
    final validity = _payment?.validityDays ?? widget.plan?.validityDays ?? 30;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Iconsax.award, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'PACKAGE ACTIVATED',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 10.5, fontWeight: FontWeight.w800, color: kDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            pkgName,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (18.0 * sf).clamp(16.0, 20.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$sessions Sessions (60 mins each) • $validity Days Validity',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FBF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Credits Granted: +$sessions Sessions credited to your balance.',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
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

  // ── Success: Booking Confirmed Card ──
  Widget _buildBookingConfirmedCard(double sf) {
    final b = widget.booking!;
    final trainerName = widget.trainer?.displayName ?? b.trainerName ?? 'Personal Coach';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Iconsax.calendar_tick, color: kDark, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'BOOKING CONFIRMED',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Coach: $trainerName',
            style: const TextStyle(fontFamily: 'Syne', fontSize: 15, fontWeight: FontWeight.w700, color: kDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${b.sessionDate.day}/${b.sessionDate.month}/${b.sessionDate.year} at ${b.startTime} (60 min session)',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF4B5563)),
          ),
          if ((b.locationReference ?? b.meetingLocation ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Location: ${b.locationReference ?? b.meetingLocation}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
            ),
          ],
        ],
      ),
    );
  }

  // ── Success: Transaction Details Card ──
  Widget _buildTransactionCard(double sf) {
    final amount = _payment?.amount ?? widget.plan?.price ?? 0;
    final txnId = _payment?.razorpayPaymentId ?? _payment?.gatewayOrderId ?? 'pay_sandbox_test';
    final receipt = _payment?.displayReceiptNumber ?? 'REC-PENDING';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRANSACTION SUMMARY',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kDark,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildRow('Amount Paid', '₹$amount'),
          const SizedBox(height: 8),
          _buildRow('Transaction ID', txnId),
          const SizedBox(height: 8),
          _buildRow('Receipt Number', receipt),
          const SizedBox(height: 8),
          _buildRow('Payment Gateway', 'Razorpay Checkout (INR)'),
        ],
      ),
    );
  }

  // ── Failed: Failure Details Card ──
  Widget _buildFailedDetailsCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 8),
              Text(
                'PAYMENT INCOMPLETE',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.errorMessage ??
                _payment?.errorMessage ??
                'The transaction could not be processed by your bank or the payment gateway.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF374151), height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'You can retry with the same payment method or choose another UPI, Card, or Netbanking option.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
          ),
        ],
      ),
    );
  }

  // ── Cancelled: Details Card ──
  Widget _buildCancelledDetailsCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Iconsax.info_circle, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'CHECKOUT CANCELLED',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'You dismissed the Razorpay checkout window before payment completion.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF374151), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Pending Verification Card ──
  Widget _buildPendingVerificationCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Column(
        children: const [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: kDark),
          ),
          SizedBox(height: 16),
          Text(
            'Verifying with Payment Gateway',
            style: TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w700, color: kDark),
          ),
          SizedBox(height: 8),
          Text(
            'We are confirming your transaction with Razorpay. This page will update automatically once verified. Please do not close the app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: kGrey, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── No Deductions Banner ──
  Widget _buildNoDeductionBanner(double sf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: const [
          Icon(Iconsax.shield_tick, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Funds Safe: No session credits have been deducted. If any amount was debited by your bank, it will be automatically refunded within 3-5 business days.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF166534), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey)),
        Text(val, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: kDark)),
      ],
    );
  }

  Widget _buildBottomActionBar(double sf, double hPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentStatus == PaymentStatusType.success) ...[
              ElevatedButton.icon(
                onPressed: () {
                  if (_payment != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientPaymentReceiptScreen(
                          payment: _payment!,
                          trainer: widget.trainer,
                          booking: widget.booking,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Iconsax.receipt_2, color: kDark, size: 18),
                label: const Text(
                  'View Official Receipt',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.w800, color: kDark),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLime,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.clientHome,
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  side: const BorderSide(color: kDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: kDark),
                ),
              ),
            ] else if (_currentStatus == PaymentStatusType.failed || _currentStatus == PaymentStatusType.cancelled) ...[
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _handleRetryPayment,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                      )
                    : const Icon(Iconsax.refresh, color: kLime, size: 18),
                label: Text(
                  _isRetrying ? 'Preparing Checkout...' : 'Retry Payment',
                  style: const TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.w800, color: kLime),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Choose Another Package',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: kDark),
                ),
              ),
            ] else if (_currentStatus == PaymentStatusType.pendingVerification) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRouter.clientPaymentHistory,
                    arguments: {'clientId': widget.clientId},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'View Payment History',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: kLime),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
