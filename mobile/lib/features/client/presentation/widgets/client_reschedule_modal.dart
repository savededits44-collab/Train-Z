import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/trainer_availability_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/trainer_availability_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Modal bottom sheet allowing clients to reschedule a booking session,
/// selecting from genuine available 60-minute trainer slots with double-booking prevention.
class ClientRescheduleModal extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onRescheduled;

  const ClientRescheduleModal({
    super.key,
    required this.booking,
    this.onRescheduled,
  });

  static Future<bool?> show(
    BuildContext context, {
    required BookingModel booking,
    VoidCallback? onRescheduled,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientRescheduleModal(
        booking: booking,
        onRescheduled: onRescheduled,
      ),
    );
  }

  @override
  State<ClientRescheduleModal> createState() => _ClientRescheduleModalState();
}

class _ClientRescheduleModalState extends State<ClientRescheduleModal> {
  final _firestoreService = FirestoreService();

  late DateTime _selectedDate;
  TimeSlot? _selectedSlot;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start from tomorrow
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  Future<void> _handleConfirmReschedule() async {
    if (_selectedSlot == null || !_selectedSlot!.isAvailable) {
      setState(() => _errorMessage = 'Please select an available 60-minute time slot.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await _firestoreService.rescheduleBooking(
        bookingId: widget.booking.id,
        newSessionDate: _selectedDate,
        newStartTime: _selectedSlot!.start,
        newEndTime: _selectedSlot!.end,
      );

      if (!mounted) return;

      widget.onRescheduled?.call();
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session rescheduled to ${_formatDate(_selectedDate)} at ${_selectedSlot!.start} - ${_selectedSlot!.end}',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        if (e is BookingConflictException) {
          _errorMessage = e.message;
        } else {
          _errorMessage = 'Rescheduling failed: $e';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    // Generate next 14 eligible days
    final nextDays = List.generate(14, (i) {
      final now = DateTime.now().add(Duration(days: i + 1));
      return DateTime(now.year, now.month, now.day);
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.calendar_edit, color: kLime, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reschedule Session',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (16.0 * sf).clamp(15.0, 18.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        Text(
                          'Trainer: ${widget.booking.displayTrainerName}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (10.5 * sf).clamp(9.5, 11.5),
                            color: kGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: kDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Session info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.info_circle, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current slot: ${_formatDate(widget.booking.sessionDate)} • ${widget.booking.startTime} - ${widget.booking.endTime}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 1. DATE SELECTION ──
                  Text(
                    'SELECT NEW DATE',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (11.0 * sf).clamp(10.0, 12.0),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF888888),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: nextDays.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final d = nextDays[index];
                        final isSelected = d.year == _selectedDate.year &&
                            d.month == _selectedDate.month &&
                            d.day == _selectedDate.day;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedDate = d;
                              _selectedSlot = null;
                              _errorMessage = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 62,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? kDark : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? kDark : const Color(0xFFE5E7EB),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _weekdayShort(d.weekday),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? kLime : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : kDark,
                                  ),
                                ),
                                Text(
                                  _monthShort(d.month),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9.5,
                                    color: isSelected ? const Color(0xFFD1D5DB) : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── 2. 60-MINUTE TIME SLOT SELECTION ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AVAILABLE 60-MIN SLOTS',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF888888),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kLime.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '60 Mins',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<List<TimeSlot>>(
                    stream: TrainerAvailabilityService.instance.streamSlotsForTrainerDate(
                      trainerId: widget.booking.trainerId,
                      date: _selectedDate,
                      currentClientId: widget.booking.clientId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator(color: kDark)),
                        );
                      }

                      final slots = snapshot.data ?? [];
                      if (slots.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Iconsax.calendar_remove, size: 18, color: Color(0xFF6B7280)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Trainer is not available on this date. Please choose another date.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: slots.map((slot) {
                          final isAvailable = slot.isAvailable;
                          final isSelected = _selectedSlot != null &&
                              _selectedSlot!.start.trim().toUpperCase() == slot.start.trim().toUpperCase();

                          return InkWell(
                            onTap: isAvailable
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedSlot = slot;
                                      _errorMessage = null;
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: !isAvailable
                                    ? const Color(0xFFF3F4F6)
                                    : isSelected
                                        ? kDark
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isAvailable
                                      ? const Color(0xFFE5E7EB)
                                      : isSelected
                                          ? kDark
                                          : const Color(0xFFD1D5DB),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    !isAvailable
                                        ? Icons.block
                                        : isSelected
                                            ? Iconsax.tick_circle
                                            : Iconsax.clock,
                                    size: 14,
                                    color: !isAvailable
                                        ? const Color(0xFF9CA3AF)
                                        : isSelected
                                            ? kLime
                                            : kDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${slot.start} - ${slot.end}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: !isAvailable
                                          ? const Color(0xFF9CA3AF)
                                          : isSelected
                                              ? Colors.white
                                              : kDark,
                                      decoration: !isAvailable ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer Confirm Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _selectedSlot == null || !_selectedSlot!.isAvailable
                    ? null
                    : _handleConfirmReschedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  foregroundColor: kLime,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Rescheduling Session...',
                            style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kLime),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.calendar_tick, size: 18, color: kLime),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Reschedule',
                            style: TextStyle(fontFamily: 'Syne', fontSize: 14, fontWeight: FontWeight.w800, color: kLime),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
