import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_earnings_service.dart';
import '../../shared/models/trainer_earnings_model.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

/// Dedicated Trainer Earnings, Commission & Payout Management Dashboard
class TrainerEarningsScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerEarningsScreen({super.key, this.trainerId});

  @override
  State<TrainerEarningsScreen> createState() => _TrainerEarningsScreenState();
}

class _TrainerEarningsScreenState extends State<TrainerEarningsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TrainerEarningsService _earningsService = TrainerEarningsService.instance;

  String _trainerId = '';
  DateRangeFilter _dateRange = DateRangeFilter.allTime;
  TrainerPayoutStatus? _selectedStatus;
  String _searchQuery = '';
  bool _isLoading = true;
  TrainerEarningsSummaryModel _summary = const TrainerEarningsSummaryModel();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _resolveTrainerId();
    _loadSummary();
    _earningsService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _earningsService.removeListener(_onServiceUpdate);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resolveTrainerId() {
    if (widget.trainerId != null && widget.trainerId!.isNotEmpty) {
      _trainerId = widget.trainerId!;
    } else {
      try {
        _trainerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      } catch (_) {
        _trainerId = '';
      }
    }
  }

  void _onServiceUpdate() {
    if (mounted) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final summary = await _earningsService.getEarningsSummary(_trainerId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Earnings & Payouts',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kLime, size: 20),
            tooltip: 'Refresh Financials',
            onPressed: _loadSummary,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kLime,
          indicatorWeight: 3,
          labelColor: _kLime,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Overview & History'),
            Tab(text: 'Payout Batches'),
            Tab(text: 'Payout Account'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: _kLime,
                backgroundColor: _kBorder,
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewAndHistoryTab(),
                  _buildPayoutBatchesTab(),
                  _buildPayoutAccountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: Overview & History
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildOverviewAndHistoryTab() {
    return RefreshIndicator(
      color: _kLime,
      backgroundColor: _kCardBg,
      onRefresh: _loadSummary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Commission Status Banner
                  _buildCommissionStatusBanner(),
                  const SizedBox(height: 14),

                  // 2. Financial Overview Cards
                  _buildFinancialCardsGrid(),
                  const SizedBox(height: 18),

                  // 3. Search and Filters Header
                  const Text(
                    'Session Earnings History',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by client, package, or reference...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      prefixIcon: const Icon(Iconsax.search_normal, color: _kLime, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kLime),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Date Range Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _dateFilterChip('All Time', DateRangeFilter.allTime),
                        const SizedBox(width: 8),
                        _dateFilterChip('This Month', DateRangeFilter.thisMonth),
                        const SizedBox(width: 8),
                        _dateFilterChip('Last 30 Days', DateRangeFilter.last30Days),
                        const SizedBox(width: 8),
                        _dateFilterChip('Last 90 Days', DateRangeFilter.last90Days),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Payout Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statusFilterChip('All Statuses', null),
                        const SizedBox(width: 8),
                        _statusFilterChip('Eligible for Payout', TrainerPayoutStatus.eligibleForPayout),
                        const SizedBox(width: 8),
                        _statusFilterChip('Payout Pending', TrainerPayoutStatus.payoutPending),
                        const SizedBox(width: 8),
                        _statusFilterChip('Paid', TrainerPayoutStatus.paid),
                        const SizedBox(width: 8),
                        _statusFilterChip('Refunded', TrainerPayoutStatus.refunded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // 4. Transaction List Stream
          StreamBuilder<List<TrainerEarningsTransactionModel>>(
            stream: _earningsService.streamTransactionsForTrainer(_trainerId),
            builder: (context, snapshot) {
              final list = _earningsService.filterTransactions(
                trainerId: _trainerId,
                dateRange: _dateRange,
                statusFilter: _selectedStatus,
                searchQuery: _searchQuery,
              );

              if (list.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.receipt_2, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Earnings Records Found',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Earnings are generated automatically whenever scheduled training sessions are completed with verified clients.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionCard(list[index]),
                    childCount: list.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionStatusBanner() {
    if (!_summary.isCommissionConfigured || _summary.commissionRatePercent == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF78350F).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(
          children: [
            Icon(Iconsax.warning_2, color: Color(0xFFF59E0B), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commission Rate Pending Configuration',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Platform commission percentage is currently pending administrator publication. Payout calculations will finalize once updated.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCardSubBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kLime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Iconsax.shield_tick, color: _kLime, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TRAIN Z Platform Fee: ${_summary.formattedCommissionRate} • Transparent & Automated',
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCardsGrid() {
    return Column(
      children: [
        // Net Earnings Featured Hero Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kLime.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _kLime.withValues(alpha: 0.05),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TRAINER NET EARNINGS',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _kLime,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_summary.completedSessionsCount} Sessions',
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kLime,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _summary.formattedNetEarnings,
                style: const TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Calculated as Gross Revenue minus ${_summary.formattedCommissionRate} platform fee for completed sessions.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2x2 Breakdown Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Gross Revenue',
                value: _summary.formattedGrossRevenue,
                icon: Iconsax.chart_2,
                color: Colors.white,
                subtitle: 'Total completed revenue',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Platform Fee',
                value: _summary.formattedCommission,
                icon: Iconsax.percentage_circle,
                color: const Color(0xFFF59E0B),
                subtitle: '${_summary.formattedCommissionRate} commission',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Pending Payout',
                value: _summary.formattedPendingPayout,
                icon: Iconsax.clock,
                color: const Color(0xFF60A5FA),
                subtitle: 'Awaiting bank transfer',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Paid Out',
                value: _summary.formattedPaidOut,
                icon: Iconsax.tick_circle,
                color: const Color(0xFF10B981),
                subtitle: 'Transferred to bank',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: _kGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateFilterChip(String label, DateRangeFilter filter) {
    final isSelected = _dateRange == filter;
    return GestureDetector(
      onTap: () => setState(() => _dateRange = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _kLime : _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _kLime : _kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? _kDark : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _statusFilterChip(String label, TrainerPayoutStatus? status) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _kLime : _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _kLime : _kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? _kDark : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TrainerEarningsTransactionModel tx) {
    final statusColor = tx.payoutStatus.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Client Name, Booking Ref, and Payout Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.clientName,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${tx.id}  •  Booking: ${tx.bookingRef}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        color: _kGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  tx.payoutStatus.displayTitle,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Package & Session Details
          Row(
            children: [
              const Icon(Iconsax.calendar_1, size: 13, color: _kGrey),
              const SizedBox(width: 4),
              Text(
                '${tx.formattedSessionDate}  •  ${tx.formattedTimeSlot}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Iconsax.box_1, size: 13, color: _kGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  tx.packageName,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: _kBorder),

          // Financial Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gross Revenue', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kGrey)),
                  const SizedBox(height: 2),
                  Text(tx.formattedGross, style: const TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee (${tx.commissionRatePercent ?? 15}%)',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kGrey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '-${tx.formattedCommission}',
                    style: const TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Trainer Net', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kLime)),
                  const SizedBox(height: 2),
                  Text(
                    tx.formattedNet,
                    style: const TextStyle(fontFamily: 'Syne', fontSize: 15, fontWeight: FontWeight.w800, color: _kLime),
                  ),
                ],
              ),
            ],
          ),

          if (tx.isRefunded && tx.refundReason != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Refunded: ${tx.refundReason}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: Payout Batches
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPayoutBatchesTab() {
    return StreamBuilder<List<TrainerPayoutModel>>(
      stream: _earningsService.streamPayoutsForTrainer(_trainerId),
      builder: (context, snapshot) {
        final payouts = _earningsService.allPayouts.where((p) => p.trainerId == _trainerId).toList();

        if (payouts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.empty_wallet, size: 52, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 14),
                  const Text(
                    'No Payout Records Yet',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Eligible session earnings are aggregated and disbursed to your registered bank account per the platform settlement cycle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _kGrey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payouts.length,
          itemBuilder: (context, index) {
            final po = payouts[index];
            final statusColor = po.status.color;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            po.id,
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Initiated: ${po.formattedDate}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          po.status.displayTitle,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Disbursed Amount', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey)),
                          const SizedBox(height: 2),
                          Text(
                            po.formattedAmount,
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _kLime,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Sessions Settled', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey)),
                          const SizedBox(height: 2),
                          Text(
                            '${po.transactionCount} sessions',
                            style: const TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (po.bankAccountLast4 != null) ...[
                    const Divider(height: 20, color: _kBorder),
                    Row(
                      children: [
                        const Icon(Iconsax.bank, size: 14, color: _kGrey),
                        const SizedBox(width: 6),
                        Text(
                          '${po.bankName ?? "Bank Transfer"} •••• ${po.bankAccountLast4}',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white70),
                        ),
                        if (po.utrNumber != null) ...[
                          const Spacer(),
                          Text(
                            'UTR: ${po.utrNumber}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _kGrey),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (po.status == PayoutBatchStatus.failed && po.failureReason != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.info_circle, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Failure Reason: ${po.failureReason}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.redAccent,
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
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: Payout Account & Security Compliance
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPayoutAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kLime.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.bank, color: _kLime, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank Account Settlement',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Direct electronic bank transfer (NEFT/RTGS/IMPS)',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: _kBorder),
                const Text(
                  'Verified Payout Channels',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'TRAIN Z settles trainer payouts directly into verified Indian banking institutions. Sensitive financial credentials are authenticated through secure banking partner APIs and verified by Platform Administrators during trainer onboarding.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kCardSubBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Iconsax.lock, size: 16, color: _kLime),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Zero Banking Credentials Stored On Device. Payout accounts are encrypted and managed in accordance with RBI and platform security guidelines.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _kGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payout Settlement Rules',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                _SettlementBullet(
                  number: '1',
                  text: 'Eligible Sessions: Only sessions validated as COMPLETED by client attendance count toward payouts.',
                ),
                _SettlementBullet(
                  number: '2',
                  text: 'Platform Commission: Centrally configured TRAIN Z platform fees are deducted transparently before net disbursement.',
                ),
                _SettlementBullet(
                  number: '3',
                  text: 'Settlement Schedule: Payouts are reconciled and batched periodically to your verified bank account in Indian Rupees (₹).',
                ),
                _SettlementBullet(
                  number: '4',
                  text: 'Reversals & Disputes: Any refunded or cancelled sessions are automatically reconciled with the payout ledger to ensure double-entry audit integrity.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementBullet extends StatelessWidget {
  final String number;
  final String text;

  const _SettlementBullet({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kLime.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _kLime,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
