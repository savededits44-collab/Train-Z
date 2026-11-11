import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../services/booking_service.dart';
import '../services/trainer_profile_service.dart';
import '../shared/models/booking_model.dart';
import 'app_widgets.dart';
import 'trainer_animations.dart';

/// Card component displaying live session booking details with real-time Accept/Reject controls.
class TrainerSessionCard extends StatefulWidget {
  final BookingModel booking;
  final double sf;
  final bool compact;

  const TrainerSessionCard({
    super.key,
    required this.booking,
    required this.sf,
    this.compact = false,
  });

  @override
  State<TrainerSessionCard> createState() => _TrainerSessionCardState();
}

class _TrainerSessionCardState extends State<TrainerSessionCard> {
  bool _loading = false;

  Future<void> _handleAccept() async {
    final trainerProfile = TrainerProfileService.instance;
    if (!trainerProfile.isApproved) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Application under review: You will be eligible to accept sessions once approved by Admin.',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.heavyImpact();

    await BookingService.instance.acceptBooking(widget.booking.id);

    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Session with ${widget.booking.displayClientName} accepted!',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Reject Session Request?',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (18.0 * widget.sf).clamp(16.0, 20.0),
              fontWeight: FontWeight.w700,
              color: kDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reject the session request from ${widget.booking.displayClientName}?',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kGrey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Reason (e.g. Schedule full, out of town)',
                  hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
                  filled: true,
                  fillColor: kField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Poppins', color: kGrey, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                HapticFeedback.mediumImpact();
                await BookingService.instance.rejectBooking(
                  widget.booking.id,
                  reason: reasonController.text,
                );
                if (mounted) setState(() => _loading = false);
              },
              child: const Text(
                'Reject Request',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRescheduleDialog() {
    DateTime selectedDate = widget.booking.sessionDate.add(const Duration(days: 1));
    String selectedTime = widget.booking.startTime;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reschedule Session',
                      style: TextStyle(fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.w800, color: kDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select new date and time for ${widget.booking.displayClientName}.',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: kGrey),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: kField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.calendar_1, size: 18, color: kDark),
                                const SizedBox(width: 10),
                                Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: kDark),
                                ),
                              ],
                            ),
                            const Text('Change Date', style: TextStyle(fontFamily: 'Syne', fontSize: 12, fontWeight: FontWeight.w700, color: kDark)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Select Time Slot', style: TextStyle(fontFamily: 'Syne', fontSize: 13, fontWeight: FontWeight.w700, color: kDark)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['06:00', '07:00', '08:00', '09:00', '10:00', '16:00', '17:00', '18:00', '19:00', '20:00'].map((time) {
                        final isSel = selectedTime == time;
                        return ChoiceChip(
                          label: Text(time),
                          selected: isSel,
                          onSelected: (_) => setSheetState(() => selectedTime = time),
                          selectedColor: kLime,
                          backgroundColor: kField,
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: kDark,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        hintText: 'Reason for rescheduling (optional)',
                        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
                        filled: true,
                        fillColor: kField,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() => _loading = true);
                          HapticFeedback.mediumImpact();
                          final endHour = (int.parse(selectedTime.split(':')[0]) + 1).toString().padLeft(2, '0');
                          final endTime = '$endHour:00';
                          await BookingService.instance.rescheduleBooking(
                            bookingId: widget.booking.id,
                            newDate: selectedDate,
                            newStartTime: selectedTime,
                            newEndTime: endTime,
                            reason: reasonController.text.trim(),
                          );
                          if (mounted) setState(() => _loading = false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Reschedule', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kLime)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCancelDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Cancel Session?', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to cancel the session with ${widget.booking.displayClientName}?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Reason for cancellation',
                  filled: true,
                  fillColor: kField,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Session', style: TextStyle(fontFamily: 'Poppins', color: kGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                HapticFeedback.mediumImpact();
                await BookingService.instance.cancelBooking(
                  bookingId: widget.booking.id,
                  isTrainer: true,
                  reason: reasonController.text.trim(),
                );
                if (mounted) setState(() => _loading = false);
              },
              child: const Text('Cancel Session', style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final sf = widget.sf;
    final isPending = b.status == BookingStatus.pending || b.status == BookingStatus.reserved;
    final isConfirmed = b.status == BookingStatus.confirmed;
    final isRescheduled = b.status == BookingStatus.rescheduled;
    final isCompleted = b.status == BookingStatus.completed;
    final isCancelled = b.isCancelled;
    final isRejected = b.status == BookingStatus.rejected;

    return TrainerBreathingGlow(
      active: isPending,
      glowColor: const Color(0xFFFFB300),
      borderRadius: (16.0 * sf).clamp(12.0, 18.0),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all((16.0 * sf).clamp(12.0, 20.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular((16.0 * sf).clamp(12, 18)),
          border: Border.all(
            color: isPending
                ? const Color(0xFFFFB300)
                : (isConfirmed || isRescheduled ? kLime.withValues(alpha: 0.6) : kBorder),
            width: isPending ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Client Name + Live Status Pill ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: (42.0 * sf).clamp(34, 48),
                height: (42.0 * sf).clamp(34, 48),
                decoration: BoxDecoration(
                  color: isPending ? const Color(0xFFFFF8E1) : kField,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.user,
                  color: isPending ? const Color(0xFFFF8F00) : kDark,
                  size: (20.0 * sf).clamp(16, 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.displayClientName,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (15.0 * sf).clamp(13.0, 17.0),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    if (b.clientPhone != null && b.clientPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Iconsax.call, size: 12, color: kGrey),
                          const SizedBox(width: 4),
                          Text(
                            b.clientPhone!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(9.5, 12.0),
                              color: kGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFFF3E0)
                      : (isRescheduled
                          ? const Color(0xFFEDE9FE)
                          : (isConfirmed
                              ? const Color(0xFFE8F5E9)
                              : (isCompleted
                                  ? const Color(0xFFF0FDF4)
                                  : (isCancelled
                                      ? const Color(0xFFF3F4F6)
                                      : const Color(0xFFFFEBEE))))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPending) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9800),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isPending
                          ? 'Live Request'
                          : (isRescheduled
                              ? 'Rescheduled'
                              : (isConfirmed
                                  ? 'Confirmed'
                                  : (isCompleted
                                      ? 'Completed'
                                      : (isCancelled ? 'Cancelled' : 'Rejected')))),
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPending
                            ? const Color(0xFFE65100)
                            : (isRescheduled
                                ? const Color(0xFF7C3AED)
                                : (isConfirmed
                                    ? const Color(0xFF2E7D32)
                                    : (isCompleted
                                        ? const Color(0xFF15803D)
                                        : (isCancelled
                                            ? const Color(0xFF6B7280)
                                            : const Color(0xFFC62828))))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Session Time & Date ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kField,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.clock, size: 16, color: kDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${b.startTime} - ${b.endTime}  •  ${_formatDate(b.sessionDate)}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (12.0 * sf).clamp(10.5, 13.0),
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Workout Focus & Gym Location ──
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Iconsax.weight, size: 14, color: kGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.displayWorkoutType,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.5 * sf).clamp(10.0, 12.5),
                          fontWeight: FontWeight.w500,
                          color: kDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (b.meetingLocation != null && b.meetingLocation!.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Iconsax.building, size: 14, color: kGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.meetingLocation!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.0, 12.5),
                            color: kGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (b.notes != null && b.notes!.isNotEmpty && !widget.compact) ...[
            const SizedBox(height: 10),
            Text(
              'Athlete Note: "${b.notes}"',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.0 * sf).clamp(9.5, 12.0),
                fontStyle: FontStyle.italic,
                color: kGrey,
              ),
            ),
          ],

          // ── Live Action Buttons (Accept / Reject) ──
          if (isPending) ...[
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kDark),
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Reject Button with spring-scale
                  Expanded(
                    flex: 4,
                    child: TrainerPressScale(
                      onTap: _showRejectDialog,
                      child: OutlinedButton.icon(
                        onPressed: _showRejectDialog,
                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935)),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: Color(0xFFE53935),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFFCDD2)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Accept Button with shimmer sweep & spring-scale
                  Expanded(
                    flex: 6,
                    child: TrainerPressScale(
                      onTap: _handleAccept,
                      child: TrainerShimmerSweep(
                        period: const Duration(milliseconds: 2400),
                        child: ElevatedButton.icon(
                          onPressed: _handleAccept,
                          icon: const Icon(Icons.check_rounded, size: 18, color: kDark),
                          label: const Text(
                            'Accept Session',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: kDark,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLime,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ] else if (isConfirmed || isRescheduled) ...[
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kDark),
                  ),
                ),
              )
            else ...[
              // Action buttons: Reschedule, Cancel, Complete
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showRescheduleDialog,
                      icon: const Icon(Iconsax.calendar_edit, size: 13, color: kDark),
                      label: const Text(
                        'Reschedule',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 11, fontWeight: FontWeight.w700, color: kDark),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCancelDialog,
                      icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _loading = true);
                        HapticFeedback.heavyImpact();
                        await BookingService.instance.markSessionCompleted(b.id);
                        if (mounted) setState(() => _loading = false);
                      },
                      icon: const Icon(Icons.check_rounded, size: 14, color: kDark),
                      label: const Text(
                        'Complete',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 11, fontWeight: FontWeight.w700, color: kDark),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLime,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workout session completed & recorded.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCancelled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF6B7280), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This session was cancelled.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isRejected) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session request was rejected.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC62828),
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
  );
}

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) {
      return 'Tomorrow';
    }
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }
}
