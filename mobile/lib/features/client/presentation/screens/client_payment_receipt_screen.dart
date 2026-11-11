import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Screen displaying the official payment receipt with transaction details,
/// activated session credits notice, linked booking confirmation (if applicable),
/// and ability to share or save the receipt.
class ClientPaymentReceiptScreen extends StatelessWidget {
  final PaymentModel payment;
  final TrainerDisplayModel? trainer;
  final BookingModel? booking;

  const ClientPaymentReceiptScreen({
    super.key,
    required this.payment,
    this.trainer,
    this.booking,
  });

  void _handleShareReceipt(BuildContext context) {
    HapticFeedback.selectionClick();
    final receiptText = '''
====================================
           TRAIN Z RECEIPT
====================================
Receipt No: ${payment.displayReceiptNumber}
Payment ID: ${payment.razorpayPaymentId ?? payment.id}
Date: ${payment.verifiedAt != null ? payment.verifiedAt.toString().substring(0, 16) : DateTime.now().toString().substring(0, 16)}
Package: ${payment.displayPackageName}
Sessions: ${payment.sessionsCount ?? 1} Sessions (60 mins each)
Validity: ${payment.validityDays ?? 30} Days
Amount Paid: ₹${payment.amount}
Status: VERIFIED & CONFIRMED
${trainer != null ? "Assigned Trainer: ${trainer!.displayName}" : ""}
${booking != null ? "First Session: ${booking!.sessionDate.day}/${booking!.sessionDate.month}/${booking!.sessionDate.year} at ${booking!.startTime}" : ""}
====================================
Powered by Razorpay & TRAIN Z Platform
''';

    Clipboard.setData(ClipboardData(text: receiptText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.copy_rounded, color: kLime, size: 18),
            SizedBox(width: 10),
            Text('Receipt details copied to clipboard!', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
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
          'Payment Receipt',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 21.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: kDark, size: 20),
            tooltip: 'Share Receipt',
            onPressed: () => _handleShareReceipt(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 120),
        child: Column(
          children: [
            // ── RECEIPT CARD ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Green check circle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment Successful',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (20.0 * sf).clamp(18.0, 23.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${payment.amount}',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (32.0 * sf).clamp(28.0, 38.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RECEIPT: ${payment.displayReceiptNumber}',
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),

                  // Session Credits Allocated Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.token, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+${payment.sessionsCount ?? 1} Session Credits Activated',
                                style: const TextStyle(fontFamily: 'Syne', fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                              ),
                              const Text(
                                'Added to your athlete ledger balance.',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receipt Line Items
                  _buildReceiptRow('Package Purchased', payment.displayPackageName),
                  _buildReceiptRow('Sessions', '${payment.sessionsCount ?? 1} Sessions (60 mins each)'),
                  _buildReceiptRow('Validity Duration', '${payment.validityDays ?? 30} Days'),
                  _buildReceiptRow('Payment ID', payment.razorpayPaymentId ?? 'pay_sandbox_test'),
                  _buildReceiptRow('Payment Method', payment.paymentMethod ?? 'Razorpay Gateway'),
                  _buildReceiptRow('Date & Time', _formatTimestamp(payment.verifiedAt ?? payment.createdAt)),

                  if (trainer != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                    ),
                    _buildReceiptRow('Assigned Trainer', trainer!.displayName),
                  ],

                  if (booking != null) ...[
                    _buildReceiptRow('First Session Slot', '${booking!.sessionDate.day}/${booking!.sessionDate.month}/${booking!.sessionDate.year} • ${booking!.startTime}'),
                    _buildReceiptRow('Location', booking!.meetingLocation ?? 'Selected Location'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text('Booking Automatically Confirmed', style: TextStyle(fontFamily: 'Syne', fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleShareReceipt(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share, size: 16, color: kDark),
                      SizedBox(width: 6),
                      Text('Share / Save', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    foregroundColor: kLime,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    booking != null ? 'View My Bookings' : 'Find a Trainer & Book',
                    style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kLime, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: kDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Just now';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
