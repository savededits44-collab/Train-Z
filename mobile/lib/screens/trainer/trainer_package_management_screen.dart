import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_package_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/trainer_profile_model.dart';
import '../../shared/models/training_plan_model.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kLime = Color(0xFFB2FF59);
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);

/// Screen for Managing Training Packages:
/// - Standard Trainers: Read-only catalog of the 6 fixed TRAIN Z packages.
/// - Advanced Trainers: Create, edit, delete, and track Admin approval for custom training plans.
class TrainerPackageManagementScreen extends StatefulWidget {
  final String? trainerId;
  final bool? isAdvanced;

  const TrainerPackageManagementScreen({
    super.key,
    this.trainerId,
    this.isAdvanced,
  });

  @override
  State<TrainerPackageManagementScreen> createState() => _TrainerPackageManagementScreenState();
}

class _TrainerPackageManagementScreenState extends State<TrainerPackageManagementScreen> {
  final TrainerPackageService _packageService = TrainerPackageService.instance;
  late final String _trainerId;
  late final bool _isAdvanced;

  PackageApprovalStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    final category = TrainerProfileService.instance.category;
    _isAdvanced = widget.isAdvanced ?? (category == TrainerCategory.advancedTrainer);
  }

  void _openCreatePlanSheet() {
    if (!_isAdvanced) {
      _showStandardTrainerRestrictionNotice();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomPlanFormSheet(
        onSubmit: (title, price, sessions, validity, desc, submitForApproval) async {
          await _packageService.createCustomPlan(
            title: title,
            price: price,
            sessionsCount: sessions,
            validityDays: validity,
            description: desc,
            submitForApproval: submitForApproval,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: submitForApproval ? const Color(0xFF2E7D32) : _kDark,
                content: Text(
                  submitForApproval
                      ? 'Package submitted for Admin approval successfully!'
                      : 'Package saved as draft.',
                  style: const TextStyle(fontFamily: 'Outfit', color: Colors.white),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _openEditPlanSheet(TrainingPlanModel plan) {
    if (!_isAdvanced) {
      _showStandardTrainerRestrictionNotice();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomPlanFormSheet(
        existingPlan: plan,
        onSubmit: (title, price, sessions, validity, desc, submitForApproval) async {
          await _packageService.updateCustomPlan(
            planId: plan.id,
            title: title,
            price: price,
            sessionsCount: sessions,
            validityDays: validity,
            description: desc,
            submitForApproval: submitForApproval,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFE65100),
                content: Text(
                  plan.approvalStatus == PackageApprovalStatus.approved
                      ? 'Plan updated. It has been resubmitted for Admin approval.'
                      : 'Plan updated successfully.',
                  style: const TextStyle(fontFamily: 'Outfit', color: Colors.white),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _handleDeletePlan(TrainingPlanModel plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Custom Plan?',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: _kDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "${plan.title}"? Clients will no longer be able to discover or book this package.',
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.shield_tick, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Purchase Safety: Any existing client purchases of this package remain 100% active and protected.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kGrey, fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _packageService.deleteCustomPlan(plan.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: _kDark,
              content: Text(
                'Custom plan removed. Past purchases preserved.',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Failed to delete package: $e', style: const TextStyle(fontFamily: 'Outfit')),
            ),
          );
        }
      }
    }
  }

  void _showStandardTrainerRestrictionNotice() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Standard Trainer Policy',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: _kDark),
        ),
        content: const Text(
          'Standard Trainers utilize the 6 fixed platform packages established by TRAIN Z. Custom package creation and pricing adjustments are reserved for verified Advanced Trainers with 3.5+ years of verified experience.\n\nPrices, session counts, and validities are standardized platform-wide.',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kDark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isAdvanced ? 'Custom Training Plans' : 'Platform Packages',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: _kDark, fontSize: 18),
        ),
        actions: [
          if (_isAdvanced)
            IconButton(
              icon: const Icon(Iconsax.add_circle, color: _kDark),
              tooltip: 'Create Custom Plan',
              onPressed: _openCreatePlanSheet,
            ),
        ],
      ),
      floatingActionButton: _isAdvanced
          ? FloatingActionButton.extended(
              onPressed: _openCreatePlanSheet,
              backgroundColor: _kDark,
              icon: const Icon(Iconsax.add, color: Colors.white),
              label: const Text(
                'New Custom Plan',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Colors.white),
              ),
            )
          : null,
      body: SafeArea(
        child: _isAdvanced ? _buildAdvancedTrainerView() : _buildStandardTrainerView(),
      ),
    );
  }

  /// ── Standard Trainer View (Fixed 6 Platform Packages) ─────────────────────────
  Widget _buildStandardTrainerView() {
    final packages = _packageService.getPlatformPackages();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Informational Policy Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kCardSubBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'STANDARD TRAINER',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Iconsax.lock, size: 16, color: _kGrey),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Platform-Standardized Packages',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: _kDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Standard Trainers operate under the 6 platform-wide packages below. Pricing, session counts, and validity are fixed to deliver consistent value across TRAIN Z. Standard Trainers cannot create custom plans or modify prices.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: _kGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Assigned Packages (6)',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w600, color: _kDark),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kCardSubBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Read-Only',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 10.5, color: _kGrey, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...packages.map((pkg) => _buildStandardPackageCard(pkg)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStandardPackageCard(TrainingPlanModel plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.popular
              ? _kDark
              : _kBorder,
          width: plan.popular ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
              ),
              if (plan.popular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MOST POPULAR',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (plan.isTransformationPackage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FLAGSHIP',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Metrics Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCardSubBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('Total Price', plan.formattedPrice, isHighlight: true),
                Container(width: 1, height: 28, color: _kBorder),
                _buildMetricColumn('Sessions', '${plan.sessionsCount}'),
                Container(width: 1, height: 28, color: _kBorder),
                _buildMetricColumn('Validity', '${plan.validityDays} Days'),
                Container(width: 1, height: 28, color: _kBorder),
                _buildMetricColumn('Per Session', '₹${plan.pricePerSession.round()}'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Iconsax.shield_tick, size: 14, color: _kDark),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Platform package • Pricing & terms locked',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: _kGrey,
                  ),
                ),
              ),
              if (plan.savingsPercent > 0)
                Text(
                  'Save ${plan.savingsPercent}%',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// ── Advanced Trainer View (Custom Plans with Approval Lifecycle) ─────────────
  Widget _buildAdvancedTrainerView() {
    return StreamBuilder<List<TrainingPlanModel>>(
      stream: _packageService.streamCustomPlans(_trainerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kLime));
        }

        final allPlans = snapshot.data ?? [];
        final filteredPlans = _statusFilter == null
            ? allPlans
            : allPlans.where((p) => p.approvalStatus == _statusFilter).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Advanced Trainer Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Text(
                          'ADVANCED TRAINER',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Iconsax.star, size: 16, color: Color(0xFFD97706)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Custom Package Management',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'As an approved Advanced Trainer, you can set your own prices, session counts, and validities. Every package requires Admin approval before it is published to clients. Existing client purchases are always protected.',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Color(0xFFB45309),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', null, allPlans.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', PackageApprovalStatus.approved,
                      allPlans.where((p) => p.approvalStatus == PackageApprovalStatus.approved).length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', PackageApprovalStatus.pending,
                      allPlans.where((p) => p.approvalStatus == PackageApprovalStatus.pending).length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', PackageApprovalStatus.rejected,
                      allPlans.where((p) => p.approvalStatus == PackageApprovalStatus.rejected).length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Draft', PackageApprovalStatus.draft,
                      allPlans.where((p) => p.approvalStatus == PackageApprovalStatus.draft).length),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (filteredPlans.isEmpty)
              _buildEmptyPlansState(allPlans.isEmpty)
            else
              ...filteredPlans.map((plan) => _buildCustomPlanCard(plan)),

            const SizedBox(height: 80), // spacing for FAB
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, PackageApprovalStatus? status, int count) {
    final isSelected = _statusFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _kDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kDark : _kBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : _kDark,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withAlpha(50) : _kCardSubBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : _kGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlansState(bool hasNoPlansAtAll) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Iconsax.box_1, size: 30, color: _kGrey),
          ),
          const SizedBox(height: 16),
          Text(
            hasNoPlansAtAll ? 'No Custom Packages Yet' : 'No Packages in this Status',
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: _kDark),
          ),
          const SizedBox(height: 8),
          Text(
            hasNoPlansAtAll
                ? 'Create custom packages with personalized rates, sessions, and validity for your clients.'
                : 'Try selecting a different filter above or create a new custom package.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: _kGrey),
          ),
          if (hasNoPlansAtAll) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openCreatePlanSheet,
              icon: const Icon(Iconsax.add, color: Colors.white, size: 16),
              label: const Text(
                'Create Custom Package',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDark,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomPlanCard(TrainingPlanModel plan) {
    final statusColor = _getStatusColor(plan.approvalStatus);
    final statusBgColor = statusColor.withValues(alpha: 0.1);
    final isApproved = plan.approvalStatus == PackageApprovalStatus.approved;
    final isRejected = plan.approvalStatus == PackageApprovalStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRejected
              ? Colors.redAccent.withValues(alpha: 0.5)
              : isApproved
                  ? const Color(0xFF86EFAC)
                  : _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Created on ${_formatDate(plan.createdAt)}',
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 10.5, color: _kGrey),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(plan.approvalStatus), size: 12, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      plan.approvalStatus.displayName,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            plan.description,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Metrics Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCardSubBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('Price', plan.formattedPrice, isHighlight: true),
                Container(width: 1, height: 28, color: _kBorder),
                _buildMetricColumn('Sessions', '${plan.sessionsCount}'),
                Container(width: 1, height: 28, color: _kBorder),
                _buildMetricColumn('Validity', '${plan.validityDays} Days'),
                Container(width: 1, height: 28, color: _kBorder),
                _buildMetricColumn('Per Session', '₹${plan.pricePerSession.round()}'),
              ],
            ),
          ),

          // Rejection Reason Callout Banner
          if (isRejected && (plan.adminRejectionReason != null && plan.adminRejectionReason!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Iconsax.info_circle, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Rejection Feedback:',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          plan.adminRejectionReason!,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: Color(0xFF991B1B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Approval Status Info Hint
          if (plan.approvalStatus == PackageApprovalStatus.pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Iconsax.clock, size: 13, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submitted for Admin review. Unavailable for client purchase until approved.',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (isApproved) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Iconsax.tick_circle, size: 13, color: Color(0xFF15803D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Published & available to clients for booking.',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 10),

          // Card Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _handleDeletePlan(plan),
                icon: const Icon(Iconsax.trash, size: 14, color: Colors.redAccent),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openEditPlanSheet(plan),
                icon: const Icon(Iconsax.edit, size: 14, color: Colors.white),
                label: Text(
                  isRejected ? 'Edit & Resubmit' : 'Edit Plan',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 11.5, fontWeight: FontWeight.w500, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDark,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, color: _kGrey),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: isHighlight ? 14 : 12.5,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(PackageApprovalStatus status) {
    switch (status) {
      case PackageApprovalStatus.approved:
        return const Color(0xFF15803D);
      case PackageApprovalStatus.pending:
        return const Color(0xFFD97706);
      case PackageApprovalStatus.rejected:
        return const Color(0xFFDC2626);
      case PackageApprovalStatus.draft:
        return _kGrey;
    }
  }

  IconData _getStatusIcon(PackageApprovalStatus status) {
    switch (status) {
      case PackageApprovalStatus.approved:
        return Iconsax.tick_circle;
      case PackageApprovalStatus.pending:
        return Iconsax.clock;
      case PackageApprovalStatus.rejected:
        return Iconsax.close_circle;
      case PackageApprovalStatus.draft:
        return Iconsax.edit_2;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// ── Bottom Sheet Form for Creating and Editing Custom Plans ─────────────────
class _CustomPlanFormSheet extends StatefulWidget {
  final TrainingPlanModel? existingPlan;
  final Future<void> Function(
    String title,
    int price,
    int sessionsCount,
    int validityDays,
    String description,
    bool submitForApproval,
  ) onSubmit;

  const _CustomPlanFormSheet({
    this.existingPlan,
    required this.onSubmit,
  });

  @override
  State<_CustomPlanFormSheet> createState() => _CustomPlanFormSheetState();
}

class _CustomPlanFormSheetState extends State<_CustomPlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _sessionsCtrl;
  late final TextEditingController _validityCtrl;
  late final TextEditingController _descCtrl;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlan;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toString() : '');
    _sessionsCtrl = TextEditingController(text: p != null ? p.sessionsCount.toString() : '');
    _validityCtrl = TextEditingController(text: p != null ? p.validityDays.toString() : '30');
    _descCtrl = TextEditingController(text: p?.description ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _sessionsCtrl.dispose();
    _validityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  double get _calculatedPricePerSession {
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final sessions = int.tryParse(_sessionsCtrl.text.trim()) ?? 0;
    if (price <= 0 || sessions <= 0) return 0.0;
    return price / sessions;
  }

  Future<void> _submit(bool submitForApproval) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final title = _titleCtrl.text.trim();
    final price = int.parse(_priceCtrl.text.trim());
    final sessions = int.parse(_sessionsCtrl.text.trim());
    final validity = int.parse(_validityCtrl.text.trim());
    final desc = _descCtrl.text.trim();

    try {
      await widget.onSubmit(title, price, sessions, validity, desc, submitForApproval);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPlan != null;
    final wasApproved = widget.existingPlan?.approvalStatus == PackageApprovalStatus.approved;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kCardSubBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.box_add, color: _kDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Custom Plan' : 'Create Custom Training Plan',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _kDark,
                            ),
                          ),
                          const Text(
                            'Advanced Trainer Custom Pricing',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: _kGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Re-approval Warning when editing an already-approved plan
                if (wasApproved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Iconsax.warning_2, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notice: Updating an approved plan resets its status to "Pending Approval". It must be reviewed by Admin before new clients can purchase it. Existing client purchases are 100% safe.',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),

                // Title Field
                _buildFieldLabel('Package Title'),
                TextFormField(
                  controller: _titleCtrl,
                  style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 14),
                  decoration: _inputDecoration('e.g. 10-Session Hypertrophy Blueprint'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a package title';
                    if (v.trim().length < 3) return 'Title must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Price and Sessions in a row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Price (INR)'),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 14),
                            decoration: _inputDecoration('₹ 4,500'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Total Sessions'),
                          TextFormField(
                            controller: _sessionsCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 14),
                            decoration: _inputDecoration('e.g. 10'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) return 'Must be >= 1';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Validity in Days
                _buildFieldLabel('Validity (Days)'),
                TextFormField(
                  controller: _validityCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 14),
                  decoration: _inputDecoration('e.g. 30'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please specify validity in days';
                    final val = int.tryParse(v.trim());
                    if (val == null || val <= 0) return 'Must be at least 1 day';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Calculated rate preview
                if (_calculatedPricePerSession > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kCardSubBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.calculator, size: 14, color: _kDark),
                        const SizedBox(width: 8),
                        Text(
                          'Effective rate: ₹${_calculatedPricePerSession.round()} per 60-min session',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: _kDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                // Description Field
                _buildFieldLabel('Package Description'),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'Outfit', color: _kDark, fontSize: 13),
                  decoration: _inputDecoration('Detailed breakdown of workout structure, milestones, and target goals...'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a description';
                    if (v.trim().length < 10) return 'Description must be at least 10 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Actions
                if (_isSaving)
                  const Center(child: CircularProgressIndicator(color: _kDark))
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _submit(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isEditing ? 'Update & Submit for Approval' : 'Submit for Admin Approval',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _submit(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kDark,
                            side: const BorderSide(color: _kBorder),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Save as Draft',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: _kDark,
                            ),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _kDark,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Outfit', color: _kGrey, fontSize: 13),
      filled: true,
      fillColor: _kCardSubBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kDark),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
