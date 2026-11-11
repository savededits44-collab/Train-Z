import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../services/booking_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/location_service.dart';
import '../../../../shared/models/trainer_availability_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_booking_confirmation_screen.dart';

/// Screen allowing clients to select preferred date, 60-min time slot,
/// training location with service-area validation, view live booking summary,
/// and trigger atomic temporary slot reservation with double-booking protection.
class ClientBookingScheduleScreen extends StatefulWidget {
  final TrainerDisplayModel trainer;
  final TrainingPlanModel plan;
  final Gender clientGender;
  final String clientId;

  const ClientBookingScheduleScreen({
    super.key,
    required this.trainer,
    required this.plan,
    required this.clientGender,
    required this.clientId,
  });

  @override
  State<ClientBookingScheduleScreen> createState() => _ClientBookingScheduleScreenState();
}

class _ClientBookingScheduleScreenState extends State<ClientBookingScheduleScreen> {
  final _firestoreService = FirestoreService();

  late DateTime _selectedDate;
  String? _selectedStartTime;
  String? _selectedEndTime;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default to tomorrow for first training session
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedStartTime = '07:00 AM';
    _selectedEndTime = '08:00 AM';

    // Default location to trainer's gym or service area
    final defaultLocation = (widget.trainer.gymName != null && widget.trainer.gymName!.isNotEmpty)
        ? widget.trainer.gymName!
        : (widget.trainer.serviceArea ?? 'Personal Training Studio');
    _locationController = TextEditingController(text: defaultLocation);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Max booking eligibility date derived from package validity
  DateTime get maxEligibleDate {
    final days = widget.plan.validityDays > 0 ? widget.plan.validityDays : 30;
    return DateTime.now().add(Duration(days: days));
  }

  /// Whether client's entered location is in trainer's service area
  bool get _isLocationValid {
    final text = _locationController.text.trim();
    if (text.isEmpty) return false;
    return FirestoreService.isAddressInTrainerServiceArea(
      clientAddress: text,
      trainerServiceArea: widget.trainer.serviceArea ?? '',
      trainerCity: widget.trainer.cityId,
    );
  }

