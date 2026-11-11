import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/location_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/client_profile_controller.dart';
import 'client_home_screen.dart';

/// Comprehensive Client Profile Setup & Edit Screen for TRAIN Z.
/// Allows clients to configure personal information, upload profile photo,
/// select fitness goals, preferred training venues, and launch city.
class ClientProfileSetupScreen extends StatefulWidget {
  final bool isEditMode;

  const ClientProfileSetupScreen({
    super.key,
    this.isEditMode = false,
  });

  @override
  State<ClientProfileSetupScreen> createState() => _ClientProfileSetupScreenState();
}

class _ClientProfileSetupScreenState extends State<ClientProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ClientProfileController _controller;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyController = TextEditingController();

  DateTime? _dateOfBirth;
  final Set<String> _selectedGoals = {'Build Muscle & Strength'};
  String _selectedLevel = 'Intermediate';
  final Set<String> _selectedTrainingTypes = {'Weightlifting / Gym'};
  final Set<String> _selectedInterests = {'Core Strength'};
  String _selectedCityId = LocationService.instance.currentCityId;
  String _preferredLocation = 'Commercial Gym';

  bool _initialized = false;

  // Preset options
  final List<String> _goalOptions = [
    'Build Muscle & Strength',
    'Fat Loss & Body Recomp',
    'Cardio & Stamina',
    'Functional Mobility',
    'Athletic Performance',
  ];

  final List<Map<String, String>> _levelOptions = [
    {'title': 'Beginner', 'desc': '< 1 year'},
    {'title': 'Intermediate', 'desc': '1 - 3 years'},
    {'title': 'Advanced', 'desc': '3+ years'},
  ];

  final List<String> _trainingTypeOptions = [
    'Weightlifting / Gym',
    'HIIT / Functional',
    'Calisthenics / Bodyweight',
    'Boxing / Martial Arts',
    'Yoga & Mobility',
  ];

  final List<String> _interestOptions = [
    'Core Strength',
    'Posture Correction',
    'Nutrition Guidance',
    'Injury Rehabilitation',
    'Competition Prep',
    'Flexibility & Recovery',
  ];

  final List<String> _locationOptions = [
    'Commercial Gym',
    'Personal Gym / Home',
    'Outdoor Park / Society',
    "Trainer's Private Studio",
  ];

  @override
  void initState() {
    super.initState();
    _controller = ClientProfileController();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    // Populate initial values once loaded
    if (!_initialized && _controller.user != null) {
      _initialized = true;
      final u = _controller.user!;
      final p = _controller.profile;

      _nameController.text = u.displayName ?? '';
      _phoneController.text = u.phoneNumber ?? '';

      if (p != null) {
        _dateOfBirth = p.dateOfBirth;
        if (p.fitnessGoals.isNotEmpty) {
          _selectedGoals
            ..clear()
            ..addAll(p.fitnessGoals);
        }
        if (p.fitnessLevel != null) {
          _selectedLevel = p.fitnessLevel!;
        }
        if (p.preferredTrainingTypes.isNotEmpty) {
          _selectedTrainingTypes
            ..clear()
            ..addAll(p.preferredTrainingTypes);
        }
        if (p.fitnessInterests.isNotEmpty) {
          _selectedInterests
            ..clear()
            ..addAll(p.fitnessInterests);
        }
        if (p.preferredCityId != null && LocationService.instance.isCityActive(p.preferredCityId)) {
          _selectedCityId = p.preferredCityId!;
        } else {
          _selectedCityId = LocationService.instance.currentCityId;
        }
        if (p.preferredTrainingLocation != null) {
          _preferredLocation = p.preferredTrainingLocation!;
        }
        _addressController.text = p.privateAddress ?? '';
        _emergencyController.text = p.emergencyContact ?? '';
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).maybePop();
    await _controller.pickProfileImage(source);
  }

  void _showImagePickerSheet() {
    final sf = scaleFactor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (20.0 * sf).clamp(16.0, 24.0),
              vertical: (20.0 * sf).clamp(16.0, 24.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Select Profile Picture',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (16.0 * sf).clamp(14.0, 18.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Iconsax.camera, color: kDark),
                  title: const Text('Take a photo (Camera)', style: TextStyle(fontFamily: 'Poppins')),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Iconsax.gallery, color: kDark),
                  title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Poppins')),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _dateOfBirth ?? DateTime(now.year - 24, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 12, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kDark,
              onPrimary: Colors.white,
              onSurface: kDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

    final success = await _controller.saveProfile(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      dateOfBirth: _dateOfBirth,
      fitnessGoals: _selectedGoals.toList(),
      fitnessLevel: _selectedLevel,
      preferredTrainingTypes: _selectedTrainingTypes.toList(),
      fitnessInterests: _selectedInterests.toList(),
      preferredCityId: _selectedCityId,
      preferredTrainingLocation: _preferredLocation,
      privateAddress: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      emergencyContact: _emergencyController.text.trim().isNotEmpty
          ? _emergencyController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      await LocationService.instance.setCity(_selectedCityId, venue: _preferredLocation);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile saved successfully!',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.isEditMode) {
        Navigator.of(context).maybePop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
        );
      }
    } else if (_controller.errorMessage != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage!,
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E1E24),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    final user = _controller.user;
    final gender = user?.gender;
    final genderStr = gender == Gender.female ? 'Female' : 'Male';
    final completion = _controller.completionPercentage;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isEditMode
            ? IconButton(
                icon: const Icon(Iconsax.arrow_left, color: kDark),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const AppLogo(fontSize: 16),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── Header & Profile Completion Score ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditMode ? 'Edit Profile' : 'Profile Setup',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (26.0 * sf).clamp(22.0, 32.0),
                              fontWeight: FontWeight.w800,
                              color: kDark,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Personalize your profile for personal training and fitness goals.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (12.0 * sf).clamp(11.0, 13.5),
                              color: kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Completion Indicator Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$completion%',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (14.0 * sf).clamp(12.0, 16.0),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (9.0 * sf).clamp(8.0, 10.5),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Linear Completion Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completion / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: const AlwaysStoppedAnimation<Color>(kLime),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Profile Picture Avatar Picker ──
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImagePickerSheet,
                        child: CircleAvatar(
                          radius: (48.0 * sf).clamp(40.0, 56.0),
                          backgroundColor: const Color(0xFF111111),
                          backgroundImage: _controller.selectedPhotoFile != null
                              ? FileImage(_controller.selectedPhotoFile!)
                              : (user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                                  ? NetworkImage(user.photoUrl!) as ImageProvider
                                  : null),
                          child: (_controller.selectedPhotoFile == null &&
                                  (user?.photoUrl == null || user!.photoUrl!.isEmpty))
                              ? Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (32.0 * sf).clamp(26.0, 38.0),
                                    fontWeight: FontWeight.w800,
                                    color: kLime,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImagePickerSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Iconsax.camera, size: 16, color: kLime),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── SECTION 1: Personal Information ──
                _SectionTitle(title: 'PERSONAL INFORMATION', sf: sf),
                const SizedBox(height: 12),

                // Full Name
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name *',
                  icon: Iconsax.user,
                ),

                const SizedBox(height: 14),

                // Phone Number
                AppTextField(
                  controller: _phoneController,
                  label: 'Mobile Number (+91) *',
                  icon: Iconsax.call,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 14),

                // Date of Birth
                InkWell(
                  onTap: _selectDateOfBirth,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.calendar_1, size: 18, color: Color(0xFFAAAAAA)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dateOfBirth != null
                                ? 'Date of Birth: ${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                : 'Select Date of Birth *',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (13.0 * sf).clamp(11.5, 14.5),
                              color: _dateOfBirth != null ? kDark : kGrey,
                              fontWeight: _dateOfBirth != null ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        const Icon(Iconsax.arrow_down_1, size: 16, color: Color(0xFF888888)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Gender: Locked & Consistent with Registration (Section 5)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        gender == Gender.female ? Icons.female : Icons.male,
                        size: 20,
                        color: kDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Gender: $genderStr Athlete',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (13.0 * sf).clamp(12.0, 14.5),
                                    fontWeight: FontWeight.w700,
                                    color: kDark,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.lock, size: 13, color: Color(0xFF888888)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Account detail locked after registration.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (10.5 * sf).clamp(9.5, 12.0),
                                color: kGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── SECTION 2: Fitness Information ──
                _SectionTitle(title: 'FITNESS TARGETS & EXPERIENCE', sf: sf),
                const SizedBox(height: 12),

                Text(
                  'Primary Fitness Goals (Select multiple)',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goalOptions.map((goal) {
                    final isSelected = _selectedGoals.contains(goal);
                    return FilterChip(
                      label: Text(goal),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : kDark,
                      ),
                      selectedColor: kDark,
                      backgroundColor: const Color(0xFFF7F7F7),
                      checkmarkColor: kLime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? kLime : const Color(0xFFEEEEEE),
                        ),
                      ),
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (selected) {
                            _selectedGoals.add(goal);
                          } else if (_selectedGoals.length > 1) {
                            _selectedGoals.remove(goal);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                Text(
                  'Fitness Experience Level',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: _levelOptions.map((opt) {
                    final isSelected = _selectedLevel == opt['title'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedLevel = opt['title']!);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? kDark : const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? kLime : const Color(0xFFEEEEEE),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  opt['title']!,
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : kDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt['desc']!,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (10.0 * sf).clamp(9.0, 11.5),
                                    color: isSelected ? const Color(0xFFBBBBBB) : kGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                Text(
                  'Preferred Training Type',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _trainingTypeOptions.map((type) {
                    final isSelected = _selectedTrainingTypes.contains(type);
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : kDark,
                      ),
                      selectedColor: kDark,
                      backgroundColor: const Color(0xFFF7F7F7),
                      checkmarkColor: kLime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? kLime : const Color(0xFFEEEEEE),
                        ),
                      ),
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (selected) {
                            _selectedTrainingTypes.add(type);
                          } else if (_selectedTrainingTypes.length > 1) {
                            _selectedTrainingTypes.remove(type);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                Text(
                  'Special Focus & Fitness Interests',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _interestOptions.map((interest) {
                    final isSelected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : kDark,
                      ),
                      selectedColor: kDark,
                      backgroundColor: const Color(0xFFF7F7F7),
                      checkmarkColor: kLime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? kLime : const Color(0xFFEEEEEE),
                        ),
                      ),
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (selected) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // ── SECTION 3: Location & Preferences ──
                _SectionTitle(title: 'LOCATION & VENUE PREFERENCE', sf: sf),
                const SizedBox(height: 12),

                // Launch City
                Text(
                  'City of Residence',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCityId,
                      isExpanded: true,
                      icon: const Icon(Iconsax.arrow_down_1, size: 18, color: kDark),
                      items: LocationService.instance.allCities.map((city) {
                        return DropdownMenuItem<String>(
                          value: city.id,
                          enabled: city.isActive,
                          child: Text(
                            city.isActive
                                ? '${city.name} (${city.state})'
                                : '${city.name} (${city.state}) - Coming Soon',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (13.0 * sf).clamp(12.0, 14.5),
                              fontWeight: FontWeight.w500,
                              color: city.isActive ? kDark : const Color(0xFF999999),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCityId = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Preferred Training Location
                Text(
                  'Preferred Workout Venue',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(11.0, 13.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _preferredLocation,
                      isExpanded: true,
                      icon: const Icon(Iconsax.arrow_down_1, size: 18, color: kDark),
                      items: _locationOptions.map((loc) {
                        return DropdownMenuItem<String>(
                          value: loc,
                          child: Text(
                            loc,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (13.0 * sf).clamp(12.0, 14.5),
                              fontWeight: FontWeight.w500,
                              color: kDark,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _preferredLocation = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Private Address with Privacy Badge
                AppTextField(
                  controller: _addressController,
                  label: 'Street / Society Address (Optional)',
                  icon: Iconsax.home_2,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kept strictly private and only shared with your confirmed trainer.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (10.5 * sf).clamp(9.5, 12.0),
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Emergency Contact
                AppTextField(
                  controller: _emergencyController,
                  label: 'Emergency Contact Phone (Optional)',
                  icon: Iconsax.call_calling,
                  keyboardType: TextInputType.phone,
                ),

                SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

                // ── Submit Button ──
                AppPrimaryButton(
                  label: widget.isEditMode ? 'Update Profile' : 'Save & Explore Coaches',
                  loading: _controller.isSaving,
                  onTap: _handleSave,
                ),

                SizedBox(height: (h * 0.05 * sf).clamp(28.0, 48.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final double sf;

  const _SectionTitle({required this.title, required this.sf});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Syne',
        fontSize: (11.5 * sf).clamp(10.5, 13.0),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF888888),
        letterSpacing: 0.8,
      ),
    );
  }
}
