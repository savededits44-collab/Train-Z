import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_review_service.dart';
import '../../shared/models/review_model.dart';
import '../../shared/models/review_report_model.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

/// Dedicated Trainer Reviews & Ratings Management Screen
class TrainerReviewsScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerReviewsScreen({super.key, this.trainerId});

  @override
  State<TrainerReviewsScreen> createState() => _TrainerReviewsScreenState();
}

class _TrainerReviewsScreenState extends State<TrainerReviewsScreen> {
  final TrainerReviewService _reviewService = TrainerReviewService.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  String _trainerId = '';
  ReviewStarFilter _starFilter = ReviewStarFilter.all;
  ReviewResponseFilter _responseFilter = ReviewResponseFilter.all;
  String _searchQuery = '';
  TrainerReviewMetricsModel _metrics = const TrainerReviewMetricsModel();

  @override
  void initState() {
    super.initState();
    _resolveTrainerId();
    _loadMetrics();
    _reviewService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _reviewService.removeListener(_onServiceUpdate);
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
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    final m = await _reviewService.getReviewMetrics(_trainerId);
    if (mounted) {
      setState(() => _metrics = m);
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
          'Reviews & Ratings',
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
            tooltip: 'Refresh Reviews',
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _kLime,
          backgroundColor: _kCardBg,
          onRefresh: _loadMetrics,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Overall Rating & Distribution Hero Card
                      _buildRatingSummaryHero(),
                      const SizedBox(height: 16),

                      // 2. Search & Filters Header
                      const Text(
                        'Client Feedback',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Search Input
                      TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search reviews by client, package, or comment...',
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

                      // Star Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _starChip('All Ratings', ReviewStarFilter.all),
                            const SizedBox(width: 8),
                            _starChip('5 Stars', ReviewStarFilter.fiveStars),
                            const SizedBox(width: 8),
                            _starChip('4 Stars', ReviewStarFilter.fourStars),
                            const SizedBox(width: 8),
                            _starChip('3 Stars', ReviewStarFilter.threeStars),
                            const SizedBox(width: 8),
                            _starChip('2 Stars', ReviewStarFilter.twoStars),
                            const SizedBox(width: 8),
                            _starChip('1 Star', ReviewStarFilter.oneStar),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Response Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _responseChip('All Feedback', ReviewResponseFilter.all),
                            const SizedBox(width: 8),
                            _responseChip('Responded', ReviewResponseFilter.responded),
                            const SizedBox(width: 8),
                            _responseChip('Awaiting Response', ReviewResponseFilter.awaitingResponse),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // 3. Reviews Stream List
              StreamBuilder<List<ReviewModel>>(
                stream: _reviewService.streamReviewsForTrainer(_trainerId),
                builder: (context, snapshot) {
                  final reviews = _reviewService.filterReviews(
                    trainerId: _trainerId,
                    starFilter: _starFilter,
                    responseFilter: _responseFilter,
                    searchQuery: _searchQuery,
                  );

                  if (reviews.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.star_slash, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              const Text(
                                'No Reviews Found',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Reviews appear automatically as verified clients complete scheduled workout sessions with you.',
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
                        (context, index) => _buildReviewCard(reviews[index]),
                        childCount: reviews.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI Sub-Components
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRatingSummaryHero() {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Big Score & Stars
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _metrics.formattedAverage,
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return Icon(
                        starValue <= _metrics.averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB300),
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_metrics.totalReviews} Verified ${_metrics.totalReviews == 1 ? "Review" : "Reviews"}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _kGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Right: 1 to 5 Star Distribution Bars
              Expanded(
                child: Column(
                  children: [
                    _buildDistributionBar(5, _metrics.starPercentage(5), _metrics.ratingDistribution[5] ?? 0),
                    const SizedBox(height: 4),
                    _buildDistributionBar(4, _metrics.starPercentage(4), _metrics.ratingDistribution[4] ?? 0),
                    const SizedBox(height: 4),
                    _buildDistributionBar(3, _metrics.starPercentage(3), _metrics.ratingDistribution[3] ?? 0),
                    const SizedBox(height: 4),
                    _buildDistributionBar(2, _metrics.starPercentage(2), _metrics.ratingDistribution[2] ?? 0),
                    const SizedBox(height: 4),
                    _buildDistributionBar(1, _metrics.starPercentage(1), _metrics.ratingDistribution[1] ?? 0),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: _kBorder),

          // Trend & Performance Badges
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kCardSubBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.like_1, size: 15, color: _kLime),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_metrics.positivePercentage.round()}% Positive Feedback',
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kCardSubBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.message_tick, size: 15, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_metrics.responseRatePercent.round()}% Response Rate',
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(int star, double percent, int count) {
    return Row(
      children: [
        Text(
          '$star',
          style: const TextStyle(fontFamily: 'Syne', fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.star_rounded, size: 10, color: Color(0xFFFFB300)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_kLime),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 18,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kGrey),
          ),
        ),
      ],
    );
  }

  Widget _starChip(String label, ReviewStarFilter filter) {
    final isSelected = _starFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _starFilter = filter),
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

  Widget _responseChip(String label, ReviewResponseFilter filter) {
    final isSelected = _responseFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _responseFilter = filter),
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

  Widget _buildReviewCard(ReviewModel r) {
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
          // Header: Client Name, Star Rating, Date, Report Action
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kLime.withValues(alpha: 0.2),
                child: Text(
                  r.displayClientName.isNotEmpty ? r.displayClientName[0].toUpperCase() : 'C',
                  style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: _kLime, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.displayClientName,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(
                              i < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 13,
                              color: const Color(0xFFFFB300),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r.formattedDate,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _kGrey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  r.isReported ? Iconsax.flag : Iconsax.flag,
                  size: 16,
                  color: r.isReported ? Colors.amber : _kGrey,
                ),
                tooltip: r.isReported ? 'Report Submitted' : 'Report Review',
                onPressed: () => _handleReportReview(r),
              ),
            ],
          ),

          // Associated Package Pill
          if (r.packageName != null && r.packageName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Package: ${r.packageName}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white60),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Written Comment
          Text(
            r.comment,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: Colors.white,
              height: 1.45,
            ),
          ),

          // Reported Notice if already reported
          if (r.isReported) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reported to Admin: ${r.reportReason ?? "Policy violation"}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 22, color: _kBorder),

          // Trainer Response Section
          if (r.hasResponse) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCardSubBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kLime.withValues(alpha: 0.2)),
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
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _kLime.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.verify, size: 11, color: _kLime),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Your Public Response',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kLime,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${r.formattedResponseDate}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kGrey),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _openResponseSheet(r, isEditing: true),
                            child: const Text(
                              'Edit',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _kLime, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _confirmDeleteResponse(r),
                            child: const Text(
                              'Delete',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.trainerResponse!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openResponseSheet(r),
                  icon: const Icon(Iconsax.message_edit, size: 14, color: _kLime),
                  label: const Text(
                    'Reply to Client',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _kLime,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _kLime.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Modals & Action Handlers
  // ───────────────────────────────────────────────────────────────────────────

  void _openResponseSheet(ReviewModel review, {bool isEditing = false}) {
    final responseController = TextEditingController(text: review.trainerResponse ?? '');
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E22),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditing ? 'Edit Public Response' : 'Reply to Client Review',
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your response will be visible publicly on your coach profile beneath ${review.displayClientName}\'s review.',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: responseController,
                      maxLines: 4,
                      maxLength: 500,
                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Write a professional, courteous reply...',
                        hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Colors.white.withValues(alpha: 0.35)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kLime)),
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorMessage!,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _kBorder),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontFamily: 'Syne', color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final text = responseController.text.trim();
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await _reviewService.submitTrainerResponse(
                                  reviewId: review.id,
                                  trainerId: _trainerId,
                                  responseText: text,
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                HapticFeedback.mediumImpact();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Public response published successfully!'),
                                    backgroundColor: Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                setSheetState(() {
                                  errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '');
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kLime,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              isEditing ? 'Update' : 'Publish Reply',
                              style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: _kDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteResponse(ReviewModel review) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        title: const Text('Delete Response?', style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to remove your public response to this review? You can submit another reply at any time.',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep', style: TextStyle(fontFamily: 'Syne', color: _kGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _reviewService.deleteTrainerResponse(
                reviewId: review.id,
                trainerId: _trainerId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Response deleted.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Syne', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleReportReview(ReviewModel review) {
    if (review.isReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already submitted a report for this review. Admin moderation is pending.'),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String selectedReason = 'Inappropriate or Abusive Language';
    final detailsController = TextEditingController();
    String? reportError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          const reasons = [
            'Inappropriate or Abusive Language',
            'False or Fabricated Feedback',
            'Spam or Commercial Solicitation',
            'Conflict of Interest',
            'Other Platform Policy Violation',
          ];

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E22),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Report Review to Administrators',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Report reviews that violate TRAIN Z code of conduct. Reports are audited impartially by Platform Administrators.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                    ),
                    const SizedBox(height: 14),

                    // Reason Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          dropdownColor: _kCardBg,
                          isExpanded: true,
                          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 12.5),
                          items: reasons.map((r) {
                            return DropdownMenuItem<String>(value: r, child: Text(r));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => selectedReason = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Additional details for administrators (optional)...',
                        hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
                      ),
                    ),

                    if (reportError != null) ...[
                      const SizedBox(height: 4),
                      Text(reportError!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _kBorder),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontFamily: 'Syne', color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await _reviewService.reportReview(
                                  reviewId: review.id,
                                  trainerId: _trainerId,
                                  reason: selectedReason,
                                  details: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                HapticFeedback.mediumImpact();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Report submitted for Admin review.'),
                                    backgroundColor: Colors.amber,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                setSheetState(() {
                                  reportError = e.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Submit Report',
                              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
