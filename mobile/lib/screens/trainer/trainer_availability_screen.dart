import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_availability_service.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/models/trainer_availability_model.dart';
import '../../widgets/app_widgets.dart';

/// Screen allowing Trainers to manage their Availability & Calendar:
/// 1. Weekly Schedule: Configure recurring days, non-overlapping windows (>= 60 min), and breaks.
/// 2. Calendar & Overrides: View availability by Day, Week, and Month; inspect confirmed bookings;
///    block dates; set custom hours; and view discrete 60-minute time slots.
class TrainerAvailabilityScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerAvailabilityScreen({
    super.key,
    this.trainerId,
  });

  @override
  State<TrainerAvailabilityScreen> createState() => _TrainerAvailabilityScreenState();
}

enum CalendarViewType { day, week, month }

class _TrainerAvailabilityScreenState extends State<TrainerAvailabilityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TrainerAvailabilityService _availabilityService = TrainerAvailabilityService.instance;

  late String _trainerId;
  bool _isLoading = true;
  bool _isSaving = false;

  // Weekly Schedule State
  late TrainerAvailabilityModel _availabilityModel;
  late List<DayAvailability> _editableDays;

  // Calendar Management State
  CalendarViewType _calendarView = CalendarViewType.day;
  DateTime _selectedDate = DateTime.now();
  final Set<String> _blockedDatesCache = {};

  // Standard selectable hours in 30-min increments for window pickers
  static final List<String> _timeOptions = [
    '05:00 AM', '05:30 AM', '06:00 AM', '06:30 AM', '07:00 AM', '07:30 AM',
    '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM', '01:00 PM', '01:30 PM',
    '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM',
    '05:00 PM', '05:30 PM', '06:00 PM', '06:30 PM', '07:00 PM', '07:30 PM',
    '08:00 PM', '08:30 PM', '09:00 PM', '09:30 PM', '10:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        (kReleaseMode ? '' : 'trainer_demo_user');
    _loadAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    try {
      final model = await _availabilityService.getWeeklyAvailability(_trainerId);
      if (!mounted) return;
      setState(() {
        _availabilityModel = model;
        // Deep copy of days for editing
        _editableDays = model.days.map((d) {
          return DayAvailability(
            dayOfWeek: d.dayOfWeek,
            isEnabled: d.isEnabled,
            windows: d.windows.map((w) => AvailabilityWindow(start: w.start, end: w.end)).toList(),
          );
        }).toList();

        // Ensure all 7 days exist (1 = Mon .. 7 = Sun)
        for (int i = 1; i <= 7; i++) {
          if (!_editableDays.any((d) => d.dayOfWeek == i)) {
            _editableDays.add(DayAvailability(
              dayOfWeek: i,
              isEnabled: i != 7,
              windows: i == 7
                  ? []
                  : [
                      const AvailabilityWindow(start: '06:00 AM', end: '11:00 AM'),
                      const AvailabilityWindow(start: '04:00 PM', end: '08:00 PM'),
                    ],
            ));
          }
        }
        _editableDays.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

        _blockedDatesCache.clear();
        for (final o in model.overrides) {
          if (o.isBlocked) _blockedDatesCache.add(o.date);
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = TrainerAvailabilityModel.defaultSchedule(_trainerId);
      setState(() {
        _availabilityModel = fallback;
        _editableDays = fallback.days.map((d) {
          return DayAvailability(
            dayOfWeek: d.dayOfWeek,
            isEnabled: d.isEnabled,
            windows: d.windows.map((w) => AvailabilityWindow(start: w.start, end: w.end)).toList(),
          );
        }).toList();
        _isLoading = false;
      });
    }
  }

  // ─── Weekly Schedule Handlers ─────────────────────────────────────────────────

  void _toggleDay(int index, bool isEnabled) {
    setState(() {
      final old = _editableDays[index];
      List<AvailabilityWindow> windows = old.windows;
      if (isEnabled && windows.isEmpty) {
        // Default windows when turning on a day
        windows = [
          const AvailabilityWindow(start: '06:00 AM', end: '11:00 AM'),
          const AvailabilityWindow(start: '04:00 PM', end: '08:00 PM'),
        ];
      }
      _editableDays[index] = old.copyWith(
        isEnabled: isEnabled,
        windows: windows,
      );
    });
  }

  void _addWindow(int dayIndex) {
    setState(() {
      final day = _editableDays[dayIndex];
      final currentWindows = List<AvailabilityWindow>.from(day.windows);

      // Determine sensible next time slot
      String newStart = '05:00 PM';
      String newEnd = '08:00 PM';

      if (currentWindows.isNotEmpty) {
        final lastEndMin = currentWindows.last.endMinutes;
        final startMin = (lastEndMin + 60) % 1440;
        final endMin = (startMin + 180) % 1440;
        if (startMin < 1380 && startMin > lastEndMin) {
          newStart = minutesToTimeString(startMin);
          newEnd = minutesToTimeString(endMin);
        }
      }

      currentWindows.add(AvailabilityWindow(start: newStart, end: newEnd));
      currentWindows.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      _editableDays[dayIndex] = day.copyWith(windows: currentWindows);
    });
  }

  void _removeWindow(int dayIndex, int windowIndex) {
    setState(() {
      final day = _editableDays[dayIndex];
      final currentWindows = List<AvailabilityWindow>.from(day.windows);
      currentWindows.removeAt(windowIndex);
      _editableDays[dayIndex] = day.copyWith(
        windows: currentWindows,
        isEnabled: currentWindows.isNotEmpty,
      );
    });
  }

  void _updateWindowTime(int dayIndex, int windowIndex, {String? start, String? end}) {
    setState(() {
      final day = _editableDays[dayIndex];
      final currentWindows = List<AvailabilityWindow>.from(day.windows);
      final old = currentWindows[windowIndex];
      currentWindows[windowIndex] = AvailabilityWindow(
        start: start ?? old.start,
        end: end ?? old.end,
      );
      _editableDays[dayIndex] = day.copyWith(windows: currentWindows);
    });
  }

  String? _validateDaySchedule(DayAvailability day) {
    if (!day.isEnabled || day.windows.isEmpty) return null;
    for (int i = 0; i < day.windows.length; i++) {
      final w1 = day.windows[i];
      if (w1.startMinutes >= w1.endMinutes) {
        return '${w1.start} must be earlier than ${w1.end}';
      }
      if (w1.durationMinutes < 60) {
        return 'Window ${w1.start} - ${w1.end} must be at least 60 minutes';
      }
      for (int j = i + 1; j < day.windows.length; j++) {
        final w2 = day.windows[j];
        if (w1.overlapsWith(w2)) {
          return 'Windows (${w1.start}-${w1.end}) and (${w2.start}-${w2.end}) overlap';
        }
      }
    }
    return null;
  }

  Future<void> _saveWeeklySchedule() async {
    // Validate all enabled days
    for (final day in _editableDays) {
      final error = _validateDaySchedule(day);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE53935),
            content: Text(
              '${day.dayName}: $error',
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await _availabilityService.saveWeeklyAvailability(
        trainerId: _trainerId,
        days: _editableDays,
        timezone: _availabilityModel.timezone,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kDark,
          content: Row(
            children: [
              Icon(Iconsax.tick_circle, color: kLime, size: 20),
              SizedBox(width: 10),
              Text(
                'Weekly availability saved successfully.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              ),
            ],
          ),
        ),
      );
      _loadAvailability();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE53935),
          content: Text(
            'Failed to save: $e',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
        ),
      );
    }
  }

  // ─── Calendar Overrides Handlers ─────────────────────────────────────────────

  Future<void> _toggleBlockSelectedDate() async {
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);
    final currentlyBlocked = _blockedDatesCache.contains(dateStr);

    if (currentlyBlocked) {
      // Unblock date
      await _availabilityService.removeDateOverride(
        trainerId: _trainerId,
        dateStr: dateStr,
      );
      setState(() {
        _blockedDatesCache.remove(dateStr);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kDark,
          content: Text(
            'Date $dateStr unblocked. Regular weekly schedule restored.',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
        ),
      );
      _loadAvailability();
    } else {
      // Show block confirmation dialog with reason
      final reasonController = TextEditingController(text: 'Personal Leave');
      final shouldBlock = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Block Date',
            style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Block $dateStr so clients cannot book training sessions on this day.',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kGrey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFEEBA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Iconsax.info_circle, size: 16, color: Color(0xFF856404)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confirmed client bookings cannot be cancelled via availability. Any booked sessions will remain valid.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for leave',
                  labelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: kGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              child: const Text('Block Date', style: TextStyle(fontFamily: 'Syne', color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldBlock == true) {
        final res = await _availabilityService.setBlockedDate(
          trainerId: _trainerId,
          dateStr: dateStr,
          isBlocked: true,
          reason: reasonController.text.trim(),
        );
        setState(() {
          _blockedDatesCache.add(dateStr);
        });

        if (!mounted) return;
        String msg = 'Date $dateStr blocked.';
        if (res.confirmedBookingsCount > 0) {
          msg += ' Notice: ${res.confirmedBookingsCount} confirmed session(s) remain active.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kDark,
            content: Text(msg, style: const TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        );
        _loadAvailability();
      }
    }
  }

  void _openCustomHoursModal() {
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);
    final dayOfWeek = _selectedDate.weekday;
    final dayConfig = _availabilityModel.day(dayOfWeek);
    final existingOverride = _availabilityModel.overrideForDate(_selectedDate);

    List<AvailabilityWindow> tempWindows = existingOverride != null && existingOverride.customWindows.isNotEmpty
        ? existingOverride.customWindows.map((w) => AvailabilityWindow(start: w.start, end: w.end)).toList()
        : dayConfig.windows.map((w) => AvailabilityWindow(start: w.start, end: w.end)).toList();

    if (tempWindows.isEmpty) {
      tempWindows.add(const AvailabilityWindow(start: '07:00 AM', end: '11:00 AM'));
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom Hours: $dateStr',
                        style: const TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w700, color: kDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: kGrey),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set custom availability windows for this date only. Minimum 60 min per window.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(tempWindows.length, (idx) {
                    final w = tempWindows[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: w.start,
                              decoration: const InputDecoration(labelText: 'Start', border: OutlineInputBorder()),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    tempWindows[idx] = AvailabilityWindow(start: val, end: w.end);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: w.end,
                              decoration: const InputDecoration(labelText: 'End', border: OutlineInputBorder()),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    tempWindows[idx] = AvailabilityWindow(start: w.start, end: val);
                                  });
                                }
                              },
                            ),
                          ),
                          if (tempWindows.length > 1)
                            IconButton(
                              icon: const Icon(Iconsax.trash, color: Color(0xFFE53935), size: 18),
                              onPressed: () {
                                setModalState(() {
                                  tempWindows.removeAt(idx);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setModalState(() {
                        tempWindows.add(const AvailabilityWindow(start: '04:00 PM', end: '08:00 PM'));
                      });
                    },
                    icon: const Icon(Iconsax.add, size: 18, color: kDark),
                    label: const Text('Add Another Window', style: TextStyle(fontFamily: 'Poppins', color: kDark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _availabilityService.setCustomDateWindows(
                            trainerId: _trainerId,
                            dateStr: dateStr,
                            windows: tempWindows,
                            reason: 'Custom Hours',
                          );
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: kDark,
                              content: Text('Custom hours saved for $dateStr.', style: const TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                            ),
                          );
                          _loadAvailability();
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFE53935),
                              content: Text('$e', style: const TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Custom Hours', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Build UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Availability & Calendar',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18 * sf).clamp(16, 22),
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kField,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.global, size: 14, color: kDark),
                const SizedBox(width: 4),
                Text(
                  'IST (Asia/Kolkata)',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10 * sf, color: kDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kDark,
          unselectedLabelColor: kGrey,
          indicatorColor: kDark,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Weekly Schedule'),
            Tab(text: 'Calendar & Overrides'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kDark))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyScheduleTab(sf),
                _buildCalendarTab(sf),
              ],
            ),
    );
  }

  // ─── 1. Weekly Schedule Tab ──────────────────────────────────────────────────

  Widget _buildWeeklyScheduleTab(double sf) {
    return Column(
      children: [
        // Informational header banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kLime.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.clock, color: kDark, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '60-Minute Session Slots',
                      style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13 * sf, color: kDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Windows are divided into 60-min sessions. Gaps between windows are automatic breaks.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * sf, color: kGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Days of week list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _editableDays.length,
            itemBuilder: (context, dayIndex) {
              final day = _editableDays[dayIndex];
              return _buildDayCard(dayIndex, day, sf);
            },
          ),
        ),

        // Sticky Save Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveWeeklySchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.tick_circle, color: kLime, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save Weekly Availability',
                            style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(int dayIndex, DayAvailability day, double sf) {
    final validationError = _validateDaySchedule(day);
    final sortedWindows = List<AvailabilityWindow>.from(day.windows)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: validationError != null ? const Color(0xFFE53935) : const Color(0xFFEAEAEA),
          width: validationError != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: day.isEnabled ? kDark : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        day.dayShort,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11 * sf,
                          fontWeight: FontWeight.w700,
                          color: day.isEnabled ? kLime : kGrey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      day.dayName,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14 * sf,
                        fontWeight: FontWeight.w700,
                        color: day.isEnabled ? kDark : kGrey,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: day.isEnabled,
                  activeThumbColor: kDark,
                  activeTrackColor: kLime,
                  onChanged: (val) => _toggleDay(dayIndex, val),
                ),
              ],
            ),
          ),

          if (day.isEnabled) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            if (sortedWindows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No windows configured. Day is currently off.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12 * sf, color: kGrey),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (int i = 0; i < sortedWindows.length; i++) ...[
                      // Window Item
                      _buildWindowItem(dayIndex, i, sortedWindows[i], sf),

                      // Break display between windows
                      if (i < sortedWindows.length - 1)
                        _buildBreakBadge(sortedWindows[i], sortedWindows[i + 1], sf),
                    ],
                  ],
                ),
              ),

            // Inline validation error if any
            if (validationError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFE53935)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        validationError,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFFE53935)),
                      ),
                    ),
                  ],
                ),
              ),

            // Add Window Button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${day.generateSlots().length} session slots',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * sf, color: kGrey, fontWeight: FontWeight.w500),
                  ),
                  TextButton.icon(
                    onPressed: () => _addWindow(dayIndex),
                    icon: const Icon(Iconsax.add_circle, size: 16, color: kDark),
                    label: Text(
                      'Add Time Window',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12 * sf, color: kDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWindowItem(int dayIndex, int windowIndex, AvailabilityWindow window, double sf) {
    final slotCount = window.generate60MinSlots().length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // Start Time Picker
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _timeOptions.contains(window.start) ? window.start : _timeOptions.first,
                isDense: true,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12 * sf, color: kDark, fontWeight: FontWeight.w600),
                items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (newStart) {
                  if (newStart != null) {
                    _updateWindowTime(dayIndex, windowIndex, start: newStart);
                  }
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('→', style: TextStyle(color: kGrey, fontWeight: FontWeight.bold)),
          ),
          // End Time Picker
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _timeOptions.contains(window.end) ? window.end : _timeOptions.last,
                isDense: true,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12 * sf, color: kDark, fontWeight: FontWeight.w600),
                items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (newEnd) {
                  if (newEnd != null) {
                    _updateWindowTime(dayIndex, windowIndex, end: newEnd);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Slot count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              '$slotCount slots',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10 * sf, color: kDark, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.trash, size: 16, color: Color(0xFFE53935)),
            onPressed: () => _removeWindow(dayIndex, windowIndex),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakBadge(AvailabilityWindow w1, AvailabilityWindow w2, double sf) {
    final breakMinutes = w2.startMinutes - w1.endMinutes;
    if (breakMinutes <= 0) return const SizedBox.shrink();

    final hours = breakMinutes ~/ 60;
    final mins = breakMinutes % 60;
    final durationStr = hours > 0 ? (mins > 0 ? '${hours}h ${mins}m' : '${hours}h') : '${mins}m';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.coffee, size: 12, color: Color(0xFFF57F17)),
          const SizedBox(width: 6),
          Text(
            'Break: ${w1.end} - ${w2.start} ($durationStr)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10 * sf,
              color: const Color(0xFFF57F17),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Calendar & Overrides Tab ─────────────────────────────────────────────

  Widget _buildCalendarTab(double sf) {
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);
    final isBlocked = _blockedDatesCache.contains(dateStr);
    final override = _availabilityModel.overrideForDate(_selectedDate);
    final hasCustomHours = override != null && !override.isBlocked && override.customWindows.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Switcher (Day / Week / Month)
          Row(
            children: [
              _buildViewPill(CalendarViewType.day, 'Day View', sf),
              const SizedBox(width: 8),
              _buildViewPill(CalendarViewType.week, 'Week View', sf),
              const SizedBox(width: 8),
              _buildViewPill(CalendarViewType.month, 'Month View', sf),
            ],
          ),
          const SizedBox(height: 16),

          // Date Navigator Strip
          _buildDateNavigator(sf),
          const SizedBox(height: 16),

          if (_calendarView == CalendarViewType.day) ...[
            // Status Card for Selected Date
            _buildDateStatusCard(dateStr, isBlocked, hasCustomHours, override, sf),
            const SizedBox(height: 16),

            // Confirmed Client Bookings on this Date
            _buildConfirmedBookingsSection(dateStr, sf),
            const SizedBox(height: 16),

            // 60-Minute Slots Breakdown
            _buildSlotsBreakdownSection(sf),
          ] else if (_calendarView == CalendarViewType.week) ...[
            _buildWeekOverview(sf),
          ] else ...[
            _buildMonthOverview(sf),
          ],
        ],
      ),
    );
  }

  Widget _buildViewPill(CalendarViewType type, String label, double sf) {
    final isSelected = _calendarView == type;
    return GestureDetector(
      onTap: () => setState(() => _calendarView = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kDark : kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 11 * sf,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : kGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator(double sf) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22, color: kDark),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      _calendarView == CalendarViewType.month
                          ? const Duration(days: 30)
                          : _calendarView == CalendarViewType.week
                              ? const Duration(days: 7)
                              : const Duration(days: 1),
                    );
                  });
                },
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: now.subtract(const Duration(days: 90)),
                    lastDate: now.add(const Duration(days: 180)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar, size: 18, color: kDark),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTitle(_selectedDate),
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14 * sf,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22, color: kDark),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(
                      _calendarView == CalendarViewType.month
                          ? const Duration(days: 30)
                          : _calendarView == CalendarViewType.week
                              ? const Duration(days: 7)
                              : const Duration(days: 1),
                    );
                  });
                },
              ),
            ],
          ),

          // Horizontal 7-Day Picker
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (i) {
                final day = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1 - i));
                final isSelected = day.year == _selectedDate.year &&
                    day.month == _selectedDate.month &&
                    day.day == _selectedDate.day;
                final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                final dStr = day.toIso8601String().substring(0, 10);
                final isBlocked = _blockedDatesCache.contains(dStr);

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = day),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kDark
                          : isBlocked
                              ? const Color(0xFFFFEBEE)
                              : kField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? kDark
                            : isToday
                                ? kLime
                                : kBorder,
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1],
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11 * sf,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : kGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 13 * sf,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? kLime
                                : isBlocked
                                    ? const Color(0xFFE53935)
                                    : kDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStatusCard(
    String dateStr,
    bool isBlocked,
    bool hasCustomHours,
    TrainerDateOverride? override,
    double sf,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBlocked
            ? const Color(0xFFFFF5F5)
            : hasCustomHours
                ? const Color(0xFFFFF9E6)
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked
              ? const Color(0xFFFFCDD2)
              : hasCustomHours
                  ? const Color(0xFFFFE082)
                  : const Color(0xFFEAEAEA),
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBlocked
                          ? const Color(0xFFE53935)
                          : hasCustomHours
                              ? const Color(0xFFF57F17)
                              : kDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isBlocked
                          ? 'BLOCKED / OFF'
                          : hasCustomHours
                              ? 'CUSTOM HOURS'
                              : 'WEEKLY SCHEDULE',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10 * sf,
                        fontWeight: FontWeight.w700,
                        color: isBlocked || hasCustomHours ? Colors.white : kLime,
                      ),
                    ),
                  ),
                  if (override?.reason != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${override!.reason})',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * sf, color: kGrey),
                    ),
                  ],
                ],
              ),
              if (isBlocked)
                TextButton(
                  onPressed: _toggleBlockSelectedDate,
                  child: const Text(
                    'Unblock Date',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: Color(0xFFE53935)),
                  ),
                )
              else if (hasCustomHours)
                TextButton(
                  onPressed: () async {
                    await _availabilityService.removeDateOverride(
                      trainerId: _trainerId,
                      dateStr: dateStr,
                    );
                    _loadAvailability();
                  },
                  child: const Text(
                    'Reset to Weekly',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: kDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons
          if (!isBlocked)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleBlockSelectedDate,
                    icon: const Icon(Iconsax.slash, size: 16, color: Color(0xFFE53935)),
                    label: Text(
                      'Block Date',
                      style: TextStyle(fontFamily: 'Syne', fontSize: 12 * sf, color: const Color(0xFFE53935), fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE53935)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openCustomHoursModal,
                    icon: const Icon(Iconsax.clock, size: 16, color: Colors.white),
                    label: Text(
                      'Custom Hours',
                      style: TextStyle(fontFamily: 'Syne', fontSize: 12 * sf, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmedBookingsSection(String dateStr, double sf) {
    return FutureBuilder<List<BookingModel>>(
      future: _availabilityService.getConfirmedBookingsForDate(_trainerId, dateStr),
      builder: (context, snapshot) {
        final bookings = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.calendar_tick, size: 18, color: kDark),
                      const SizedBox(width: 8),
                      Text(
                        'Confirmed Client Sessions',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 14 * sf, fontWeight: FontWeight.w700, color: kDark),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: bookings.isNotEmpty ? kDark : kField,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${bookings.length}',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 11 * sf,
                        fontWeight: FontWeight.w700,
                        color: bookings.isNotEmpty ? kLime : kGrey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Callout warning about confirmed bookings protection
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.shield_tick, size: 16, color: kDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confirmed bookings are protected and cannot be cancelled through availability settings.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10 * sf, color: kDark),
                      ),
                    ),
                  ],
                ),
              ),

              if (bookings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'No confirmed client sessions scheduled for this date.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12 * sf, color: kGrey),
                    ),
                  ),
                )
              else
                ...bookings.map((b) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kField,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 36,
                          decoration: BoxDecoration(
                            color: kDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.clientName ?? 'TRAIN Z Athlete',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 13 * sf,
                                  fontWeight: FontWeight.w700,
                                  color: kDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${b.startTime} - ${b.endTime} • 60 min session',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * sf, color: kGrey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kLime.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CONFIRMED',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 9 * sf,
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotsBreakdownSection(double sf) {
    return StreamBuilder<List<TimeSlot>>(
      stream: _availabilityService.streamSlotsForTrainerDate(
        trainerId: _trainerId,
        date: _selectedDate,
      ),
      builder: (context, snapshot) {
        final slots = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.clock, size: 18, color: kDark),
                      const SizedBox(width: 8),
                      Text(
                        '60-Minute Slots Breakdown',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 14 * sf, fontWeight: FontWeight.w700, color: kDark),
                      ),
                    ],
                  ),
                  Text(
                    '${slots.where((s) => s.isAvailable).length} Available',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * sf, color: kDark, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (slots.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Iconsax.calendar_remove, size: 36, color: kGrey),
                        const SizedBox(height: 8),
                        Text(
                          'No available slots on this date.',
                          style: TextStyle(fontFamily: 'Syne', fontSize: 13 * sf, fontWeight: FontWeight.w700, color: kDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date is blocked or outside working hours.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * sf, color: kGrey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((s) => _buildSlotPill(s, sf)).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotPill(TimeSlot slot, double sf) {
    Color bg = Colors.white;
    Color border = kBorder;
    Color text = kDark;
    String statusLabel = 'Available';

    if (slot.isBooked) {
      bg = kDark;
      border = kDark;
      text = Colors.white;
      statusLabel = slot.bookedByClientName != null ? 'Booked: ${slot.bookedByClientName}' : 'Booked';
    } else if (slot.isReserved) {
      bg = const Color(0xFFFFF3CD);
      border = const Color(0xFFFFEEBA);
      text = const Color(0xFF856404);
      statusLabel = 'Hold (Checkout)';
    } else if (slot.isPast) {
      bg = const Color(0xFFF0F0F0);
      border = const Color(0xFFE0E0E0);
      text = const Color(0xFF9E9E9E);
      statusLabel = 'Elapsed';
    } else {
      bg = kLime.withValues(alpha: 0.15);
      border = kLime;
      text = kDark;
      statusLabel = 'Open';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${slot.start} - ${slot.end}',
            style: TextStyle(fontFamily: 'Syne', fontSize: 11 * sf, fontWeight: FontWeight.w700, color: text),
          ),
          const SizedBox(height: 2),
          Text(
            statusLabel,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9 * sf,
              fontWeight: FontWeight.w600,
              color: slot.isBooked ? kLime : text,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Week Overview ───────────────────────────────────────────────────────────

  Widget _buildWeekOverview(double sf) {
    return Column(
      children: List.generate(7, (i) {
        final day = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1 - i));
        final dStr = day.toIso8601String().substring(0, 10);
        final isBlocked = _blockedDatesCache.contains(dStr);
        final dayConfig = _availabilityModel.day(day.weekday);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isBlocked ? const Color(0xFFFFCDD2) : const Color(0xFFEAEAEA)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isBlocked ? const Color(0xFFFFEBEE) : kField,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 13 * sf,
                          fontWeight: FontWeight.w700,
                          color: isBlocked ? const Color(0xFFE53935) : kDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day.weekday - 1],
                        style: TextStyle(fontFamily: 'Syne', fontSize: 13 * sf, fontWeight: FontWeight.w700, color: kDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBlocked
                            ? 'Blocked (Day Off)'
                            : !dayConfig.isEnabled
                                ? 'Weekly Rest Day'
                                : '${dayConfig.windows.length} windows • ${dayConfig.generateSlots().length} sessions',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11 * sf,
                          color: isBlocked ? const Color(0xFFE53935) : kGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 14, color: kGrey),
                onPressed: () {
                  setState(() {
                    _selectedDate = day;
                    _calendarView = CalendarViewType.day;
                  });
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Month Overview ──────────────────────────────────────────────────────────

  Widget _buildMonthOverview(double sf) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatMonthYear(_selectedDate),
            style: TextStyle(fontFamily: 'Syne', fontSize: 16 * sf, fontWeight: FontWeight.w700, color: kDark),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final dayNum = index + 1;
              final dayDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final dStr = dayDate.toIso8601String().substring(0, 10);
              final isBlocked = _blockedDatesCache.contains(dStr);
              final isSelected = dayDate.day == _selectedDate.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = dayDate;
                    _calendarView = CalendarViewType.day;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kDark
                        : isBlocked
                            ? const Color(0xFFFFEBEE)
                            : kField,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? kDark : (isBlocked ? const Color(0xFFFFCDD2) : kBorder),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 12 * sf,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? kLime
                            : isBlocked
                                ? const Color(0xFFE53935)
                                : kDark,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDateTitle(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatMonthYear(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