  Future<void> _handleProceedToCheckout() async {
    // Inactive city guard (Requirement 6)
    if (widget.trainer.cityId != null && !LocationService.instance.isCityActive(widget.trainer.cityId)) {
      setState(() => _errorMessage = 'Bookings are not currently active in ${LocationService.instance.getCityName(widget.trainer.cityId)}. Bookings in this area will open soon.');
      return;
    }

    if (_selectedStartTime == null || _selectedEndTime == null) {
      setState(() => _errorMessage = 'Please select an available 60-minute time slot.');
      return;
    }

    final locationText = _locationController.text.trim();
    if (locationText.isEmpty) {
      setState(() => _errorMessage = 'Please enter your training location address.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final athleteName = currentUser?.displayName?.isNotEmpty == true
          ? currentUser!.displayName!
          : 'Active Athlete';
      final athletePhone = currentUser?.phoneNumber;

      // 1. Double-booking check & atomic reservation in Firestore
      final reservedBooking = await _firestoreService.reserveBookingSlot(
        clientId: widget.clientId,
        trainerId: widget.trainer.uid,
        packageId: widget.plan.id,
        sessionDate: _selectedDate,
        startTime: _selectedStartTime!,
        endTime: _selectedEndTime!,
        trainingLocation: locationText,
        notes: _notesController.text.trim(),
        clientName: athleteName,
        clientPhone: athletePhone,
        clientGender: widget.clientGender,
        trainerGender: widget.trainer.gender,
      );

      // Immediately sync with BookingService in-memory stream for 0ms trainer reflection
      BookingService.instance.addOrUpdateBooking(reservedBooking);

      if (!mounted) return;

      // 2. Navigate to Booking Confirmation & Payment Preparation Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientBookingConfirmationScreen(
            booking: reservedBooking,
            trainer: widget.trainer,
            plan: widget.plan,
          ),
        ),
      );
    } on BookingConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _selectedStartTime = null; // Reset selection so user picks another
      });
      _showCollisionDialog(e.message);
    } on GenderMismatchException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Unable to reserve slot: $e';
      });
    }
  }

  void _showCollisionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.danger, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Slot Unavailable',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF444444), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Choose Another Slot', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Schedule Booking',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 21.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. BOOKING DETAILS: TRAINER & PACKAGE BANNER ──
            _buildTrainerPackageBanner(sf),
            const SizedBox(height: 20),

            // ── 2. DATE SELECTION CALENDAR ──
            _buildDateSelectionSection(sf),
            const SizedBox(height: 20),

            // ── 3. TIME SLOT SELECTION (60-MIN SLOTS FROM FIREBASE) ──
            _buildTimeSlotSelectionSection(sf),
            const SizedBox(height: 20),

            // ── 4. TRAINING LOCATION & SERVICE AREA CHECK ──
            _buildTrainingLocationSection(sf),
            const SizedBox(height: 20),

            // ── 5. BOOKING SUMMARY SECTION ──
            _buildBookingSummaryCard(sf),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w500,
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
      // ── BOTTOM ACTION BAR ──
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PAYABLE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (10.0 * sf).clamp(9.0, 11.0),
                        fontWeight: FontWeight.w600,
                        color: kGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '₹${widget.plan.price}',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (22.0 * sf).clamp(19.0, 25.0),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleProceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    foregroundColor: kLime,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: kLime),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Reserve & Proceed',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (14.5 * sf).clamp(13.0, 16.5),
                                fontWeight: FontWeight.w800,
                                color: kLime,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 16, color: kLime),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Trainer & Package Details Card ──
  Widget _buildTrainerPackageBanner(double sf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trainer Row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFFF3F4F6),
                  child: (widget.trainer.photoUrl != null && widget.trainer.photoUrl!.isNotEmpty)
                      ? Image.network(
                          widget.trainer.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Iconsax.user, color: kDark, size: 28),
                        )
                      : const Icon(Iconsax.user, color: kDark, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.trainer.displayName,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (15.5 * sf).clamp(14.0, 17.5),
                              fontWeight: FontWeight.w800,
                              color: kDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (widget.trainer.gymName != null && widget.trainer.gymName!.isNotEmpty)
                          ? widget.trainer.gymName!
                          : (widget.trainer.serviceArea ?? 'Service Area'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.0 * sf).clamp(10.0, 12.5),
                        color: kGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.trainer.ratingText} (${widget.trainer.totalReviews} reviews)',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: kDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          // Package Snapshot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.plan.title,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.5 * sf).clamp(13.0, 16.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  Text(
                    '${widget.plan.sessionsCount} Sessions • ${widget.plan.validityDays} Days Validity',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '₹${widget.plan.price}',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (15.0 * sf).clamp(13.5, 17.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Interactive Date Selection Calendar ──
  Widget _buildDateSelectionSection(double sf) {
    final now = DateTime.now();
    // Build next 14 eligible days
    final daysCount = widget.plan.validityDays.clamp(1, 14);
    final eligibleDates = List.generate(daysCount, (index) => now.add(Duration(days: index + 1)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Training Date',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (15.0 * sf).clamp(13.5, 17.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            Text(
              'Validity: ${widget.plan.validityDays}d',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: eligibleDates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final date = eligibleDates[index];
              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDate = date;
                    _errorMessage = null;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? kDark : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? kDark : const Color(0xFFE5E5E5),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kDark.withValues(alpha: 0.15),
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
                        _getShortDay(date.weekday),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? kLime : kGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : kDark,
                        ),
                      ),
                      Text(
                        _getShortMonth(date.month),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          color: isSelected ? const Color(0xFFDDDDDD) : kGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 3. 60-Minute Time Slot Selection from Firebase ──
  Widget _buildTimeSlotSelectionSection(double sf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Time Slot (60 Mins)',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (15.0 * sf).clamp(13.5, 17.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            const Row(
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text('Live Availability', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<TimeSlot>>(
          stream: _firestoreService.streamSlotsForTrainerDate(
            trainerId: widget.trainer.uid,
            date: _selectedDate,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2, color: kDark),
                ),
              );
            }

            final slots = snapshot.data ?? [
              const TimeSlot(start: '06:00 AM', end: '07:00 AM', isBooked: false),
              const TimeSlot(start: '07:00 AM', end: '08:00 AM', isBooked: false),
              const TimeSlot(start: '08:30 AM', end: '09:30 AM', isBooked: false),
              const TimeSlot(start: '10:00 AM', end: '11:00 AM', isBooked: false),
              const TimeSlot(start: '11:30 AM', end: '12:30 PM', isBooked: false),
              const TimeSlot(start: '05:00 PM', end: '06:00 PM', isBooked: false),
              const TimeSlot(start: '06:30 PM', end: '07:30 PM', isBooked: false),
              const TimeSlot(start: '08:00 PM', end: '09:00 PM', isBooked: false),
            ];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final isBooked = slot.isBooked;
                final isSelected = !isBooked && _selectedStartTime == slot.start;

                return InkWell(
                  onTap: isBooked
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedStartTime = slot.start;
                            _selectedEndTime = slot.end;
                            _errorMessage = null;
                          });
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? const Color(0xFFF3F4F6)
                          : isSelected
                              ? const Color(0xFFF4F9F2)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBooked
                            ? const Color(0xFFE5E7EB)
                            : isSelected
                                ? kLime
                                : const Color(0xFFE5E5E5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.start,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (12.5 * sf).clamp(11.5, 14.0),
                                fontWeight: FontWeight.w700,
                                color: isBooked ? const Color(0xFF9CA3AF) : kDark,
                              ),
                            ),
                            Text(
                              isBooked ? 'Reserved / Booked' : '60 min session',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9.5,
                                color: isBooked ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A))
                        else if (isBooked)
                          const Icon(Icons.lock_outline, size: 14, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── 4. Training Location & Service Area Check ──
  Widget _buildTrainingLocationSection(double sf) {
    final isValid = _isLocationValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Training Location',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (15.0 * sf).clamp(13.5, 17.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Trainer Service Area: ${widget.trainer.serviceArea}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (11.0 * sf).clamp(10.0, 12.0),
            color: kGrey,
          ),
        ),
        const SizedBox(height: 8),

        // Text input for location address
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isValid ? const Color(0xFF16A34A) : const Color(0xFFE5E5E5),
              width: isValid ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _locationController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
            decoration: InputDecoration(
              prefixIcon: const Icon(Iconsax.location, color: kDark, size: 20),
              suffixIcon: isValid
                  ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                  : null,
              hintText: 'Enter gym or residential clubhouse address',
              hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Privacy Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Iconsax.shield_tick, size: 14, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Address is encrypted & revealed only to your confirmed trainer.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 5. Booking Summary Breakdown ──
  Widget _buildBookingSummaryCard(double sf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.receipt_2, size: 16, color: kDark),
              const SizedBox(width: 8),
              Text(
                'BOOKING SUMMARY',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryLine('Trainer', widget.trainer.displayName),
          _buildSummaryLine('Package', '${widget.plan.title} (${widget.plan.sessionsCount} Sessions)'),
          _buildSummaryLine('Session Duration', '60 Minutes'),
          _buildSummaryLine('Scheduled Date', '${_selectedDate.day} ${_getShortMonth(_selectedDate.month)} ${_selectedDate.year}'),
          _buildSummaryLine('Time Slot', '$_selectedStartTime - $_selectedEndTime'),
          _buildSummaryLine('Location', _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : 'Unspecified'),
          const Divider(height: 18, color: Color(0xFFF0F0F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Package Price', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: kDark)),
              Text('₹${widget.plan.price}', style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 15, color: kDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: kDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getShortDay(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }

  String _getShortMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }
}
