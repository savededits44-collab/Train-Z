import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../services/booking_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/location_service.dart';
import '../../../../shared/models/gym_model.dart';
import '../../../../shared/models/trainer_availability_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_booking_confirmation_screen.dart';

/// Supported training location modes
enum TrainingLocationMode {
  home,
  gym,
  other,
}

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
  late TextEditingController _notesController;

  // Commercial Gym Selection State
  late List<GymModel> _partnerGyms;
  GymModel? _selectedGym;
  late TextEditingController _gymNameController;
  late TextEditingController _gymAddressController;
  late TextEditingController _gymMapsUrlController;
  double? _gymLat;
  double? _gymLng;
  bool _isCustomGym = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default to tomorrow or first working day
    final now = DateTime.now();
    DateTime initial = now.add(const Duration(days: 1));
    if (!_isTrainerWorkingOnDate(initial)) {
      for (int i = 1; i <= 7; i++) {
        final candidate = now.add(Duration(days: i));
        if (_isTrainerWorkingOnDate(candidate)) {
          initial = candidate;
          break;
        }
      }
    }
    _selectedDate = initial;
    _selectedStartTime = '07:00 AM';
    _selectedEndTime = '08:00 AM';
    _notesController = TextEditingController();

    // Curated commercial partner gyms for trainer's city
    final gyms = LocationService.instance.getCommercialGymsForCity(widget.trainer.cityId);
    final baseGyms = gyms.isNotEmpty ? List<GymModel>.from(gyms) : List<GymModel>.from(LocationService.curatedPartnerGyms);
    if (widget.trainer.gymName != null && widget.trainer.gymName!.trim().isNotEmpty) {
      final tGymName = widget.trainer.gymName!.trim();
      if (!baseGyms.any((g) => g.name.toLowerCase() == tGymName.toLowerCase())) {
        baseGyms.insert(
          0,
          GymModel(
            id: 'gym_trainer_primary',
            name: tGymName,
            address: widget.trainer.profile.primaryGymAddress ?? '$tGymName Commercial Facility, Pune',
            city: widget.trainer.cityId ?? 'Pune',
            latitude: widget.trainer.effectiveLat ?? 18.5204,
            longitude: widget.trainer.effectiveLng ?? 73.8567,
            mapsUrl: 'https://maps.google.com/?q=${widget.trainer.effectiveLat ?? 18.5204},${widget.trainer.effectiveLng ?? 73.8567}',
            partnershipStatus: GymPartnershipStatus.active,
          ),
        );
      }
    }
    _partnerGyms = baseGyms;
    _selectedGym = _partnerGyms.isNotEmpty ? _partnerGyms.first : null;

    _gymNameController = TextEditingController(
      text: _selectedGym?.name ?? widget.trainer.gymName ?? 'Gold\'s Gym Kalyani Nagar',
    );
    _gymAddressController = TextEditingController(
      text: _selectedGym?.address ?? 'Kalyani Nagar, Pune, Maharashtra 411006',
    );
    _gymMapsUrlController = TextEditingController(
      text: _selectedGym?.mapsUrl ?? 'https://maps.google.com/?q=18.5463,73.9033',
    );
    _gymLat = _selectedGym?.latitude ?? 18.5463;
    _gymLng = _selectedGym?.longitude ?? 73.9033;
  }

  @override
  void dispose() {
    _gymNameController.dispose();
    _gymAddressController.dispose();
    _gymMapsUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Accurate distance in km between trainer active location and selected gym using Haversine formula
  double? get calculatedTravelDistanceKm {
    final gLat = _gymLat ?? _selectedGym?.latitude;
    final gLng = _gymLng ?? _selectedGym?.longitude;
    final tLat = widget.trainer.effectiveLat;
    final tLng = widget.trainer.effectiveLng;
    if (gLat == null || gLng == null || tLat == null || tLng == null) return null;
    return calculateHaversineDistanceKm(tLat, tLng, gLat, gLng);
  }

  /// Whether selected gym is within trainer's travel radius
  bool get isWithinTravelRadius {
    final dist = calculatedTravelDistanceKm;
    if (dist == null) return true;
    return dist <= widget.trainer.travelRadiusKm;
  }

  /// Select a partner gym
  void _selectPartnerGym(GymModel gym) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGym = gym;
      _isCustomGym = false;
      _gymNameController.text = gym.name;
      _gymAddressController.text = gym.address;
      _gymMapsUrlController.text = gym.mapsUrl ?? 'https://maps.google.com/?q=${gym.latitude},${gym.longitude}';
      _gymLat = gym.latitude;
      _gymLng = gym.longitude;
      _errorMessage = null;
    });
  }

  /// Switch to custom commercial gym entry
  void _enableCustomGym() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGym = null;
      _isCustomGym = true;
      _gymNameController.clear();
      _gymAddressController.clear();
      _gymMapsUrlController.clear();
      _gymLat = widget.trainer.effectiveLat;
      _gymLng = widget.trainer.effectiveLng;
      _errorMessage = null;
    });
  }

  /// Min booking date (today)
  DateTime get _minDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Max booking eligibility date derived from package validity
  DateTime get maxEligibleDate {
    final days = widget.plan.validityDays > 0 ? widget.plan.validityDays : 30;
    return _minDate.add(Duration(days: days));
  }

  /// Checks if trainer is working on the given date based on workingDays profile configuration
  bool _isTrainerWorkingOnDate(DateTime date) {
    if (widget.trainer.profile.workingDays.isEmpty) return true;
    final shortDay = _getShortDay(date.weekday).toUpperCase();
    return widget.trainer.profile.workingDays.any((d) {
      final clean = d.trim().toUpperCase();
      return clean.startsWith(shortDay) || shortDay.startsWith(clean);
    });
  }

  /// Opens full monthly interactive calendar picker
  Future<void> _openCalendarPicker() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(_minDate)
          ? _minDate
          : (_selectedDate.isAfter(maxEligibleDate) ? maxEligibleDate : _selectedDate),
      firstDate: _minDate,
      lastDate: maxEligibleDate,
      selectableDayPredicate: (date) {
        // Enforce trainer working days and package validity
        return _isTrainerWorkingOnDate(date);
      },
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
      setState(() {
        _selectedDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleProceedToCheckout() async {
    if (_isSubmitting) return;

    // 1. Inactive city guard
    if (widget.trainer.cityId != null && !LocationService.instance.isCityActive(widget.trainer.cityId)) {
      setState(() => _errorMessage =
          'Bookings are not currently active in ${LocationService.instance.getCityName(widget.trainer.cityId)}. Bookings in this area will open soon.');
      return;
    }

    // 2. Professional Trainer policy: Coming soon
    if (widget.trainer.category == TrainerCategory.professionalTrainer) {
      setState(() => _errorMessage =
          'Professional Trainer packages are coming soon and unavailable for booking at launch.');
      return;
    }

    // 3. Time slot selection check
    if (_selectedStartTime == null || _selectedEndTime == null) {
      setState(() => _errorMessage = 'Please select an available 60-minute time slot.');
      return;
    }

    // 4. Gym name and address check
    final gymName = _gymNameController.text.trim();
    final gymAddress = _gymAddressController.text.trim();
    if (gymName.isEmpty || gymAddress.isEmpty) {
      setState(() => _errorMessage = 'Please specify both commercial gym name and complete address.');
      return;
    }

    // 5. Commercial Gym verification: reject residential / outdoor addresses
    if (isProhibitedTrainingLocation(gymName) || isProhibitedTrainingLocation(gymAddress)) {
      setState(() => _errorMessage =
          'All TRAIN Z personal training sessions take place exclusively at commercial gyms. Please select or enter a verified commercial gym facility.');
      return;
    }

    // 6. Travel Radius check
    final dist = calculatedTravelDistanceKm;
    if (dist != null && dist > widget.trainer.travelRadiusKm) {
      setState(() => _errorMessage =
          'Selected gym is ${dist.toStringAsFixed(1)} km away, which exceeds Coach ${widget.trainer.displayName}\'s travel radius of ${widget.trainer.travelRadiusKm.toStringAsFixed(0)} km. Please select a gym closer to the coach.');
      return;
    }

    // 7. Date validity check
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate.isBefore(today)) {
      setState(() => _errorMessage = 'Session date cannot be in the past.');
      return;
    }
    if (_selectedDate.isAfter(maxEligibleDate)) {
      setState(() => _errorMessage =
          'Selected date exceeds package validity of ${widget.plan.validityDays} days.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final currentUser = () {
        try {
          return FirebaseAuth.instance.currentUser;
        } catch (_) {
          return null;
        }
      }();

      final athleteName = currentUser?.displayName?.isNotEmpty == true
          ? currentUser!.displayName!
          : 'TRAIN Z Athlete';
      final athletePhone = currentUser?.phoneNumber;

      final fullLocation = '$gymName, $gymAddress';

      // 1. Create booking request with status PENDING (No charge at this stage)
      final bookingRequest = await BookingService.instance.createBookingRequest(
        clientName: athleteName,
        clientPhone: athletePhone ?? '+919820154321',
        sessionDate: _selectedDate,
        startTime: _selectedStartTime!,
        endTime: _selectedEndTime!,
        workoutType: widget.plan.title,
        meetingLocation: fullLocation,
        gymId: _selectedGym?.id,
        gymName: gymName,
        gymAddress: gymAddress,
        gymLat: _gymLat ?? _selectedGym?.latitude,
        gymLng: _gymLng ?? _selectedGym?.longitude,
        gymMapsUrl: _gymMapsUrlController.text.trim(),
        trainerTravelDistanceKm: dist,
        packageId: widget.plan.id,
        packagePrice: widget.plan.price,
        sessionsCount: widget.plan.sessionsCount,
        validityDays: widget.plan.validityDays,
        notes: _notesController.text.trim(),
        trainerId: widget.trainer.uid,
        clientId: widget.clientId,
        clientGender: widget.clientGender,
        trainerGender: widget.trainer.gender,
      );

      if (!mounted) return;

      // 2. Navigate to Booking Confirmation Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientBookingConfirmationScreen(
            booking: bookingRequest,
            trainer: widget.trainer,
            plan: widget.plan,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Unable to send booking request: $e';
      });
    }
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
          'Schedule Session',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: (18.0 * sf).clamp(16.0, 21.0),
            fontWeight: FontWeight.w600,
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
                          fontFamily: 'Outfit',
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
          border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
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
                        fontFamily: 'Outfit',
                        fontSize: (10.0 * sf).clamp(9.0, 11.0),
                        fontWeight: FontWeight.w600,
                        color: kGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      widget.plan.formattedPrice,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: (22.0 * sf).clamp(19.0, 25.0),
                        fontWeight: FontWeight.w600,
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
                  onPressed: (_isSubmitting || _selectedStartTime == null) ? null : _handleProceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    foregroundColor: kLime,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _selectedStartTime != null ? 'Submit Booking Request' : 'Select a Slot',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: (14.5 * sf).clamp(13.0, 16.5),
                                  fontWeight: FontWeight.w600,
                                  color: _selectedStartTime != null ? kLime : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward,
                                size: 16, color: _selectedStartTime != null ? kLime : const Color(0xFF9CA3AF)),
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
    String categoryLabel;
    Color categoryBg;
    Color categoryText;

    switch (widget.trainer.category) {
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
                  color: const Color(0xFF111111),
                  child: (widget.trainer.photoUrl != null && widget.trainer.photoUrl!.isNotEmpty)
                      ? Image.network(
                          widget.trainer.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Iconsax.user, color: kLime, size: 28),
                        )
                      : Center(
                          child: Text(
                            widget.trainer.displayName.isNotEmpty
                                ? widget.trainer.displayName[0].toUpperCase()
                                : 'T',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: kLime,
                            ),
                          ),
                        ),
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
                              fontFamily: 'Outfit',
                              fontSize: (15.5 * sf).clamp(14.0, 17.5),
                              fontWeight: FontWeight.w600,
                              color: kDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: Color(0xFF16A34A)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: categoryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.trainer.displayLocation,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: (11.0 * sf).clamp(10.0, 12.0),
                              color: kGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      fontFamily: 'Outfit',
                      fontSize: (14.5 * sf).clamp(13.0, 16.0),
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                  Text(
                    '${widget.plan.sessionsCount} Sessions (${widget.plan.sessionDurationMinutes} mins each) • ${widget.plan.validityDays}d Validity',
                    style: TextStyle(
                      fontFamily: 'Outfit',
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
                  widget.plan.formattedPrice,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: (15.0 * sf).clamp(13.5, 17.0),
                    fontWeight: FontWeight.w600,
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
    // Build days within package validity (max 21 shown horizontally)
    final daysCount = widget.plan.validityDays.clamp(1, 21);
    final eligibleDates = List.generate(daysCount, (index) => now.add(Duration(days: index)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Training Date',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: (15.0 * sf).clamp(13.5, 17.0),
                fontWeight: FontWeight.w600,
                color: kDark,
              ),
            ),
            InkWell(
              onTap: _openCalendarPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar_1, size: 15, color: kDark),
                    const SizedBox(width: 4),
                    Text(
                      'Calendar',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: eligibleDates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final date = eligibleDates[index];
              final isTrainerWorking = _isTrainerWorkingOnDate(date);
              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;

              return InkWell(
                onTap: isTrainerWorking
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDate = date;
                          _errorMessage = null;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !isTrainerWorking
                        ? const Color(0xFFF3F4F6)
                        : isSelected
                            ? kDark
                            : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? kDark
                          : !isTrainerWorking
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFFE5E5E5),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: (isSelected && isTrainerWorking)
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
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: !isTrainerWorking
                              ? const Color(0xFF9CA3AF)
                              : isSelected
                                  ? kLime
                                  : kGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: !isTrainerWorking
                              ? const Color(0xFF9CA3AF)
                              : isSelected
                                  ? Colors.white
                                  : kDark,
                        ),
                      ),
                      Text(
                        isTrainerWorking ? _getShortMonth(date.month) : 'Off',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 9.5,
                          fontWeight: isTrainerWorking ? FontWeight.w500 : FontWeight.w700,
                          color: !isTrainerWorking
                              ? const Color(0xFFDC2626)
                              : isSelected
                                  ? const Color(0xFFDDDDDD)
                                  : kGrey,
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
                fontFamily: 'Outfit',
                fontSize: (15.0 * sf).clamp(13.5, 17.0),
                fontWeight: FontWeight.w600,
                color: kDark,
              ),
            ),
            const Row(
              children: [
                Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text(
                  'Live Availability',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10.5,
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<TimeSlot>>(
          stream: _firestoreService.streamSlotsForTrainerDate(
            trainerId: widget.trainer.uid,
            date: _selectedDate,
            currentClientId: widget.clientId,
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

            final slots = snapshot.data ?? const [
              TimeSlot(start: '06:00 AM', end: '07:00 AM', isBooked: false),
              TimeSlot(start: '07:00 AM', end: '08:00 AM', isBooked: false),
              TimeSlot(start: '08:30 AM', end: '09:30 AM', isBooked: false),
              TimeSlot(start: '10:00 AM', end: '11:00 AM', isBooked: false),
              TimeSlot(start: '11:30 AM', end: '12:30 PM', isBooked: false),
              TimeSlot(start: '05:00 PM', end: '06:00 PM', isBooked: false),
              TimeSlot(start: '06:30 PM', end: '07:30 PM', isBooked: false),
              TimeSlot(start: '08:00 PM', end: '09:00 PM', isBooked: false),
            ];

            if (slots.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: const Center(
                  child: Text(
                    'No available time slots on this date. Please choose another date.',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: kGrey),
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final isAvailable = slot.isAvailable;
                final isSelected = isAvailable && _selectedStartTime == slot.start;

                String statusLabel;
                Color statusColor;
                Color cardBg;
                Color borderColor;

                if (slot.isBooked) {
                  statusLabel = 'Booked';
                  statusColor = const Color(0xFF6B7280);
                  cardBg = const Color(0xFFF3F4F6);
                  borderColor = const Color(0xFFE5E7EB);
                } else if (slot.isReserved) {
                  statusLabel = 'In Checkout Hold';
                  statusColor = const Color(0xFFB45309);
                  cardBg = const Color(0xFFFEF3C7);
                  borderColor = const Color(0xFFFDE68A);
                } else if (slot.isPast) {
                  statusLabel = 'Time Passed';
                  statusColor = const Color(0xFF9CA3AF);
                  cardBg = const Color(0xFFF9FAFB);
                  borderColor = const Color(0xFFEEEEEE);
                } else {
                  statusLabel = 'Available • 60m';
                  statusColor = const Color(0xFF15803D);
                  cardBg = isSelected ? const Color(0xFFF4F9F2) : Colors.white;
                  borderColor = isSelected ? kLime : const Color(0xFFE5E5E5);
                }

                return InkWell(
                  onTap: isAvailable
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedStartTime = slot.start;
                            _selectedEndTime = slot.end;
                            _errorMessage = null;
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
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
                                fontFamily: 'Outfit',
                                fontSize: (12.5 * sf).clamp(11.5, 14.0),
                                fontWeight: FontWeight.w700,
                                color: isAvailable ? kDark : const Color(0xFF6B7280),
                              ),
                            ),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 9.5,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A))
                        else if (slot.isReserved)
                          const Icon(Icons.hourglass_top, size: 14, color: Color(0xFFB45309))
                        else if (slot.isBooked)
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

  // ── 4. Training Location & Commercial Gym Selection ──
  Widget _buildTrainingLocationSection(double sf) {
    final dist = calculatedTravelDistanceKm;
    final maxRadius = widget.trainer.travelRadiusKm;
    final withinRadius = isWithinTravelRadius;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commercial Gym Location',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: (15.0 * sf).clamp(13.5, 17.0),
                fontWeight: FontWeight.w600,
                color: kDark,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, size: 12, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Gym Exclusive',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the commercial gym where you want to train. Coach travels to your gym.',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: (11.0 * sf).clamp(10.0, 12.0),
            color: kGrey,
          ),
        ),
        const SizedBox(height: 12),

        // Quick Selector: Verified Commercial Partner Gyms
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._partnerGyms.map((gym) {
                final isSelected = !_isCustomGym && _selectedGym?.id == gym.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      gym.name,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? kLime : kDark,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _selectPartnerGym(gym),
                    selectedColor: kDark,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? kDark : const Color(0xFFE5E7EB),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    '+ Other Commercial Gym',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      fontWeight: _isCustomGym ? FontWeight.w600 : FontWeight.w500,
                      color: _isCustomGym ? kLime : kDark,
                    ),
                  ),
                  selected: _isCustomGym,
                  onSelected: (_) => _enableCustomGym(),
                  selectedColor: kDark,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _isCustomGym ? kDark : const Color(0xFFE5E7EB),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Gym Name Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: TextField(
            controller: _gymNameController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: kDark),
            decoration: const InputDecoration(
              prefixIcon: Icon(Iconsax.building, color: kDark, size: 20),
              hintText: 'Commercial gym name (e.g. Gold\'s Gym, Cult.fit)',
              hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: kGrey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Gym Complete Address Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: TextField(
            controller: _gymAddressController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: kDark),
            decoration: const InputDecoration(
              prefixIcon: Icon(Iconsax.location, color: kDark, size: 20),
              hintText: 'Complete commercial gym address & area',
              hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: kGrey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Google Maps Link / Pin Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: TextField(
            controller: _gymMapsUrlController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: kDark),
            decoration: const InputDecoration(
              prefixIcon: Icon(Iconsax.map, color: kDark, size: 20),
              hintText: 'Google Maps pin / link (optional for navigation)',
              hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: kGrey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── LIVE TRAVEL DISTANCE & TRAVEL RADIUS INDICATOR ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: withinRadius ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: withinRadius ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    withinRadius ? Iconsax.routing_2 : Iconsax.warning_2,
                    size: 16,
                    color: withinRadius ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      withinRadius
                          ? 'Within Coach Travel Radius (${dist?.toStringAsFixed(1) ?? '...'} km / max ${maxRadius.toStringAsFixed(0)} km)'
                          : 'Exceeds Coach Travel Radius (${dist?.toStringAsFixed(1) ?? '...'} km / max ${maxRadius.toStringAsFixed(0)} km)',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: withinRadius ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                withinRadius
                    ? 'Coach ${widget.trainer.displayName} will travel from ${widget.trainer.effectiveLocationName} to your chosen gym. Travel expenses are included in your package pricing.'
                    : 'The selected gym is beyond Coach ${widget.trainer.displayName}\'s travel radius of ${maxRadius.toStringAsFixed(0)} km from ${widget.trainer.effectiveLocationName}. Please select a gym closer to the coach or pick another coach.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: withinRadius ? const Color(0xFF166534) : const Color(0xFF92400E),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Commercial Gym Policy Callout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All TRAIN Z personal training sessions take place exclusively at verified commercial gym facilities. TRAIN Z establishes commercial arrangements and pays participating gyms for session hosting.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: (10.0 * sf).clamp(9.0, 11.5),
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
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
    final gymName = _gymNameController.text.trim().isNotEmpty
        ? _gymNameController.text.trim()
        : 'Selected Commercial Gym';
    final dist = calculatedTravelDistanceKm;

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
                  fontFamily: 'Outfit',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w600,
                  color: kDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryLine('Trainer', widget.trainer.displayName),
          _buildSummaryLine('Trainer Category', widget.trainer.category == TrainerCategory.advancedTrainer ? 'Advanced Trainer' : 'Personal Trainer'),
          _buildSummaryLine('Selected Package', '${widget.plan.title} (${widget.plan.sessionsCount} Sessions)'),
          _buildSummaryLine('Session Duration', '60 Minutes'),
          _buildSummaryLine('Scheduled Date', '${_selectedDate.day} ${_getShortMonth(_selectedDate.month)} ${_selectedDate.year}'),
          _buildSummaryLine('Time Slot', _selectedStartTime != null ? '$_selectedStartTime - $_selectedEndTime' : 'Pending Selection'),
          _buildSummaryLine('Training Gym', gymName),
          if (dist != null)
            _buildSummaryLine('Coach Travel Distance', '${dist.toStringAsFixed(1)} km (Included)'),
          const Divider(height: 18, color: Color(0xFFF0F0F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Package Price', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: kDark)),
              Text(widget.plan.formattedPrice, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: kDark)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              '• Step 2: Submitting sends a booking request to coach. No charge is made yet.\n• 15-Minute Payment Window: Once coach accepts, your 15-minute checkout hold begins.\n• Travel expenses and gym access are covered. 12-Hour Cancellation Rule applies.',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Color(0xFF78350F), height: 1.4),
            ),
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
          Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: kGrey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 11.5, fontWeight: FontWeight.w600, color: kDark),
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
