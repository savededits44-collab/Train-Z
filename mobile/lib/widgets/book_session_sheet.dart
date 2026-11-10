import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../services/booking_service.dart';
import '../services/trainer_profile_service.dart';
import '../shared/models/user_model.dart';
import 'app_widgets.dart';

/// Interactive modal sheet allowing clients to book a training session.
class BookSessionSheet extends StatefulWidget {
  final String? preferredTrainerName;
  final String? preferredGym;
  final String? trainerId;
  final Gender clientGender;
  final Gender trainerGender;

  const BookSessionSheet({
    super.key,
    this.preferredTrainerName,
    this.preferredGym,
    this.trainerId,
    this.clientGender = Gender.male,
    this.trainerGender = Gender.male,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? trainerName,
    String? gymName,
    String? trainerId,
    Gender clientGender = Gender.male,
    Gender trainerGender = Gender.male,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BookSessionSheet(
        preferredTrainerName: trainerName,
        preferredGym: gymName,
        trainerId: trainerId,
        clientGender: clientGender,
        trainerGender: trainerGender,
      ),
    );
  }

  @override
  State<BookSessionSheet> createState() => _BookSessionSheetState();
}

class _BookSessionSheetState extends State<BookSessionSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  int _selectedDateOffset = 0; // 0 = Today, 1 = Tomorrow, 2 = Day after
  int _selectedSlotIndex = 1; // "07:00 AM - 08:00 AM"
  int _selectedWorkoutIndex = 0;
  bool _submitting = false;

  final List<String> _timeSlots = [
    '06:00 AM - 07:00 AM',
    '07:00 AM - 08:00 AM',
    '08:30 AM - 09:30 AM',
    '10:00 AM - 11:00 AM',
    '05:00 PM - 06:00 PM',
    '06:30 PM - 07:30 PM',
    '08:00 PM - 09:00 PM',
  ];

  final List<String> _workoutTypes = [
    'Strength & Hypertrophy',
    'Fat Loss & HIIT',
    'Endurance & Cardio',
    'Athletic Conditioning',
    'Mobility & Flexibility',
  ];

  @override
  void initState() {
    super.initState();
    final trainerService = TrainerProfileService.instance;
    final defaultGym = widget.preferredGym ?? trainerService.gymName ?? "Gold's Gym Bandra";

    _nameController = TextEditingController(text: 'Rohan Sharma');
    _phoneController = TextEditingController(text: '+91 98201 54321');
    _locationController = TextEditingController(text: defaultGym);
    _notesController = TextEditingController(
      text: 'Focusing on upper body strength & proper bench/deadlift form.',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleBook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final sessionDate = now.add(Duration(days: _selectedDateOffset));
    final slot = _timeSlots[_selectedSlotIndex];
    final parts = slot.split(' - ');
    final startTime = parts[0];
    final endTime = parts.length > 1 ? parts[1] : '';

    try {
      await BookingService.instance.createBookingRequest(
        trainerId: widget.trainerId,
        clientGender: widget.clientGender,
        trainerGender: widget.trainerGender,
        clientName: _nameController.text,
        clientPhone: _phoneController.text,
        sessionDate: sessionDate,
        startTime: startTime,
        endTime: endTime,
        workoutType: _workoutTypes[_selectedWorkoutIndex],
        meetingLocation: _locationController.text,
        notes: _notesController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Booking sent! It is now live in the Trainer session requests.',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF111111),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to book session: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final h = MediaQuery.of(context).size.height;

    final trainerName = widget.preferredTrainerName ??
        TrainerProfileService.instance.fullName ??
        'Coach Marcus';

    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.9),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
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

                // Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Book a Session',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (20.0 * sf).clamp(18.0, 24.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trainerName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your session request will instantly show on the trainer\'s live dashboard.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(10.5, 13.0),
                    color: kGrey,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Client Info Inputs ──
                Text(
                  'Your Name & Mobile',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Iconsax.user,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: _phoneController,
                        label: 'Mobile No',
                        icon: Iconsax.call,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Date Selector (Today, Tomorrow, Day 3) ──
                Text(
                  'Select Day',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(3, (i) {
                    final selected = _selectedDateOffset == i;
                    final target = DateTime.now().add(Duration(days: i));
                    final dayLabel = i == 0
                        ? 'Today'
                        : i == 1
                            ? 'Tomorrow'
                            : '${target.day}/${target.month}';

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 8.0 : 0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedDateOffset = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? kDark : kField,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? kDark : kBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  dayLabel,
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : kDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nov ${target.day}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10.5,
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : kGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // ── Time Slot ──
                Text(
                  'Select Time Slot',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_timeSlots.length, (i) {
                    final selected = _selectedSlotIndex == i;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selectedSlotIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? kDark : kField,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? kDark : kBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.clock,
                              size: 13,
                              color: selected ? kLime : kDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _timeSlots[i],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected ? Colors.white : kDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // ── Workout Focus ──
                Text(
                  'Workout Focus',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_workoutTypes.length, (i) {
                    final selected = _selectedWorkoutIndex == i;
                    return ChoiceChip(
                      label: Text(_workoutTypes[i]),
                      selected: selected,
                      selectedColor: kDark,
                      backgroundColor: kField,
                      labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: selected ? Colors.white : kDark,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      checkmarkColor: kLime,
                      onSelected: (val) {
                        if (val) setState(() => _selectedWorkoutIndex = i);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide.none,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // ── Meeting Gym Location ──
                Text(
                  'Training Location / Gym',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _locationController,
                  label: 'Gym or Studio address',
                  icon: Iconsax.building,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter location' : null,
                ),

                const SizedBox(height: 16),

                // ── Notes ──
                Text(
                  'Notes / Injuries / Specific Goals',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _notesController,
                  label: 'e.g. Focus on deadlifts, bad lower back, etc.',
                  icon: Iconsax.edit_2,
                ),

                const SizedBox(height: 24),

                // Submit Button
                AppPrimaryButton(
                  label: 'Request Session (Instant Live Broadcast)',
                  loading: _submitting,
                  onTap: _handleBook,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

