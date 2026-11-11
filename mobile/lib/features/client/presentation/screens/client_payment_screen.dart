import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../services/payment_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_payment_receipt_screen.dart';

/// Screen displaying the Payment Summary, Razorpay Checkout integration,
/// backend signature verification, and sandbox testing capabilities.
class ClientPaymentScreen extends StatefulWidget {
  final TrainingPlanModel plan;
  final TrainerDisplayModel? trainer;
  final BookingModel? booking;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;

  const ClientPaymentScreen({
    super.key,
    required this.plan,
    this.trainer,
    this.booking,
    required this.clientId,
    this.clientName = 'TRAIN Z Athlete',
    this.clientEmail = 'athlete@trainz.com',
    this.clientPhone = '+91 98201 54321',
  });

  @override
  State<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends State<ClientPaymentScreen> {
  final _paymentService = PaymentService();

  RazorpayOrderData? _currentOrder;
  bool _isCreatingOrder = false;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _paymentService.initializeRazorpay(
      onSuccess: _onRazorpaySuccess,
      onError: _onRazorpayError,
      onExternalWallet: _onRazorpayExternalWallet,
    );
  }

  @override
  void dispose() {
    _paymentService.disposeRazorpay();
    super.dispose();
  }

  /// Starts the Razorpay payment checkout flow
  Future<void> _handleStartPayment() async {
    setState(() {
      _isCreatingOrder = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      // 1. Server-side order creation with authoritative package pricing
      final orderData = await _paymentService.createOrder(
        packageId: widget.plan.id,
        clientId: widget.clientId,
        bookingId: widget.booking?.id,
        trainerId: widget.trainer?.uid,
        trainerName: widget.trainer?.displayName,
      );

      _currentOrder = orderData;
      if (!mounted) return;

      setState(() => _isCreatingOrder = false);

      // 2. Open official Razorpay Checkout SDK
      _paymentService.openCheckout(
        orderData: orderData,
        clientName: widget.clientName,
        clientEmail: widget.clientEmail,
        clientPhone: widget.clientPhone,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreatingOrder = false;
        _errorMessage = 'Order creation failed: $e';
      });
    }
  }

  /// Razorpay Success Callback
  Future<void> _onRazorpaySuccess(PaymentSuccessResponse response) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final paymentDocId = _currentOrder?.paymentDocId ?? '';
      final orderId = response.orderId ?? _currentOrder?.orderId ?? '';
      final paymentId = response.paymentId ?? '';
      final signature = response.signature ?? '';

