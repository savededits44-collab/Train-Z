import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/credit_service.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Card displaying an official fixed platform package from Firestore.
class ClientPackageCard extends StatefulWidget {
  final TrainingPlanModel plan;
  final String clientId;
  final VoidCallback? onPurchased;

  const ClientPackageCard({
    super.key,
    required this.plan,
    required this.clientId,
    this.onPurchased,
  });

  @override
  State<ClientPackageCard> createState() => _ClientPackageCardState();
}

class _ClientPackageCardState extends State<ClientPackageCard> {
  bool _purchasing = false;

  void _showPurchaseConfirmation() {
    final sf = scaleFactor(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.card, color: kLime, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirm Package',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (18.0 * sf).clamp(16.0, 20.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are activating the ${widget.plan.title} package.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  children: [
                    _DialogRow(label: 'Total Sessions', value: '${widget.plan.sessionsCount} Sessions (60m)'),
                    const SizedBox(height: 6),
                    _DialogRow(label: 'Validity', value: '${widget.plan.validityDays} Days'),
                    const SizedBox(height: 6),
                    _DialogRow(label: 'Price per Session', value: '₹${widget.plan.pricePerSession.round()}'),
                    const Divider(height: 16),
                    _DialogRow(
                      label: 'Total Amount',
                      value: '₹${widget.plan.price}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your session credit balance will be credited instantly upon confirmation.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: kGrey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: kGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _executePurchase();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Confirm & Credit',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kLime),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executePurchase() async {
    setState(() => _purchasing = true);
    HapticFeedback.mediumImpact();

    try {
      final paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';

      await CreditService().recordPurchase(
        clientId: widget.clientId,
        sessionCount: widget.plan.sessionsCount,
        paymentId: paymentId,
        planId: widget.plan.id,
      );

      if (!mounted) return;

      widget.onPurchased?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Success! +${widget.plan.sessionsCount} session credits added to your account.',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment/credit failed: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final isPopular = widget.plan.popular || widget.plan.id == 'plan_1_month';
    final isBestValue = widget.plan.id == 'plan_6_months';

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isPopular ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? kLime.withValues(alpha: 0.8) : const Color(0xFFEEEEEE),
          width: isPopular ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPopular ? 0.12 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.plan.title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (12.0 * sf).clamp(11.0, 13.5),
                        fontWeight: FontWeight.w800,
                        color: isPopular ? const Color(0xFFAAAAAA) : const Color(0xFF888888),
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                      )
                    else if (isBestValue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BEST VALUE',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${widget.plan.price}',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (26.0 * sf).clamp(22.0, 30.0),
                        fontWeight: FontWeight.w800,
                        color: isPopular ? Colors.white : kDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ ${widget.plan.validityDays} ${widget.plan.validityDays == 1 ? "day" : "days"}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.0 * sf).clamp(10.0, 12.5),
                        color: isPopular ? const Color(0xFFAAAAAA) : kGrey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Per session rate pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPopular
                        ? kLime.withValues(alpha: 0.18)
                        : const Color(0xFFF4F9F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '₹${widget.plan.pricePerSession.round()} per 60-min session',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.0 * sf).clamp(9.0, 11.5),
                      fontWeight: FontWeight.w700,
                      color: isPopular ? kLime : const Color(0xFF15803D),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Features
                _FeatureLine(
                  text: '${widget.plan.sessionsCount} Personal 1-on-1 Sessions',
                  isDark: isPopular,
                  sf: sf,
                ),
                const SizedBox(height: 6),
                _FeatureLine(
                  text: '${widget.plan.validityDays} Days Validity Window',
                  isDark: isPopular,
                  sf: sf,
                ),
                const SizedBox(height: 6),
                _FeatureLine(
                  text: '60 Minutes per workout',
                  isDark: isPopular,
                  sf: sf,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Select CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _purchasing ? null : _showPurchaseConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? kLime : kDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _purchasing
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isPopular ? kDark : Colors.white,
                        ),
                      )
                    : Text(
                        'Select Package',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (12.5 * sf).clamp(11.5, 14.0),
                          fontWeight: FontWeight.w800,
                          color: isPopular ? kDark : Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final String text;
  final bool isDark;
  final double sf;

  const _FeatureLine({required this.text, required this.isDark, required this.sf});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: isDark ? kLime : const Color(0xFF16A34A),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(10.0, 12.5),
              color: isDark ? const Color(0xFFDDDDDD) : const Color(0xFF444444),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DialogRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: isBold ? 13 : 12,
            color: isBold ? kDark : kGrey,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: isBold ? 15 : 12,
            color: isBold ? kDark : const Color(0xFF222222),
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

