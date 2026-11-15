import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../screens/client_payment_screen.dart';

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
  void _showPurchaseConfirmation() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientPaymentScreen(
          plan: widget.plan,
          clientId: widget.clientId,
          clientName: 'TRAIN Z Athlete',
        ),
      ),
    ).then((_) {
      if (mounted) widget.onPurchased?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final isPopular = widget.plan.popular || widget.plan.id == 'plan_1_month';
    final isBestValue = widget.plan.id == 'plan_6_months';

    return Container(
      width: (250.0 * sf).clamp(240.0, 280.0),
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? const Color(0xFF84CC00) : const Color(0xFFEEEEEE),
          width: isPopular ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPopular ? 0.06 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all((14.0 * sf).clamp(12.0, 16.0)),
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
                        fontFamily: 'Outfit',
                        fontSize: (12.0 * sf).clamp(11.0, 13.5),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
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
                            fontFamily: 'Outfit',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
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
                            fontFamily: 'Outfit',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
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
                        fontFamily: 'Outfit',
                        fontSize: (24.0 * sf).clamp(20.0, 28.0),
                        fontWeight: FontWeight.w600,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '/ ${widget.plan.validityDays} ${widget.plan.validityDays == 1 ? "day" : "days"}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          color: kGrey,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Per session rate pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '₹${widget.plan.pricePerSession.round()} per 60-min session',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: (10.0 * sf).clamp(9.0, 11.5),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Features
                _FeatureLine(
                  text: '${widget.plan.sessionsCount} Personal 1-on-1 Sessions',
                  sf: sf,
                ),
                const SizedBox(height: 6),
                _FeatureLine(
                  text: '${widget.plan.validityDays} Days Validity Window',
                  sf: sf,
                ),
                const SizedBox(height: 6),
                _FeatureLine(
                  text: '60 Minutes per workout',
                  sf: sf,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Select CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showPurchaseConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Select Package',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: (12.5 * sf).clamp(11.5, 14.0),
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
  final double sf;

  const _FeatureLine({required this.text, required this.sf});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: Color(0xFF16A34A),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: (11.0 * sf).clamp(10.0, 12.5),
              color: const Color(0xFF444444),
            ),
          ),
        ),
      ],
    );
  }
}

