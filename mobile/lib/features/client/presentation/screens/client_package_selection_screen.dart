import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_booking_schedule_screen.dart';
import 'client_payment_screen.dart';

/// Screen allowing clients to view, compare and select a training package for a personal trainer.
/// Supports trainer category-based package display:
/// - Standard Trainer: Displays the 6 predefined TRAIN Z packages with platform-controlled pricing.
/// - Advanced Trainer: Displays only Admin-approved & published custom plans created by that trainer.
/// - Professional Trainer: Displays "Coming Soon" with purchases disabled at launch.
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
  // Starts with no package pre-selected. The client must explicitly choose a package.
  String? _selectedPlanId;
  bool _showComparisonTable = false;

  TrainerCategory get _trainerCategory =>
      widget.trainer?.category ?? TrainerCategory.trainer;

  bool get _isProfessionalTrainer =>
      _trainerCategory == TrainerCategory.professionalTrainer;

  void _onProceed(TrainingPlanModel plan) {
    if (!plan.isActive || !plan.isApproved) return;
    HapticFeedback.mediumImpact();
    final sf = scaleFactor(context);

    // Show transparent package summary and conditions before scheduling
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
                        'Package Summary',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (18.0 * sf).clamp(16.0, 22.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                      Text(
                        'Transparent Price & Session Breakdown',
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
                  if (widget.trainer != null) ...[
                    _buildSummaryRow('Selected Trainer', widget.trainer!.displayName),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Trainer Category',
                      widget.trainer!.category == TrainerCategory.advancedTrainer
                          ? 'Advanced Trainer'
                          : 'Personal Trainer',
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Training Location', widget.trainer!.displayLocation),
                    const Divider(height: 18, color: Color(0xFFE5E5E5)),
                  ],
                  _buildSummaryRow('Selected Package', plan.title),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Package Type', plan.packageTypeLabel),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Session Count', '${plan.sessionsCount} Sessions (${plan.sessionDurationMinutes} mins each)'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Total Price', '${plan.formattedPrice} (₹${plan.pricePerSession.round()}/session)'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Package Validity', '${plan.validityDays} Days from activation'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Session Duration', '${plan.sessionDurationMinutes} minutes per session'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Important Conditions Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Important Package Conditions',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Full 60-minute 1-on-1 personal training sessions.\n'
                    '• 12-Hour Cancellation Rule: full session credit returned if cancelled >= 12h before start.\n'
                    '• Package sessions are valid for ${plan.validityDays} days from activation.\n'
                    '• Transparent pricing in Indian Rupees (₹) with zero hidden fees.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.5 * sf).clamp(9.5, 11.5),
                      color: const Color(0xFF78350F),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Proceed Action Button
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontFamily: 'Syne', fontSize: 12.0, fontWeight: FontWeight.w700, color: kDark),
          ),
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
          if (!_isProfessionalTrainer) ...[
            IconButton(
              icon: Icon(
                _showComparisonTable ? Iconsax.cards : Iconsax.chart_square,
                color: kDark,
                size: 20,
              ),
              tooltip: _showComparisonTable ? 'Show Cards View' : 'Compare Packages',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _showComparisonTable = !_showComparisonTable);
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Trainer Header Banner ──
            if (trainer != null) ...[
              _buildTrainerHeaderCard(trainer, sf),
              const SizedBox(height: 18),
            ],

            // ── 2. Category-Specific Header & Explanation ──
            _buildCategoryHeader(sf),

            const SizedBox(height: 16),

            // ── 3. Professional Trainer Coming Soon Guard ──
            if (_isProfessionalTrainer) ...[
              _buildProfessionalTrainerComingSoon(sf),
              const SizedBox(height: 100),
            ] else ...[
              // ── 4. Package Stream & Selection ──
              StreamBuilder<List<TrainingPlanModel>>(
                stream: FirestoreService().streamPackagesForTrainer(widget.trainer),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: CircularProgressIndicator(color: kDark),
                      ),
                    );
                  }

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

                  // Empty State for Advanced Trainer or Missing Plans
                  if (plans.isEmpty) {
                    return _buildEmptyPlansState(sf);
                  }

                  // ── Comparison Table View (When Toggled) ──
                  if (_showComparisonTable) {
                    return _buildComparisonTable(plans: plans, sf: sf);
                  }

                  // ── Package Cards Listing ──
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
                          if (!plan.isActive || !plan.isApproved) return;
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedPlanId = plan.id;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── 5. Package Information, Rules & Guarantees ──
              _buildPackageRulesSection(sf),

              const SizedBox(height: 110), // Space for sticky bottom bar
            ],
          ],
        ),
      ),
      bottomSheet: _isProfessionalTrainer ? null : _buildStickyBottomBar(sf),
    );
  }

  Widget _buildTrainerHeaderCard(TrainerDisplayModel trainer, double sf) {
    String categoryLabel;
    Color categoryBg;
    Color categoryText;

    switch (trainer.category) {
      case TrainerCategory.trainer:
        categoryLabel = 'Trainer';
        categoryBg = const Color(0xFFF3F4F6);
        categoryText = kDark;
        break;
      case TrainerCategory.advancedTrainer:
        categoryLabel = 'Advanced Trainer';
        categoryBg = const Color(0xFFDCFCE7);
        categoryText = const Color(0xFF15803D);
        break;
      case TrainerCategory.professionalTrainer:
        categoryLabel = 'Professional Trainer • Coming Soon';
        categoryBg = const Color(0xFFFEF3C7);
        categoryText = const Color(0xFFB45309);
        break;
    }

    return Container(
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
                    trainer.displayName.isNotEmpty ? trainer.displayName[0].toUpperCase() : 'T',
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
                  trainer.gymName ?? 'Certified Personal Trainer',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: kGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: categoryBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: categoryText,
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

  Widget _buildCategoryHeader(double sf) {
    String title;
    String subtitle;

    switch (_trainerCategory) {
      case TrainerCategory.trainer:
        title = 'Standard Platform Packages';
        subtitle = 'Fixed platform pricing for 1-on-1 personal training. All sessions are 60 minutes with 12-hour cancellation protection.';
        break;
      case TrainerCategory.advancedTrainer:
        title = 'Advanced Trainer Custom Plans';
        subtitle = 'Custom training packages designed by ${widget.trainer?.displayName ?? "this Advanced Trainer"} and approved by TRAIN Z Admin.';
        break;
      case TrainerCategory.professionalTrainer:
        title = 'Professional Trainer';
        subtitle = 'Specialized elite coaching packages.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (19.0 * sf).clamp(17.0, 23.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (11.5 * sf).clamp(10.5, 13.0),
            color: kGrey,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalTrainerComingSoon(double sf) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, size: 36, color: Color(0xFFD97706)),
          ),
          const SizedBox(height: 16),
          Text(
            'Professional Trainer • Coming Soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (16.0 * sf).clamp(15.0, 18.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Packages for Professional Trainers are coming soon and are unavailable for booking at launch. Please choose an available Standard or Advanced Trainer to book your training sessions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10.5, 12.5),
              color: kGrey,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Explore Other Trainers',
              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kLime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlansState(double sf) {
    final isAdvanced = _trainerCategory == TrainerCategory.advancedTrainer;

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
              isAdvanced
                  ? 'No training plans are currently available from this trainer.'
                  : 'No packages available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (15.5 * sf).clamp(14.5, 17.5),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAdvanced
                  ? 'This Advanced Trainer has not yet published any Admin-approved training plans. You can check back soon or browse other available trainers.'
                  : 'Platform training packages will appear here once configured.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.5 * sf).clamp(10.5, 12.5),
                color: kGrey,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              child: const Text(
                'Explore Other Trainers',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kLime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(double sf) {
    return Container(
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
          stream: FirestoreService().streamPackagesForTrainer(widget.trainer),
          builder: (context, snapshot) {
            final plans = snapshot.data ?? [];
            if (plans.isEmpty) {
              return const SizedBox.shrink();
            }

            final selectedPlan = plans.cast<TrainingPlanModel?>().firstWhere(
                  (p) => p?.id == _selectedPlanId,
                  orElse: () => null,
                );

            final hasSelection = selectedPlan != null;

            return Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSelection ? selectedPlan.title : 'No Package Selected',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: hasSelection ? kGrey : const Color(0xFF9CA3AF),
                      ),
                    ),
                    Text(
                      hasSelection ? selectedPlan.formattedPrice : 'Choose a package',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (18.0 * sf).clamp(16.0, 22.0),
                        fontWeight: FontWeight.w800,
                        color: hasSelection ? kDark : const Color(0xFFCCCCCC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasSelection ? () => _onProceed(selectedPlan) : null,
                    icon: Icon(Iconsax.arrow_right_3, size: 16, color: hasSelection ? kDark : const Color(0xFF9CA3AF)),
                    label: Text(
                      hasSelection ? 'Review & Continue' : 'Select a Package',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: hasSelection ? kDark : const Color(0xFF9CA3AF),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasSelection ? kLime : const Color(0xFFE5E7EB),
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
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
    final isCustom = plan.isCustom;

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
                              'FLAGSHIP TRANSFORMATION',
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
                      if (savings > 0)
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
                            plan.formattedPrice,
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

    // ── Standard & Custom Package Cards ──
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
                // Top Tag & Type Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCustom ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCustom
                            ? 'Advanced Trainer Custom Plan • Admin Verified'
                            : 'TRAIN Z Platform Package',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isCustom ? const Color(0xFF1D4ED8) : kDark,
                        ),
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

                const SizedBox(height: 10),

                Row(
                  children: [
                    Text(
                      plan.title,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (16.0 * sf).clamp(14.5, 18.0),
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

                if (plan.description.isNotEmpty) ...[
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
                ],

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.formattedPrice,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (18.5 * sf).clamp(16.5, 22.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        Text(
                          savings > 0
                              ? '₹$pricePerSession/session (Save $savings%)'
                              : '₹$pricePerSession/session • 60 mins',
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
                    if (!plan.isActive || !plan.isApproved) return;
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
                    DataCell(Text(plan.formattedPrice, style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12))),
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

  Widget _buildPackageRulesSection(double sf) {
    return Container(
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
            title: 'Package Expiry & Validity',
            subtitle: 'Credits expire on the package validity date (1d to 180d). Unused expired sessions cannot be carried forward.',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildPolicyRow(
            icon: Icons.replay_outlined,
            title: '12-Hour Cancellation Protection',
            subtitle: 'Cancel up to 12 hours before session start for 100% session credit return. Late cancellations (<12h) forfeit credit.',
            sf: sf,
          ),
          const SizedBox(height: 10),
          _buildPolicyRow(
            icon: Icons.verified_user_outlined,
            title: 'Verified Personal Trainers',
            subtitle: 'All platform trainers are verified for qualifications, background checks, and professional standards.',
            sf: sf,
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
