import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/booking_service.dart';
import '../../shared/models/booking_model.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/trainer_animations.dart';

enum ScheduleViewMode { daily, weekly, monthly }
enum PackageFilter { all, active, expiringSoon, pendingRequests }
enum TimeSlotFilter { all, morning, afternoon, evening }

/// Redesigned Schedule Section for the Trainer Dashboard.
///
/// Enables trainers to understand in under 5 seconds:
/// 1. Exactly which client is scheduled & their training time
/// 2. What package they have (Monthly, 3 Months, 6 Months, etc.)
/// 3. Remaining days as a high-contrast fraction (e.g. 15/30 Days Left, 7/90 Days Left, 3/30 Days Left)
/// 4. Visual package progress bar with clear Green / Orange / Red health indicators
/// 5. Daily, Weekly, and Monthly layouts with interactive date navigation & instant client search
/// 6. Complete detailed client modal panel with phone dial, fitness goals, and attendance tracking.
class TrainerScheduleSection extends StatefulWidget {
  final double sf;
  const TrainerScheduleSection({super.key, required this.sf});

  @override
  State<TrainerScheduleSection> createState() => _TrainerScheduleSectionState();
}

class _TrainerScheduleSectionState extends State<TrainerScheduleSection> {
  ScheduleViewMode _viewMode = ScheduleViewMode.daily;
  DateTime _selectedDate = DateTime.now();
  PackageFilter _packageFilter = PackageFilter.all;
  TimeSlotFilter _timeSlotFilter = TimeSlotFilter.all;
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectDate(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
  }

