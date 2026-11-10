import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Screen allowing clients to select a training package for their chosen trainer.
/// Displays all 6 TRAIN Z official packages, pricing per session, validity, and perks.
class ClientPackageSelectionScreen extends StatefulWidget {
  final TrainerDisplayModel trainer;
  final Gender clientGender;
  final String clientId;

  const ClientPackageSelectionScreen({
    super.key,
    required this.trainer,
    required this.clientGender,
    required this.clientId,
  });

  @override
  State<ClientPackageSelectionScreen> createState() => _ClientPackageSelectionScreenState();
}

class _ClientPackageSelectionScreenState extends State<ClientPackageSelectionScreen> {
  String? _selectedPlanId = 'plan_monthly'; // Default to Monthly Transformation

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.065).clamp(18.0, 28.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: kDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select Package',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (17.0 * sf).clamp(15.0, 19.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Selected Trainer Summary Card ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF111111),
                    backgroundImage: (widget.trainer.photoUrl != null && widget.trainer.photoUrl!.isNotEmpty)
                        ? NetworkImage(widget.trainer.photoUrl!)
                        : null,
                    child: (widget.trainer.photoUrl == null || widget.trainer.photoUrl!.isEmpty)
                        ? Text(
                            widget.trainer.displayName.isNotEmpty
                                ? widget.trainer.displayName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kLime,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.trainer.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: Color(0xFF16A34A)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.trainer.gymName ?? 'TRAIN Z Certified Coach',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: kGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.trainer.ratingText} (${widget.trainer.totalReviews} reviews)',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Training Packages',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (18.0 * sf).clamp(16.0, 22.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how many 1-on-1 sessions you want in your training block. All sessions include 12-hour refund protection.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.5 * sf).clamp(10.5, 13.0),
                color: kGrey,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            // ── Stream / Fallback Packages ──
            StreamBuilder<List<TrainingPlanModel>>(
              stream: FirestoreService().streamTrainingPlans(),
              builder: (context, snapshot) {
                var plans = snapshot.data ?? [];
                if (plans.isEmpty) {
                  plans = AppConstants.fixedTrainingPlans.map((p) {
                    return TrainingPlanModel(
                      id: p['id'] as String,
                      title: p['title'] as String,
                      price: p['price'] as int,
                      sessionsCount: p['sessions'] as int,
                      validityDays: p['validityDays'] as int,
                      description: p['description'] as String,
                      popular: p['popular'] as bool? ?? false,
                    );
                  }).toList();
                }

                // Ensure initial selection exists in the loaded plans
                if (_selectedPlanId == null && plans.isNotEmpty) {
                  _selectedPlanId = plans.first.id;
                }

                return Column(
                  children: plans.map((plan) {
                    final isSelected = _selectedPlanId == plan.id;
                    final pricePerSession = plan.pricePerSession.round();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF9FFF2) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? kLime : const Color(0xFFE5E5E5),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? kLime.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPlanId = plan.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Title, popular badge, and selection check
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            plan.title,
                                            style: TextStyle(
                                              fontFamily: 'Syne',
                                              fontSize: (15.0 * sf).clamp(14.0, 17.0),
                                              fontWeight: FontWeight.w800,
                                              color: kDark,
                                            ),
                                          ),
                                          if (plan.popular) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: kDark,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'POPULAR',
                                                style: TextStyle(
                                                  fontFamily: 'Syne',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: kLime,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? kDark : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? kDark : const Color(0xFFCCCCCC),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 14, color: kLime)
                                          : null,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  plan.description,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (11.0 * sf).clamp(10.0, 12.5),
                                    color: const Color(0xFF555555),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Metrics row: Price, Per Session, and Validity
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₹${plan.price}',
                                          style: TextStyle(
                                            fontFamily: 'Syne',
                                            fontSize: (18.0 * sf).clamp(16.0, 22.0),
                                            fontWeight: FontWeight.w800,
                                            color: kDark,
                                          ),
                                        ),
                                        Text(
                                          '₹$pricePerSession per session',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: (10.0 * sf).clamp(9.0, 11.5),
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${plan.sessionsCount} ${plan.sessionsCount == 1 ? "Session" : "Sessions"} • ${plan.validityDays}d validity',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: (10.5 * sf).clamp(9.5, 12.0),
                                          fontWeight: FontWeight.w600,
                                          color: kDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 16),

            // ── What's Included Card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EVERY PACKAGE INCLUDES',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kGrey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPerkItem(
                    icon: Icons.fitness_center,
                    title: '1-on-1 Dedicated Training',
                    subtitle: 'Full 60-minute in-person session tailored to your body type.',
                    sf: sf,
                  ),
                  _buildPerkItem(
                    icon: Icons.shield_outlined,
                    title: '12-Hour Cancellation Protection',
                    subtitle: 'Cancel up to 12 hours before session for 100% credit refund.',
                    sf: sf,
                  ),
                  _buildPerkItem(
                    icon: Icons.verified_user_outlined,
                    title: 'Strict Gender-Matched Coaching',
                    subtitle: 'Certified coach matching your preference verified on backend.',
                    sf: sf,
                  ),
                  _buildPerkItem(
                    icon: Icons.trending_up,
                    title: 'Progressive Overload Tracking',
                    subtitle: 'Structured workout log and milestone tracking via TRAIN Z.',
                    sf: sf,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100), // Space for sticky bottom bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: StreamBuilder<List<TrainingPlanModel>>(
            stream: FirestoreService().streamTrainingPlans(),
            builder: (context, snapshot) {
              var plans = snapshot.data ?? [];
              if (plans.isEmpty) {
                plans = AppConstants.fixedTrainingPlans.map((p) {
                  return TrainingPlanModel(
                    id: p['id'] as String,
                    title: p['title'] as String,
                    price: p['price'] as int,
                    sessionsCount: p['sessions'] as int,
                    validityDays: p['validityDays'] as int,
                    description: p['description'] as String,
                    popular: p['popular'] as bool? ?? false,
                  );
                }).toList();
              }

              final selectedPlan = plans.firstWhere(
                (p) => p.id == _selectedPlanId,
                orElse: () => plans.first,
              );

              return Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedPlan.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: kGrey,
                        ),
                      ),
                      Text(
                        '₹${selectedPlan.price}',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (18.0 * sf).clamp(16.0, 22.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (sheetContext) => Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDDDDD),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF4F9F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Iconsax.tick_circle, color: Color(0xFF16A34A), size: 36),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Package Selected!',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (20.0 * sf).clamp(18.0, 24.0),
                                    fontWeight: FontWeight.w800,
                                    color: kDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You selected ${selectedPlan.title} (${selectedPlan.sessionsCount} Sessions for ₹${selectedPlan.price}) with Coach ${widget.trainer.displayName}.\n\nFinal checkout and payment will be processed in the next step.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                                    color: const Color(0xFF555555),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kDark,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Done',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Iconsax.arrow_right_3, size: 16, color: kDark),
                      label: const Text(
                        'Proceed with Package',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLime,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPerkItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required double sf,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: kDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (10.5 * sf).clamp(9.5, 12.0),
                    color: kGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

