import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/seed_service.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_booking_schedule_screen.dart';
import 'client_payment_screen.dart';

/// Screen allowing clients to view, compare and select a training package before booking a personal trainer.
/// Fetches all 6 official packages from the Firestore `training_plans` collection with transparent
/// pricing, 60-minute duration rules, validity expiry explanation, and 6-Month Transformation highlighting.
class ClientPackageSelectionScreen extends StatefulWidget {
  final TrainerDisplayModel? trainer;
  final Gender? clientGender;
  final String? clientId;

  const ClientPackageSelectionScreen({
    super.key,
    this.trainer,
    this.clientGender,
    this.clientId,
  });

  @override
  State<ClientPackageSelectionScreen> createState() => _ClientPackageSelectionScreenState();
}

class _ClientPackageSelectionScreenState extends State<ClientPackageSelectionScreen> {
  String? _selectedPlanId = 'plan_1_month'; // Default selection: 1 Month
  bool _showComparisonTable = false;

  void _onProceed(TrainingPlanModel plan) {
    HapticFeedback.mediumImpact();
    final sf = scaleFactor(context);

    // Show the next booking step sheet (No Razorpay payment or final booking confirmation here)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F9F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.tick_circle, color: Color(0xFF16A34A), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Package Selected',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (18.0 * sf).clamp(16.0, 22.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                      Text(
                        'Step 1 of 2 Complete',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.5),
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Selected Package', plan.title),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Session Count', '${plan.sessionsCount} Sessions (60 mins each)'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Total Price', '₹${plan.price} (₹${plan.pricePerSession.round()}/session)'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Validity Period', '${plan.validityDays} Days from activation'),
                  if (widget.trainer != null) ...[
                    const Divider(height: 20, color: Color(0xFFE5E5E5)),
                    _buildSummaryRow('Assigned Trainer', widget.trainer!.displayName),
                    const SizedBox(height: 6),
                    _buildSummaryRow('Training Area', widget.trainer!.displayLocation),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Next step instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.trainer != null
                          ? 'Next Step: Pick your first 1-on-1 session date and time slot from ${widget.trainer!.displayName}\'s schedule.'
                          : 'Next Step: Select an available personal trainer.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.0 * sf).clamp(10.0, 12.5),
                        color: const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Next Step Action Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(sheetContext); // Close sheet

                if (widget.trainer != null) {
                  // Direct to session scheduling with trainer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientBookingScheduleScreen(
                        trainer: widget.trainer!,
                        plan: plan,
                        clientGender: widget.clientGender ?? Gender.male,
                        clientId: widget.clientId ?? 'client_active',
                      ),
                    ),
                  );
                } else {
                  // Package purchased without pre-selected trainer: purchase & book later
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientPaymentScreen(
                        plan: plan,
                        clientId: widget.clientId ?? 'client_active',
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kDark,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.trainer != null ? 'Continue to Schedule Session' : 'Proceed to Payment & Book Later',
                style: const TextStyle(
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
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
        ),
        Text(
          value,
          style: const TextStyle(fontFamily: 'Syne', fontSize: 12.5, fontWeight: FontWeight.w700, color: kDark),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.065).clamp(18.0, 28.0);
    final trainer = widget.trainer;

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
          'Training Packages',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (17.0 * sf).clamp(15.0, 19.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          // Comparison toggle button
          IconButton(
            icon: Icon(
              _showComparisonTable ? Iconsax.cards : Iconsax.chart_square,
              color: kDark,
              size: 20,
            ),
            tooltip: _showComparisonTable ? 'Show Cards View' : 'Compare All Packages',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _showComparisonTable = !_showComparisonTable);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Trainer Connection Banner (If Opened from a Trainer Profile) ──
            if (trainer != null) ...[
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
                      backgroundImage: (trainer.photoUrl != null && trainer.photoUrl!.isNotEmpty)
                          ? NetworkImage(trainer.photoUrl!)
                          : null,
                      child: (trainer.photoUrl == null || trainer.photoUrl!.isEmpty)
                          ? Text(
                              trainer.displayName.isNotEmpty
                                  ? trainer.displayName[0].toUpperCase()
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
                                  trainer.displayName,
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
                            trainer.gymName ?? 'TRAIN Z Certified Coach',
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
                                '${trainer.ratingText} (${trainer.totalReviews} reviews)',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kDark,
                                ),
                              ),
                              const Text(' • ', style: TextStyle(color: kGrey)),
                              Text(
                                trainer.displayLocation,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: kGrey,
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
              const SizedBox(height: 18),
            ],

            // ── Header & Description ──
            Text(
              'Select Your Training Block',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (20.0 * sf).clamp(18.0, 24.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fixed platform pricing for 1-on-1 personal training. All sessions are 60 minutes with 12-hour cancellation protection.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.5 * sf).clamp(10.5, 13.0),
                color: kGrey,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 16),

            // ── 2. Firebase Integration: Stream training_plans collection ──
            StreamBuilder<List<TrainingPlanModel>>(
              stream: FirestoreService().streamTrainingPlans(),
              builder: (context, snapshot) {
                // Loading State
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(color: kDark),
                    ),
                  );
                }

                // Error State
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load packages',
                            style: TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            style: ElevatedButton.styleFrom(backgroundColor: kDark),
                            child: const Text('Try Again', style: TextStyle(fontFamily: 'Syne', color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final plans = snapshot.data ?? [];

                // Proper Setup Message if training_plans collection is empty in Firestore
                if (plans.isEmpty) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.box_remove, size: 44, color: Color(0xFF999999)),
                          const SizedBox(height: 14),
                          Text(
                            'Packages Setup Required',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (16.0 * sf).clamp(15.0, 18.0),
                              fontWeight: FontWeight.w800,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The Firestore "training_plans" collection has not yet been initialized. Please seed the database with platform packages to view available plans.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.5 * sf).clamp(10.5, 13.0),
                              color: kGrey,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await SeedService().seedTrainingPlans();
                              setState(() {});
                            },
                            icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: kDark),
                            label: const Text(
                              'Initialize Platform Packages',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kLime,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Default initial selection if needed
                if (_selectedPlanId == null || !plans.any((p) => p.id == _selectedPlanId)) {
                  _selectedPlanId = plans.firstWhere((p) => p.popular, orElse: () => plans.first).id;
                }

                // ── 3. Package Comparison Table / Matrix View (When toggled) ──
                if (_showComparisonTable) {
                  return _buildComparisonTable(plans: plans, sf: sf);
                }

                // ── 4. Package Cards Listing (With 6-Month Transformation Highlight) ──
                return Column(
                  children: plans.map((plan) {
                    final isSelected = _selectedPlanId == plan.id;
                    final isTransformation = plan.isTransformationPackage;

                    return _buildPackageCard(
                      plan: plan,
                      isSelected: isSelected,
                      isTransformation: isTransformation,
                      sf: sf,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPlanId = plan.id);
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── 5. Package Information, Rules & Expiry Policies ──
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
                  Row(
                    children: const [
                      Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Text(
                        'PACKAGE RULES & GUARANTEES',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kDark,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyRow(
                    icon: Icons.timer_outlined,
                    title: 'Full 60-Minute Sessions',
                    subtitle: 'Every booking provides a full 60 minutes of intensive 1-on-1 personal training.',
                    sf: sf,
                  ),
                  const SizedBox(height: 10),
                  _buildPolicyRow(
                    icon: Icons.event_busy_outlined,
                    title: 'Package Expiry & Duration',
                    subtitle: 'Credits expire on the package end date (1d to 180d). Unused expired sessions cannot be carried forward.',
                    sf: sf,
                  ),
                  const SizedBox(height: 10),
                  _buildPolicyRow(
                    icon: Icons.replay_outlined,
                    title: '12-Hour Cancellation Protection',
                    subtitle: 'Cancel up to 12 hours before session start for 100% credit refund. Late cancellations forfeit credit.',
                    sf: sf,
                  ),
                  const SizedBox(height: 10),
                  _buildPolicyRow(
                    icon: Icons.verified_user_outlined,
                    title: 'Certified Personal Trainers',
                    subtitle: 'All platform trainers are verified for qualifications, background checks, and professional standards.',
                    sf: sf,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 110), // Space for sticky bottom bar
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
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) {
                return const SizedBox(height: 50);
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
                      onPressed: () => _onProceed(selectedPlan),
                      icon: const Icon(Iconsax.arrow_right_3, size: 16, color: kDark),
                      label: const Text(
                        'Continue to Booking',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 13.5,
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

  // ── Package Card Builder ──
  Widget _buildPackageCard({
    required TrainingPlanModel plan,
    required bool isSelected,
    required bool isTransformation,
    required double sf,
    required VoidCallback onTap,
  }) {
    final pricePerSession = plan.pricePerSession.round();
    final savings = plan.savingsPercent;

    if (isTransformation) {
      // ── Flagship 6-Month Transformation Card ──
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kLime : const Color(0xFF333333),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: kLime.withValues(alpha: isSelected ? 0.25 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top highlight banner
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium, size: 14, color: kDark),
                            SizedBox(width: 4),
                            Text(
                              'MAXIMUM TRANSFORMATION VALUE',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Selection Indicator
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? kLime : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? kLime : const Color(0xFF666666),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: kDark)
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan.title,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (18.0 * sf).clamp(16.0, 21.0),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kLime.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          'Save $savings% per session',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            color: kLime,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    plan.description,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      color: const Color(0xFFB0B0B0),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 14),

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
                              fontSize: (22.0 * sf).clamp(20.0, 26.0),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '₹$pricePerSession per 60-min session',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kLime,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${plan.sessionsCount} Sessions • ${plan.validityDays} Days',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
    }

    // ── Standard & Popular Package Cards ──
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            plan.title,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (15.5 * sf).clamp(14.0, 17.5),
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
                                'MOST POPULAR',
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
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 12),

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
                          savings > 0
                              ? '₹$pricePerSession/session (Save $savings%)'
                              : '₹$pricePerSession/session',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (10.0 * sf).clamp(9.0, 11.5),
                            fontWeight: FontWeight.w600,
                            color: savings > 0 ? const Color(0xFF15803D) : kGrey,
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
  }

  // ── Package Comparison Table Matrix ──
  Widget _buildComparisonTable({
    required List<TrainingPlanModel> plans,
    required double sf,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.chart_square, size: 16, color: kDark),
                const SizedBox(width: 8),
                Text(
                  'ALL PACKAGES COMPARISON',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (11.5 * sf).clamp(10.5, 13.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text('Package', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(label: Text('Sessions', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(label: Text('Total Price', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(label: Text('Per Session', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(label: Text('Validity', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(label: Text('Savings', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 11))),
              ],
              rows: plans.map((plan) {
                final isSelected = _selectedPlanId == plan.id;
                final isTransformation = plan.isTransformationPackage;

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPlanId = plan.id);
                  },
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Text(
                            plan.title,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isTransformation ? const Color(0xFFD97706) : kDark,
                              fontSize: 11.5,
                            ),
                          ),
                          if (isTransformation)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.star, size: 12, color: Color(0xFFD97706)),
                            ),
                        ],
                      ),
                    ),
                    DataCell(Text('${plan.sessionsCount}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5))),
                    DataCell(Text('₹${plan.price}', style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12))),
                    DataCell(Text('₹${plan.pricePerSession.round()}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF15803D)))),
                    DataCell(Text('${plan.validityDays}d', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5))),
                    DataCell(Text(plan.savingsPercent > 0 ? '${plan.savingsPercent}%' : '—', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11.5))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required double sf,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kDark),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (10.0 * sf).clamp(9.0, 11.5),
                  color: kGrey,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