  void _navigateDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _pickCalendarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kDark,
              onPrimary: kLime,
              onSurface: kDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _onSelectDate(picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<BookingModel> _filterBookings(List<BookingModel> all) {
    return all.where((b) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = b.displayClientName.toLowerCase().contains(q);
        final phoneMatch = (b.clientPhone ?? '').toLowerCase().contains(q);
        final goalMatch = b.resolvedFitnessGoal.toLowerCase().contains(q);
        final planMatch = b.resolvedPackageName.toLowerCase().contains(q);
        if (!nameMatch && !phoneMatch && !goalMatch && !planMatch) {
          return false;
        }
      }

      // 2. Package / Status Filter
      if (_packageFilter == PackageFilter.active) {
        if (b.packageHealthStatus != 'green' || b.status == BookingStatus.rejected) {
          return false;
        }
      } else if (_packageFilter == PackageFilter.expiringSoon) {
        if (b.packageHealthStatus == 'green' || b.status == BookingStatus.rejected) {
          return false;
        }
      } else if (_packageFilter == PackageFilter.pendingRequests) {
        if (b.status != BookingStatus.pending) {
          return false;
        }
      }

      // 3. Time Slot Filter
      if (_timeSlotFilter != TimeSlotFilter.all) {
        final slot = _categorizeTimeSlot(b.startTime);
        if (slot != _timeSlotFilter) return false;
      }

      // 4. View Mode Date Scope Filter
      if (_viewMode == ScheduleViewMode.daily) {
        return _isSameDay(b.sessionDate, _selectedDate);
      } else if (_viewMode == ScheduleViewMode.weekly) {
        // Find Monday of the selected week
        final weekday = _selectedDate.weekday; // 1 = Mon, 7 = Sun
        final startOfWeek = _selectedDate.subtract(Duration(days: weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
        return b.sessionDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
               b.sessionDate.isBefore(end.add(const Duration(seconds: 1)));
      } else {
        // Monthly view
        return b.sessionDate.year == _selectedDate.year &&
               b.sessionDate.month == _selectedDate.month;
      }
    }).toList();
  }

  TimeSlotFilter _categorizeTimeSlot(String startTime) {
    final s = startTime.toUpperCase().trim();
    if (s.contains('AM')) {
      if (s.startsWith('12')) return TimeSlotFilter.morning;
      return TimeSlotFilter.morning;
    } else if (s.contains('PM')) {
      if (s.startsWith('12') || s.startsWith('01') || s.startsWith('02') ||
          s.startsWith('03') || s.startsWith('04') || s.startsWith('1:') ||
          s.startsWith('2:') || s.startsWith('3:') || s.startsWith('4:')) {
        return TimeSlotFilter.afternoon;
      }
      return TimeSlotFilter.evening;
    }
    return TimeSlotFilter.morning;
  }

  @override
  Widget build(BuildContext context) {
    final sf = widget.sf;
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 28.0);

    return ListenableBuilder(
      listenable: BookingService.instance,
      builder: (context, _) {
        final service = BookingService.instance;
        final allBookings = service.allBookings;
        final pending = service.pendingBookings;
        final filteredList = _filterBookings(allBookings);

        // Stats calculation
        final activeCount = allBookings.where((b) => b.packageHealthStatus == 'green' && b.status != BookingStatus.rejected).length;
        final expiringCount = allBookings.where((b) => b.packageHealthStatus != 'green' && b.status != BookingStatus.rejected).length;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          physics: const BouncingScrollPhysics(),
          child: TrainerFadeSlide(
            delayMs: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),

                // ── Top Header Row with SaaS Live Badge ──
                _buildHeader(sf, pending.length),

                const SizedBox(height: 14),

                // ── Quick Summary Metrics Strip ──
                _buildStatsStrip(sf, total: allBookings.length, active: activeCount, expiring: expiringCount, pending: pending.length),

                const SizedBox(height: 16),

                // ── View Mode Switcher: Daily | Weekly | Monthly ──
                _buildViewModeSelector(sf),

                const SizedBox(height: 14),

                // ── Date Navigator (< Date > + Picker + Jump to Today) ──
                _buildDateNavigator(sf),

                const SizedBox(height: 12),

                // ── View Mode Specific Date Strip / Grid ──
                if (_viewMode == ScheduleViewMode.daily)
                  _buildDailyDateStrip(sf, allBookings)
                else if (_viewMode == ScheduleViewMode.monthly)
                  _buildMonthlyGrid(sf, allBookings),

                const SizedBox(height: 16),

                // ── Search & Filter Controls ──
                _buildSearchAndFilters(sf, pending.length, activeCount, expiringCount),

                const SizedBox(height: 18),

                // ── Section Title & Results Count ──
                _buildResultsHeader(sf, filteredList.length),

                const SizedBox(height: 12),

                // ── Scheduled Client Cards List ──
                if (filteredList.isEmpty)
                  _buildEmptyState(sf)
                else
                  ...filteredList.map((booking) => _TrainerClientScheduleCard(
                        booking: booking,
                        sf: sf,
                        onTap: () => _openClientDetailsPanel(context, booking, sf),
                      )),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI Sub-Components
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(double sf, int pendingCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Client Schedule',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (22.0 * sf).clamp(18.0, 26.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track client packages, remaining sessions, and schedule.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (11.5 * sf).clamp(10.0, 13.0),
                  color: kGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: pendingCount > 0 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: pendingCount > 0 ? const Color(0xFFFFB300) : const Color(0xFF81C784),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingCount > 0)
                const TrainerLivePulseDot(color: Color(0xFFFF9800), size: 7)
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                pendingCount > 0 ? '$pendingCount New' : 'Live Sync',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (10.5 * sf).clamp(9.5, 12.0),
                  fontWeight: FontWeight.w700,
                  color: pendingCount > 0 ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip(double sf, {
    required int total,
    required int active,
    required int expiring,
    required int pending,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (14.0 * sf).clamp(10.0, 18.0),
        vertical: (12.0 * sf).clamp(10.0, 14.0),
      ),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatMiniItem(label: 'Total Clients', value: '$total', color: kDark, sf: sf),
          Container(width: 1, height: 28, color: kBorder),
          _StatMiniItem(label: 'Healthy (>7s)', value: '$active', color: const Color(0xFF16A34A), sf: sf),
          Container(width: 1, height: 28, color: kBorder),
          _StatMiniItem(label: 'Expiring Soon', value: '$expiring', color: const Color(0xFFEA580C), sf: sf),
          if (pending > 0) ...[
            Container(width: 1, height: 28, color: kBorder),
            _StatMiniItem(label: 'Pending Req', value: '$pending', color: const Color(0xFFFF9800), sf: sf),
          ],
        ],
      ),
    );
  }