      // Backend signature verification & session credits allocation
      final finalizedPayment = await _paymentService.verifyPayment(
        paymentDocId: paymentDocId,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        paymentMethod: 'RAZORPAY_CHECKOUT',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPaymentReceiptScreen(
            payment: finalizedPayment,
            trainer: widget.trainer,
            booking: widget.booking,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Payment verification failed: $e';
      });
    }
  }

  /// Razorpay Error Callback (User cancelled or payment failed)
  Future<void> _onRazorpayError(PaymentFailureResponse response) async {
    HapticFeedback.mediumImpact();
    if (_currentOrder != null) {
      await _paymentService.recordFailure(
        paymentDocId: _currentOrder!.paymentDocId,
        errorCode: response.code.toString(),
        errorDescription: response.message,
      );
    }

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _errorMessage = response.message != null && response.message!.isNotEmpty
          ? 'Payment cancelled or failed: ${response.message}'
          : 'Payment cancelled or dismissed. No credits were deducted.';
    });
  }

  /// External Wallet Callback
  void _onRazorpayExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay external wallet selected: ${response.walletName}');
  }

  /// Sandbox Simulation / Test-mode payment verification
  Future<void> _handleTestModePayment() async {
    setState(() {
      _isCreatingOrder = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final orderData = await _paymentService.createOrder(
        packageId: widget.plan.id,
        clientId: widget.clientId,
        bookingId: widget.booking?.id,
        trainerId: widget.trainer?.uid,
        trainerName: widget.trainer?.displayName,
      );

      _currentOrder = orderData;
      setState(() {
        _isCreatingOrder = false;
        _isVerifying = true;
      });

      // Generate verified test signature for sandbox verification
      final testPaymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';
      final testSignature = PaymentService.generateTestSignature(orderData.orderId, testPaymentId);

      // Verify and finalize via backend
      final finalized = await _paymentService.verifyPayment(
        paymentDocId: orderData.paymentDocId,
        razorpayOrderId: orderData.orderId,
        razorpayPaymentId: testPaymentId,
        razorpaySignature: testSignature,
        paymentMethod: 'TEST_UPI_SANDBOX',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPaymentReceiptScreen(
            payment: finalized,
            trainer: widget.trainer,
            booking: widget.booking,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreatingOrder = false;
        _isVerifying = false;
        _errorMessage = 'Sandbox simulation failed: $e';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Summary',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (16.0 * sf).clamp(15.0, 18.0),
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
            // ── 1. PACKAGE & COACH SUMMARY CARD ──
            _buildPackageSummaryCard(sf),
            const SizedBox(height: 16),

            // ── 2. BOOKING DETAILS (IF ATTACHED) ──
            if (widget.booking != null) ...[
              _buildLinkedBookingCard(sf),
              const SizedBox(height: 16),
            ],

            // ── 3. PRICE & TAX BREAKDOWN ──
            _buildPriceBreakdownCard(sf),
            const SizedBox(height: 16),

            // ── 4. RAZORPAY METHODS BADGE ──
            _buildRazorpayMethodsCard(sf),
            const SizedBox(height: 16),

            // ── 5. SECURITY & IDEMPOTENCY BADGE ──
            _buildSecurityBadge(sf),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINAL AMOUNT',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (10.0 * sf).clamp(9.0, 11.0),
                          fontWeight: FontWeight.w600,
                          color: kGrey,
                        ),
                      ),
                      Text(
                        '₹${widget.plan.price}',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (22.0 * sf).clamp(19.0, 24.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreatingOrder || _isVerifying ? null : _handleStartPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDark,
                        foregroundColor: kLime,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isCreatingOrder || _isVerifying
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isVerifying ? 'Verifying...' : 'Preparing...',
                                  style: const TextStyle(fontFamily: 'Syne', fontSize: 13, color: kLime, fontWeight: FontWeight.w700),
                                ),
                              ],
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Iconsax.lock, size: 16, color: kLime),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay ₹${widget.plan.price} (Razorpay)',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (13.5 * sf).clamp(12.5, 15.0),
                                      fontWeight: FontWeight.w800,
                                      color: kLime,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Sandbox Test Mode Trigger
              InkWell(
                onTap: _isCreatingOrder || _isVerifying ? null : _handleTestModePayment,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          'Test Mode Simulation (Instant Sandbox Verification)',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(10.0, 11.5),
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Package & Coach Card ──
  Widget _buildPackageSummaryCard(double sf) {
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
                widget.plan.title,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (17.0 * sf).clamp(15.0, 20.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${widget.plan.price}',
                  style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: kDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.plan.description,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey, height: 1.35),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          _buildSummaryRow('Sessions Included', '${widget.plan.sessionsCount} Sessions (60 mins each)'),
          _buildSummaryRow('Rate Per Session', '₹${widget.plan.pricePerSession.round()}/session'),
          _buildSummaryRow('Package Validity', '${widget.plan.validityDays} Days from activation'),
          if (widget.trainer != null) ...[
            const SizedBox(height: 4),
            _buildSummaryRow('Assigned Coach', widget.trainer!.displayName),
          ],
        ],
      ),
    );
  }

  // ── 2. Linked Booking Card ──
  Widget _buildLinkedBookingCard(double sf) {
    final b = widget.booking!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.calendar_tick, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LINKED FIRST SESSION',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
                Text(
                  '${b.sessionDate.day} ${_getShortMonth(b.sessionDate.month)} • ${b.startTime} - ${b.endTime}',
                  style: const TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: kDark),
                ),
                Text(
                  b.meetingLocation ?? 'Selected Location',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Price Breakdown ──
  Widget _buildPriceBreakdownCard(double sf) {
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
          Text(
            'PRICE BREAKDOWN',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (11.5 * sf).clamp(10.5, 13.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Package Cost', '₹${widget.plan.price}'),
          _buildSummaryRow('Platform Booking Fee', 'FREE (₹0)'),
          _buildSummaryRow('Goods & Services Tax (GST)', 'Included'),
          const Divider(height: 18, color: Color(0xFFF0F0F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Payable', style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.w800, color: kDark)),
              Text('₹${widget.plan.price}', style: const TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w800, color: kDark)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Razorpay Methods Card ──
  Widget _buildRazorpayMethodsCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.card, size: 16, color: kDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ACCEPTED PAYMENT METHODS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (11.0 * sf).clamp(10.0, 12.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMethodPill('UPI (GPay / PhonePe / Paytm)'),
              _buildMethodPill('Credit & Debit Cards (Visa / MC / RuPay)'),
              _buildMethodPill('Net Banking (50+ Banks)'),
              _buildMethodPill('Wallets'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodPill(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      ),
    );
  }

  // ── 5. Security Badge ──
  Widget _buildSecurityBadge(double sf) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.shield_tick, size: 16, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '256-Bit Encrypted Razorpay Gateway. Backend signature verification & idempotency guards prevent duplicate billing.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey)),
          Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: kDark)),
        ],
      ),
    );
  }

  String _getShortMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }
}