  Widget _buildViewModeSelector(double sf) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          _buildModeTab('Daily', ScheduleViewMode.daily, Iconsax.calendar_1, sf),
          _buildModeTab('Weekly', ScheduleViewMode.weekly, Iconsax.calendar, sf),
          _buildModeTab('Monthly', ScheduleViewMode.monthly, Iconsax.calendar_tick, sf),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, ScheduleViewMode mode, IconData icon, double sf) {
    final active = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _viewMode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? kDark : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: (14.0 * sf).clamp(12.0, 16.0),
                color: active ? kLime : const Color(0xFF888888),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.0, 13.0),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator(double sf) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    String title;
    if (_viewMode == ScheduleViewMode.daily) {
      if (isToday) {
        title = 'Today, ${_formatHeaderDate(_selectedDate)}';
      } else {
        title = _formatHeaderDate(_selectedDate);
      }
    } else if (_viewMode == ScheduleViewMode.weekly) {
      final weekday = _selectedDate.weekday;
      final start = _selectedDate.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 6));
      title = '${_formatShortDate(start)} - ${_formatShortDate(end)}';
    } else {
      title = _formatMonthYear(_selectedDate);
    }

    return Row(
      children: [
        TrainerPressScale(
          onTap: () => _navigateDate(_viewMode == ScheduleViewMode.monthly ? -30 : (_viewMode == ScheduleViewMode.weekly ? -7 : -1)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.chevron_left_rounded, size: 20, color: kDark),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _pickCalendarDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.calendar_search, size: 16, color: kDark),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (13.0 * sf).clamp(11.5, 14.5),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TrainerPressScale(
          onTap: () => _navigateDate(_viewMode == ScheduleViewMode.monthly ? 30 : (_viewMode == ScheduleViewMode.weekly ? 7 : 1)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.chevron_right_rounded, size: 20, color: kDark),
          ),
        ),
        if (!isToday) ...[
          const SizedBox(width: 8),
          TrainerPressScale(
            onTap: _jumpToToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Today',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(9.5, 12.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDailyDateStrip(double sf, List<BookingModel> bookings) {
    // Show 14 days around selected date (-3 to +10 days)
    final start = _selectedDate.subtract(const Duration(days: 3));
    final dates = List.generate(14, (i) => start.add(Duration(days: i)));

    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: dates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dt = dates[index];
          final isSelected = _isSameDay(dt, _selectedDate);
          final isToday = _isSameDay(dt, DateTime.now());
          final hasSessions = bookings.any((b) => _isSameDay(b.sessionDate, dt));

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _onSelectDate(dt);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? kDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? kDark
                      : isToday
                          ? kLime
                          : kBorder,
                  width: isToday ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayAbbr(dt.weekday),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFFBBBBBB) : kGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dt.day}',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? kLime : kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (hasSessions)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? kLime : const Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyGrid(double sf, List<BookingModel> bookings) {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 = Mon, 7 = Sun

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          // Weekday Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 28,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kGrey,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (firstDayWeekday - 1) + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayWeekday - 1) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - (firstDayWeekday - 1) + 1;
              final dayDate = DateTime(year, month, dayNumber);
              final isSelected = _isSameDay(dayDate, _selectedDate);
              final isToday = _isSameDay(dayDate, DateTime.now());
              final dayBookings = bookings.where((b) => _isSameDay(b.sessionDate, dayDate)).length;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _onSelectDate(dayDate);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? kDark : (isToday ? const Color(0xFFF0FDF4) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: kLime, width: 1.2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? kLime : kDark,
                        ),
                      ),
                      if (dayBookings > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(double sf, int pendingCount, int activeCount, int expiringCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Search Input
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: kField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
            decoration: InputDecoration(
              hintText: 'Search client by name, phone, or goal...',
              hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFAAAAAA)),
              prefixIcon: const Icon(Iconsax.search_normal_1, size: 16, color: kGrey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: kGrey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Filter by Package Status (Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('All Statuses', PackageFilter.all, sf),
              const SizedBox(width: 6),
              _buildFilterChip('Healthy (>7s)', PackageFilter.active, sf, badgeColor: const Color(0xFF16A34A)),
              const SizedBox(width: 6),
              _buildFilterChip('Expiring Soon', PackageFilter.expiringSoon, sf, badgeColor: const Color(0xFFEA580C)),
              if (pendingCount > 0) ...[
                const SizedBox(width: 6),
                _buildFilterChip('Requests ($pendingCount)', PackageFilter.pendingRequests, sf, badgeColor: const Color(0xFFFF9800)),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Filter by Time Slot (Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildTimeChip('All Times', TimeSlotFilter.all, sf),
              const SizedBox(width: 6),
              _buildTimeChip('Morning (<12 PM)', TimeSlotFilter.morning, sf),
              const SizedBox(width: 6),
              _buildTimeChip('Afternoon (12-5 PM)', TimeSlotFilter.afternoon, sf),
              const SizedBox(width: 6),
              _buildTimeChip('Evening (>5 PM)', TimeSlotFilter.evening, sf),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, PackageFilter filter, double sf, {Color? badgeColor}) {
    final selected = _packageFilter == filter;
    return TrainerPressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _packageFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kDark : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? kDark : kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (11.0 * sf).clamp(9.5, 12.0),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, TimeSlotFilter filter, double sf) {
    final selected = _timeSlotFilter == filter;
    return TrainerPressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _timeSlotFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? kLime.withValues(alpha: 0.25) : kField,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? kLime : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (10.5 * sf).clamp(9.5, 11.5),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? kDark : kGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsHeader(double sf, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Scheduled Clients ($count)',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (14.0 * sf).clamp(12.5, 16.0),
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        Text(
          'Tap card for full client details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10.5,
            color: kGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(double sf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.calendar_tick, size: 40, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(
            'No clients found for this view',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (14.0 * sf).clamp(12.5, 16.0),
              fontWeight: FontWeight.w700,
              color: kDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting another date, clearing search keywords, or relaxing status filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10.0, 13.0),
              color: kGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _openClientDetailsPanel(BuildContext context, BookingModel booking, double sf) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrainerClientDetailsSheet(booking: booking, sf: sf),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Formatters
  // ───────────────────────────────────────────────────────────────────────────

  String _weekdayAbbr(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      case 7: return 'SUN';
      default: return '';
    }
  }

  String _formatHeaderDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatShortDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _formatMonthYear(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client Schedule Card (Card Displaying All Core Requirements)
// ─────────────────────────────────────────────────────────────────────────────
class _TrainerClientScheduleCard extends StatelessWidget {
  final BookingModel booking;
  final double sf;
  final VoidCallback onTap;

  const _TrainerClientScheduleCard({
    required this.booking,
    required this.sf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final health = b.packageHealthStatus;

    // Determine color scheme based on Green / Orange / Red indicator
    Color badgeColor;
    Color badgeBg;
    String healthText;
    if (health == 'green') {
      badgeColor = const Color(0xFF16A34A);
      badgeBg = const Color(0xFFE8F5E9);
      healthText = 'Active';
    } else if (health == 'orange') {
      badgeColor = const Color(0xFFEA580C);
      badgeBg = const Color(0xFFFFF3E0);
      healthText = 'Nearing Expiry';
    } else {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFFEBEE);
      healthText = 'Expiring Soon';
    }

    final isPending = b.status == BookingStatus.pending;

    Widget cardContent = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all((14.0 * sf).clamp(12.0, 18.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFFB300)
              : (health == 'red' ? const Color(0xFFFFCDD2) : kBorder),
          width: isPending ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Row: Client Photo/Avatar + Name + Training Time ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Profile Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    b.displayClientName.isNotEmpty ? b.displayClientName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kLime,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Client Name and Goal/Workout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.displayClientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (15.0 * sf).clamp(13.5, 17.0),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                        ),
                        if (isPending) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REQUEST',
                              style: TextStyle(fontFamily: 'Syne', fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.resolvedFitnessGoal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.0 * sf).clamp(10.0, 12.0),
                        color: kGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Training Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.clock, size: 12, color: kDark),
                    const SizedBox(width: 4),
                    Text(
                      '${b.startTime} - ${b.endTime}',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (10.5 * sf).clamp(9.5, 12.0),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),

          // ── Package Name & Dates Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.box_1, size: 13, color: kGrey),
                  const SizedBox(width: 5),
                  Text(
                    b.resolvedPackageName,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (12.0 * sf).clamp(10.5, 13.0),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                ],
              ),
              // Status Indicator (Green / Orange / Red)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      healthText,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Package Dates
          Text(
            'Start: ${_formatDate(b.resolvedStartDate)}  •  Expiry: ${_formatDate(b.resolvedExpiryDate)}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (10.5 * sf).clamp(9.5, 11.5),
              color: kGrey,
            ),
          ),

          const SizedBox(height: 10),

          // ── Package Progress (Crucial Requirement: Fraction + Visual Bar) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining Sessions',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (11.0 * sf).clamp(10.0, 12.0),
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                ),
              ),
              // High-Contrast Fraction
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.remainingDaysFraction,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (12.5 * sf).clamp(11.0, 14.0),
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Visual Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: b.packageProgress,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Quick Action Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.location, size: 12, color: kGrey),
                  const SizedBox(width: 4),
                  Text(
                    b.meetingLocation ?? 'Standard Gym Studio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.5 * sf).clamp(9.5, 11.5),
                      color: kGrey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (11.0 * sf).clamp(10.0, 12.0),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kDark),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (isPending) {
      cardContent = TrainerBreathingGlow(
        glowColor: const Color(0xFFFFB300),
        child: cardContent,
      );
    }

    return TrainerPressScale(
      onTap: onTap,
      child: cardContent,
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client Details Panel (Modern SaaS Slide-Up Modal)
// ─────────────────────────────────────────────────────────────────────────────
class _TrainerClientDetailsSheet extends StatefulWidget {
  final BookingModel booking;
  final double sf;

  const _TrainerClientDetailsSheet({
    required this.booking,
    required this.sf,
  });

  @override
  State<_TrainerClientDetailsSheet> createState() => _TrainerClientDetailsSheetState();
}

class _TrainerClientDetailsSheetState extends State<_TrainerClientDetailsSheet> {
  bool _actionLoading = false;

  void _callClient(String? phone) {
    HapticFeedback.mediumImpact();
    final p = phone ?? '+91 98201 54321';
    Clipboard.setData(ClipboardData(text: p));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contact number $p copied to clipboard for dialing!',
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: kDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _actionLoading = true);
    HapticFeedback.heavyImpact();
    await BookingService.instance.acceptBooking(widget.booking.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Booking accepted for ${widget.booking.displayClientName}!',
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleReject() async {
    setState(() => _actionLoading = true);
    HapticFeedback.mediumImpact();
    await BookingService.instance.rejectBooking(widget.booking.id, reason: 'Schedule conflict');
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session request for ${widget.booking.displayClientName} declined.',
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _markAttendance() async {
    setState(() => _actionLoading = true);
    HapticFeedback.heavyImpact();
    await BookingService.instance.markSessionCompleted(widget.booking.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Attendance recorded! Session marked complete for ${widget.booking.displayClientName}.',
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final sf = widget.sf;
    final health = b.packageHealthStatus;

    Color badgeColor;
    if (health == 'green') {
      badgeColor = const Color(0xFF16A34A);
    } else if (health == 'orange') {
      badgeColor = const Color(0xFFEA580C);
    } else {
      badgeColor = const Color(0xFFDC2626);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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

              const SizedBox(height: 16),

              // ── Client Profile Header ──
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: kDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: badgeColor, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        b.displayClientName.isNotEmpty ? b.displayClientName[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: kLime,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.displayClientName,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (18.0 * sf).clamp(16.0, 22.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Age: ${b.resolvedAge} yrs  •  ${b.clientPhone ?? "+91 98201 54321"}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (12.0 * sf).clamp(10.5, 13.0),
                            color: kGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Call Button
                  TrainerPressScale(
                    onTap: () => _callClient(b.clientPhone),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kLime,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kLime.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Iconsax.call, color: kDark, size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Fitness Goal & Workout Focus Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.activity, size: 15, color: kDark),
                        const SizedBox(width: 6),
                        Text(
                          'Fitness Goal & Routine',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (13.0 * sf).clamp(11.5, 14.5),
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.resolvedFitnessGoal,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: kDark),
                    ),
                    if (b.notes != null && b.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Notes: ${b.notes!}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Package Progress & Details Card (Crucial Section) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.medal_star, size: 16, color: kDark),
                            const SizedBox(width: 6),
                            Text(
                              b.resolvedPackageName,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (14.5 * sf).clamp(13.0, 16.5),
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                          ],
                        ),
                        // Fraction Highlight
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b.remainingDaysFraction,
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Visual Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 9,
                        child: LinearProgressIndicator(
                          value: b.packageProgress,
                          backgroundColor: const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Metrics Grid (Total Sessions, Sessions Done, Remaining, Dates)
                    Row(
                      children: [
                        Expanded(
                          child: _MetricDetailBox(
                            label: 'Total Sessions',
                            value: '${b.resolvedTotalDays} Sessions',
                            icon: Iconsax.calendar_tick,
                            sf: sf,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricDetailBox(
                            label: 'Sessions Done',
                            value: '${b.resolvedDaysCompleted} Sessions',
                            icon: Iconsax.tick_circle,
                            sf: sf,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricDetailBox(
                            label: 'Remaining',
                            value: '${b.resolvedDaysRemaining} Sessions',
                            icon: Iconsax.timer_1,
                            valueColor: badgeColor,
                            sf: sf,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Start & Expiry Dates Row
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kField,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Package Start', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: kGrey)),
                              Text(
                                _formatFullDate(b.resolvedStartDate),
                                style: const TextStyle(fontFamily: 'Syne', fontSize: 12, fontWeight: FontWeight.w700, color: kDark),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 24, color: kBorder),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Package Expiry', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: kGrey)),
                              Text(
                                _formatFullDate(b.resolvedExpiryDate),
                                style: TextStyle(fontFamily: 'Syne', fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Attendance & Sessions Attended
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attendance & Sessions:',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
                        ),
                        Text(
                          '${b.resolvedSessionsCompleted} / ${b.resolvedTotalSessions} Attended',
                          style: const TextStyle(fontFamily: 'Syne', fontSize: 12.5, fontWeight: FontWeight.w800, color: kDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Scheduled Session Time & Location ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.clock, size: 14, color: kDark),
                        const SizedBox(width: 6),
                        Text(
                          'Session: ${b.startTime} - ${b.endTime}  •  ${_formatFullDate(b.sessionDate)}',
                          style: const TextStyle(fontFamily: 'Syne', fontSize: 12.5, fontWeight: FontWeight.w700, color: kDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Iconsax.location, size: 14, color: kGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.meetingLocation ?? 'Standard Gym Studio',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Action Buttons ──
              if (_actionLoading)
                const Center(child: CircularProgressIndicator(color: kDark))
              else if (b.status == BookingStatus.pending) ...[
                Row(
                  children: [
                    Expanded(
                      child: TrainerPressScale(
                        onTap: _handleReject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: const Center(
                            child: Text(
                              'Decline',
                              style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TrainerPressScale(
                        onTap: _handleAccept,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: kDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Accept Request',
                              style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: kLime),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (b.status == BookingStatus.confirmed) ...[
                TrainerPressScale(
                  onTap: _markAttendance,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kDark,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_rounded, color: kLime, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Mark Session Attended & Complete',
                          style: TextStyle(fontFamily: 'Syne', fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Box Helper
// ─────────────────────────────────────────────────────────────────────────────
class _MetricDetailBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final double sf;

  const _MetricDetailBox({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: kGrey),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (11.5 * sf).clamp(10.0, 13.0),
              fontWeight: FontWeight.w800,
              color: valueColor ?? kDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.5,
              color: kGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMiniItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double sf;

  const _StatMiniItem({
    required this.label,
    required this.value,
    required this.color,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (16.0 * sf).clamp(14.0, 19.0),
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (9.5 * sf).clamp(8.5, 11.0),
            color: kGrey,
          ),
        ),
      ],
    );
  }
}
