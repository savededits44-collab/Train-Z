import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../features/trainer/presentation/screens/trainer_pending_approval_screen.dart';
import '../../routing/app_router.dart';
import '../../services/storage_service.dart';
import '../../services/trainer_certificate_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/trainer_certificate_model.dart';
import '../../shared/models/trainer_profile_model.dart';
import '../../shared/models/user_model.dart';
import '../../widgets/app_widgets.dart';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// Trainer Profile Setup Screen
/// Collects Personal Profile Info, Professional Information, and Training Services.
/// Features live profile completion indicator, draft progress saving,
/// and prevents incomplete profiles from being submitted for Admin review.
class TrainerProfileSetupScreen extends StatefulWidget {
  const TrainerProfileSetupScreen({super.key});

  @override
  State<TrainerProfileSetupScreen> createState() => _TrainerProfileSetupScreenState();
}

class _TrainerProfileSetupScreenState extends State<TrainerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ──
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _experienceController;
  late TextEditingController _professionalExperienceController;
  late TextEditingController _trainingApproachController;
  late TextEditingController _workingHoursController;

  // Tag & custom input controllers
  final _newAreaController = TextEditingController();
  final _newOtherLocationController = TextEditingController();
  final _newSpecialtyController = TextEditingController();
  final _newLanguageController = TextEditingController();

  // ── Personal Info State ──
  String? _photoUrl;
  String? _localPhotoPath;
  DateTime? _selectedDob;
  Gender? _selectedGender;
  bool _isUploadingPhoto = false;
  double _uploadProgress = 0.0;

  // ── Professional Information State ──
  TrainerCategory _category = TrainerCategory.trainer;
  final Set<String> _specialties = {};
  final Set<String> _clientTypes = {};
  final Set<String> _trainingGoals = {};
  final Set<String> _trainingMethods = {};
  final Set<String> _languages = {};

  // ── Training Services State ──
  bool _trainsAtHome = false;
  bool _trainsAtGym = false;
  final List<String> _otherTrainingLocations = [];
  final List<String> _serviceAreas = [];
  final Set<String> _workingDays = {};

  // ── Lifecycle & Loading State ──
  bool _isLoadingInitial = true;
  bool _isSavingDraft = false;
  bool _isSubmitting = false;
  bool _showChecklistExpanded = false;

  final ImagePicker _picker = ImagePicker();

  // Default option sets
  static const List<String> _defaultSpecialties = [
    'Strength & Conditioning',
    'Weight Loss & Fat Loss',
    'Hypertrophy & Muscle Gain',
    'Functional Training',
    'Core Strength & Posture',
    'Mobility & Flexibility',
    'HIIT & Cardio Conditioning',
    'Calisthenics',
    'Powerlifting',
    'CrossFit',
    'Yoga & Mind-Body',
    'Post-Rehab & Corrective Exercise',
  ];

  static const List<String> _defaultClientTypes = [
    'Beginners',
    'Intermediate Athletes',
    'Advanced Lifters',
    'Corporate Professionals',
    'Women\'s Fitness & Prenatal',
    'Senior Citizens (50+)',
    'Post-Injury Rehab Clients',
    'Youth / Teens',
  ];

  static const List<String> _defaultTrainingGoals = [
    'Fat Loss & Toning',
    'Muscle Hypertrophy',
    'Maximal Strength',
    'Posture & Core Stability',
    'Endurance & Stamina',
    'Agility & Athletic Performance',
    'Joint Longevity & Mobility',
    'Healthy Lifestyle Routine',
  ];

  static const List<String> _defaultTrainingMethods = [
    'Progressive Overload',
    'Periodization Training',
    'High-Intensity Interval Training (HIIT)',
    'Circuit Training',
    'Kettlebell Training',
    'Barbell & Compound Movements',
    'Bodyweight & Calisthenics',
    'Resistance Bands & Suspension',
  ];

  static const List<String> _defaultLanguages = [
    'English',
    'Hindi',
    'Marathi',
    'Gujarati',
    'Bengali',
    'Kannada',
    'Tamil',
    'Telugu',
    'Punjabi',
  ];

  static const List<Map<String, String>> _allDays = [
    {'code': 'MON', 'label': 'Mon'},
    {'code': 'TUE', 'label': 'Tue'},
    {'code': 'WED', 'label': 'Wed'},
    {'code': 'THU', 'label': 'Thu'},
    {'code': 'FRI', 'label': 'Fri'},
    {'code': 'SAT', 'label': 'Sat'},
    {'code': 'SUN', 'label': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadProfileData();
  }

  void _initControllers() {
    final service = TrainerProfileService.instance;
    _nameController = TextEditingController(text: service.fullName ?? '');
    _phoneController = TextEditingController(text: service.mobileNumber ?? '');
    _bioController = TextEditingController(text: service.bio ?? '');
    _experienceController = TextEditingController(
      text: service.experienceYears > 0 ? service.experienceYears.toString() : '',
    );
    _professionalExperienceController = TextEditingController(
      text: service.professionalExperience ?? '',
    );
    _trainingApproachController = TextEditingController(
      text: service.trainingApproach ?? '',
    );
    _workingHoursController = TextEditingController(
      text: service.workingHours ?? '06:00 AM - 09:00 PM',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _professionalExperienceController.dispose();
    _trainingApproachController.dispose();
    _workingHoursController.dispose();
    _newAreaController.dispose();
    _newOtherLocationController.dispose();
    _newSpecialtyController.dispose();
    _newLanguageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await TrainerProfileService.instance.loadProfile(uid);
    }

    final service = TrainerProfileService.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      setState(() {
        _nameController.text = (service.fullName != null && service.fullName!.isNotEmpty)
            ? service.fullName!
            : (user?.displayName ?? '');

        _phoneController.text = (service.mobileNumber != null && service.mobileNumber!.isNotEmpty)
            ? service.mobileNumber!
            : (user?.phoneNumber ?? '');

        _bioController.text = service.bio ?? '';
        _experienceController.text = service.experienceYears > 0
            ? (service.experienceYears % 1 == 0
                ? service.experienceYears.toInt().toString()
                : service.experienceYears.toString())
            : '';

        _professionalExperienceController.text = service.professionalExperience ?? '';
        _trainingApproachController.text = service.trainingApproach ?? '';
        _workingHoursController.text = (service.workingHours != null && service.workingHours!.isNotEmpty)
            ? service.workingHours!
            : '06:00 AM - 09:00 PM';

        _photoUrl = service.photoUrl ?? user?.photoURL;
        _category = service.category;
        _selectedGender = service.gender;

        if (service.dateOfBirth != null && service.dateOfBirth!.isNotEmpty) {
          _selectedDob = DateTime.tryParse(service.dateOfBirth!);
        }

        _specialties.clear();
        _specialties.addAll(service.specialties.isNotEmpty
            ? service.specialties
            : ['Strength & Conditioning']);

        _clientTypes.clear();
        _clientTypes.addAll(service.clientTypes);

        _trainingGoals.clear();
        _trainingGoals.addAll(service.trainingGoals);

        _trainingMethods.clear();
        _trainingMethods.addAll(service.trainingMethods);

        _languages.clear();
        _languages.addAll(service.languages.isNotEmpty ? service.languages : ['English']);

        _trainsAtHome = service.trainsAtHome;
        _trainsAtGym = service.trainsAtGym;
        _otherTrainingLocations.clear();
        _otherTrainingLocations.addAll(service.otherTrainingLocations);

        _serviceAreas.clear();
        _serviceAreas.addAll(service.serviceAreas);

        _workingDays.clear();
        _workingDays.addAll(service.workingDays.isNotEmpty
            ? service.workingDays
            : ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']);

        _isLoadingInitial = false;
      });
    }
  }

  // ── Completion Calculation ──

  TrainerProfileCompletion _evaluateCompletion() {
    final exp = double.tryParse(_experienceController.text.trim()) ?? 0.0;
    final dobStr = _selectedDob != null
        ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
        : null;

    final tempModel = TrainerProfileModel(
      uid: 'eval_uid',
      category: _category,
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      gender: _selectedGender,
      dateOfBirth: dobStr,
      photoUrl: _photoUrl,
      bio: _bioController.text.trim(),
      experienceYears: exp,
      specialties: _specialties.toList(),
      clientTypes: _clientTypes.toList(),
      trainingGoals: _trainingGoals.toList(),
      trainingMethods: _trainingMethods.toList(),
      languages: _languages.toList(),
      trainingApproach: _trainingApproachController.text.trim(),
      professionalExperience: _professionalExperienceController.text.trim(),
      trainsAtHome: _trainsAtHome,
      trainsAtGym: _trainsAtGym,
      otherTrainingLocations: _otherTrainingLocations,
      serviceAreas: _serviceAreas,
      workingDays: _workingDays.toList(),
      workingHours: _workingHoursController.text.trim(),
    );

    return tempModel.calculateCompletion(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      genderValue: _selectedGender,
    );
  }

  // ── Photo Upload ──

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file == null) return;

      final localFile = File(file.path);
      final size = await localFile.length();
      if (size > StorageService.maxProfileImageBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image must be less than 5 MB.'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
        return;
      }

      setState(() {
        _localPhotoPath = file.path;
        _isUploadingPhoto = true;
        _uploadProgress = 0.1;
      });

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'temp_user';
      final downloadUrl = await StorageService().uploadProfilePicture(
        userId: uid,
        file: localFile,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
        _isUploadingPhoto = false;
        _uploadProgress = 1.0;
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo uploaded successfully!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final sf = scaleFactor(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Profile Photo',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (18.0 * sf).clamp(16.0, 22.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload a clear, professional photo to display on your trainer profile.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.5 * sf).clamp(11.0, 14.0),
                    color: kGrey,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kLime.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.camera, color: kDark),
                  ),
                  title: const Text(
                    'Take Photo (Camera)',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                  subtitle: const Text(
                    'Capture directly from camera',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: kField,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.gallery, color: kDark),
                  ),
                  title: const Text(
                    'Choose From Gallery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                  subtitle: const Text(
                    'Select saved photo from your library',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Date Picker ──

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    final minDate = DateTime(1950, 1, 1);
    final initial = _selectedDob ?? DateTime(1996, 6, 15);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(maxDate) ? maxDate : initial,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'SELECT DATE OF BIRTH',
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
      setState(() => _selectedDob = picked);
    }
  }

  // ── Save Draft Action ──

  Future<void> _handleSaveDraft() async {
    setState(() => _isSavingDraft = true);
    HapticFeedback.lightImpact();

    try {
      final exp = double.tryParse(_experienceController.text.trim()) ?? 0.0;
      final dobStr = _selectedDob != null
          ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
          : null;

      final completion = await TrainerProfileService.instance.saveProfileDetails(
        fullName: _nameController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        dateOfBirth: dobStr ?? '',
        gender: _selectedGender ?? Gender.male,
        bio: _bioController.text.trim(),
        experienceYears: exp,
        specialties: _specialties.toList(),
        clientTypes: _clientTypes.toList(),
        trainingGoals: _trainingGoals.toList(),
        trainingMethods: _trainingMethods.toList(),
        languages: _languages.toList(),
        professionalExperience: _professionalExperienceController.text.trim(),
        trainingApproach: _trainingApproachController.text.trim(),
        trainsAtHome: _trainsAtHome,
        trainsAtGym: _trainsAtGym,
        otherTrainingLocations: _otherTrainingLocations,
        serviceAreas: _serviceAreas,
        workingDays: _workingDays.toList(),
        workingHours: _workingHoursController.text.trim(),
        photoUrl: _photoUrl,
        photoPath: _localPhotoPath,
        submitForReview: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: kLime, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Profile draft saved (${completion.score}% complete). You can resume anytime.',
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: kDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save draft: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  // ── Submit for Review Action ──

  Future<void> _handleSubmitForReview() async {
    final completion = _evaluateCompletion();

    if (!completion.isComplete) {
      HapticFeedback.heavyImpact();
      setState(() => _showChecklistExpanded = true);

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          final sf = scaleFactor(context);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.warning_2, color: Color(0xFFD32F2F), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Incomplete (${completion.score}%)',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (16.0 * sf).clamp(15.0, 18.0),
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                            const Text(
                              'All required details must be filled before Admin review.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please complete the following required items:',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: completion.missingFields.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        return Row(
                          children: [
                            const Icon(Icons.circle_outlined, size: 10, color: Color(0xFFD32F2F)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                completion.missingFields[idx],
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF424242),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: 'Continue Editing',
                    onTap: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final exp = double.tryParse(_experienceController.text.trim()) ?? 0.0;
      final dobStr = _selectedDob != null
          ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
          : '';

      await TrainerProfileService.instance.saveProfileDetails(
        fullName: _nameController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        dateOfBirth: dobStr,
        gender: _selectedGender!,
        bio: _bioController.text.trim(),
        experienceYears: exp,
        specialties: _specialties.toList(),
        clientTypes: _clientTypes.toList(),
        trainingGoals: _trainingGoals.toList(),
        trainingMethods: _trainingMethods.toList(),
        languages: _languages.toList(),
        professionalExperience: _professionalExperienceController.text.trim(),
        trainingApproach: _trainingApproachController.text.trim(),
        trainsAtHome: _trainsAtHome,
        trainsAtGym: _trainsAtGym,
        otherTrainingLocations: _otherTrainingLocations,
        serviceAreas: _serviceAreas,
        workingDays: _workingDays.toList(),
        workingHours: _workingHoursController.text.trim(),
        photoUrl: _photoUrl,
        photoPath: _localPhotoPath,
        submitForReview: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Profile completed and submitted for Admin verification!',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TrainerPendingApprovalScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit profile: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: kDark)),
      );
    }

    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);
    final completion = _evaluateCompletion();
    final isAdvanced = _category == TrainerCategory.advancedTrainer;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Trainer Profile Setup',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (16.0 * sf).clamp(14.0, 18.0),
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSavingDraft ? null : _handleSaveDraft,
            child: _isSavingDraft
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kDark),
                  )
                : const Text(
                    'Save Draft',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: (h * 0.015).clamp(8.0, 20.0)),

                // ── Completion Progress Indicator Card ──
                _buildCompletionCard(completion, sf),

                const SizedBox(height: 24),

                // ═════════════════════════════════════════════════════════════
                // SECTION 1: Personal Profile Information
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader('1. PERSONAL PROFILE', sf),
                const SizedBox(height: 16),

                // Profile Photo Avatar with Upload
                _buildPhotoPicker(sf),
                const SizedBox(height: 20),

                // Full Name
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name (from registration)',
                  icon: Iconsax.user,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                ),
                const SizedBox(height: 14),

                // Phone Number
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone Number (from registration)',
                  icon: Iconsax.call,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Valid 10-digit phone number is required' : null,
                ),
                const SizedBox(height: 14),

                // Date of Birth Field
                _buildDobSelector(sf),
                const SizedBox(height: 14),

                // Gender Field (Protected under private backend matching)
                _buildGenderSelector(sf),
                const SizedBox(height: 14),

                // Professional Biography
                AppTextField(
                  controller: _bioController,
                  label: 'Professional Biography (min. 20 characters)',
                  icon: Iconsax.document_text,
                  keyboardType: TextInputType.multiline,
                  validator: (v) => (v == null || v.trim().length < 20)
                      ? 'Biography must be at least 20 characters'
                      : null,
                ),
                const SizedBox(height: 14),

                // Years of Experience
                AppTextField(
                  controller: _experienceController,
                  label: isAdvanced
                      ? 'Total Years of Experience (Min. 3.5 years required)'
                      : 'Total Years of Training Experience',
                  icon: Iconsax.clock,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final numVal = double.tryParse(v ?? '');
                    if (numVal == null) return 'Enter a valid numeric value';
                    if (isAdvanced && numVal < 3.5) {
                      return 'Advanced Trainers require minimum 3.5 years experience';
                    }
                    if (numVal < 0) return 'Experience cannot be negative';
                    return null;
                  },
                ),
                if (isAdvanced) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Advanced Trainer eligibility requires minimum 3.5 years of verifiable coaching experience.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ═════════════════════════════════════════════════════════════
                // SECTION 2: Professional Information
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader('2. PROFESSIONAL INFORMATION', sf),
                const SizedBox(height: 16),

                // Training Specialisations
                _buildChipGroup(
                  title: 'Training Specialisations (Select all that apply):',
                  options: _defaultSpecialties,
                  selected: _specialties,
                  onChanged: (set) => setState(() {}),
                  customController: _newSpecialtyController,
                  customPlaceholder: 'Add custom specialty...',
                  sf: sf,
                ),
                const SizedBox(height: 18),

                // Types of Clients
                _buildChipGroup(
                  title: 'Types of Clients You Work With:',
                  options: _defaultClientTypes,
                  selected: _clientTypes,
                  onChanged: (set) => setState(() {}),
                  sf: sf,
                ),
                const SizedBox(height: 18),

                // Fitness Goals
                _buildChipGroup(
                  title: 'Fitness Goals You Help Clients Achieve:',
                  options: _defaultTrainingGoals,
                  selected: _trainingGoals,
                  onChanged: (set) => setState(() {}),
                  sf: sf,
                ),
                const SizedBox(height: 18),

                // Training Methods
                _buildChipGroup(
                  title: 'Training Methods:',
                  options: _defaultTrainingMethods,
                  selected: _trainingMethods,
                  onChanged: (set) => setState(() {}),
                  sf: sf,
                ),
                const SizedBox(height: 18),

                // Languages Spoken
                _buildChipGroup(
                  title: 'Languages Spoken:',
                  options: _defaultLanguages,
                  selected: _languages,
                  onChanged: (set) => setState(() {}),
                  customController: _newLanguageController,
                  customPlaceholder: 'Add custom language...',
                  sf: sf,
                ),
                const SizedBox(height: 18),

                // Training Approach Description
                AppTextField(
                  controller: _trainingApproachController,
                  label: 'Training Approach & Coaching Philosophy',
                  icon: Iconsax.award,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 14),

                // Relevant Professional Experience
                AppTextField(
                  controller: _professionalExperienceController,
                  label: isAdvanced
                      ? 'Detailed Professional Experience (Gyms, Transformations, Milestones)'
                      : 'Relevant Professional Experience (Optional)',
                  icon: Iconsax.briefcase,
                  keyboardType: TextInputType.multiline,
                ),
                if (isAdvanced) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Advanced Trainer status is verified independently by Admin before activation.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: kGrey,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ═════════════════════════════════════════════════════════════
                // SECTION 3: Training Services
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader('3. TRAINING SERVICES', sf),
                const SizedBox(height: 14),

                // Service Location Options
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supported Training Locations:',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _trainsAtHome,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: kDark,
                        activeTrackColor: kLime,
                        title: const Text(
                          'Home Training (Client\'s Residence)',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                        ),
                        onChanged: (val) => setState(() => _trainsAtHome = val),
                      ),
                      SwitchListTile(
                        value: _trainsAtGym,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: kDark,
                        activeTrackColor: kLime,
                        title: const Text(
                          'Gym Training (Partner / Commercial Gyms)',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                        ),
                        onChanged: (val) => setState(() => _trainsAtGym = val),
                      ),
                      const SizedBox(height: 8),

                      // Other supported locations
                      const Text(
                        'Other Locations (Society Clubhouses, Parks, etc.):',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newOtherLocationController,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'e.g. Society Gym, Outdoor Park',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: kBorder),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final text = _newOtherLocationController.text.trim();
                              if (text.isNotEmpty && !_otherTrainingLocations.contains(text)) {
                                setState(() {
                                  _otherTrainingLocations.add(text);
                                  _newOtherLocationController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('Add', style: TextStyle(fontFamily: 'Syne', color: kLime)),
                          ),
                        ],
                      ),
                      if (_otherTrainingLocations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _otherTrainingLocations.map((loc) {
                            return Chip(
                              label: Text(loc, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                              backgroundColor: Colors.white,
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() => _otherTrainingLocations.remove(loc)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Dynamic Service Areas (No Hardcoded Cities)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service Areas & Localities (Dynamic Across India):',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Specify the areas or neighborhoods where you offer personal training services.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newAreaController,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Enter locality (e.g. Koregaon Park, Baner, Indiranagar)',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: kBorder),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final text = _newAreaController.text.trim();
                              if (text.isNotEmpty && !_serviceAreas.contains(text)) {
                                setState(() {
                                  _serviceAreas.add(text);
                                  _newAreaController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('Add', style: TextStyle(fontFamily: 'Syne', color: kLime)),
                          ),
                        ],
                      ),
                      if (_serviceAreas.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _serviceAreas.map((area) {
                            return Chip(
                              label: Text(area, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500)),
                              backgroundColor: Colors.white,
                              deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFD32F2F)),
                              onDeleted: () => setState(() => _serviceAreas.remove(area)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Preferred Working Days
                const Text(
                  'Preferred Working Days:',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: kDark),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allDays.map((d) {
                    final isSel = _workingDays.contains(d['code']);
                    return FilterChip(
                      label: Text(
                        d['label']!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? kDark : const Color(0xFF424242),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: kLime,
                      backgroundColor: kField,
                      checkmarkColor: kDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isSel ? kDark : kBorder),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _workingDays.add(d['code']!);
                          } else {
                            _workingDays.remove(d['code']!);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // General Working Hours
                AppTextField(
                  controller: _workingHoursController,
                  label: 'General Working Hours (e.g. 06:00 AM - 09:00 PM)',
                  icon: Iconsax.clock,
                ),

                const SizedBox(height: 36),

                // ═════════════════════════════════════════════════════════════
                // SECTION 4: Certificates & Qualifications
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader('4. CERTIFICATES & QUALIFICATIONS', sf),
                const SizedBox(height: 14),
                _buildCertificatesOverviewCard(sf),

                const SizedBox(height: 36),

                // ═════════════════════════════════════════════════════════════
                // SECTION 5: Action Buttons
                // ═════════════════════════════════════════════════════════════
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSavingDraft ? null : _handleSaveDraft,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kDark, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSavingDraft
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kDark),
                              )
                            : const Text(
                                'Save Progress',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kDark,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmitForReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: completion.isComplete ? kDark : const Color(0xFF757575),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    completion.isComplete ? Icons.check_circle_rounded : Iconsax.lock,
                                    size: 16,
                                    color: completion.isComplete ? kLime : Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Submit for Review',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: completion.isComplete ? kLime : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI Helper Widgets
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildCertificatesOverviewCard(double sf) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final category = _category;
    final expYears = double.tryParse(_experienceController.text.trim()) ?? 0.0;

    return StreamBuilder<List<TrainerCertificateModel>>(
      stream: TrainerCertificateService.instance.streamTrainerCertificates(uid),
      builder: (context, snapshot) {
        final certs = snapshot.data ?? [];
        final eligibility = TrainerCertificateService.instance.checkCategoryRequirements(
          category: category,
          certificates: certs,
          experienceYears: expYears,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kField,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Iconsax.award, color: kLime, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        category.displayName,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (14.0 * sf).clamp(13.0, 16.0),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: eligibility.isEligible
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${certs.length} Submitted',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: eligibility.isEligible
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                category == TrainerCategory.advancedTrainer
                    ? 'Advanced Trainers must submit relevant professional trainer certificates and have at least 3.5 years of experience.'
                    : 'Standard Trainers must submit at least one beginner-level trainer certificate for Admin verification.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF555555),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: const [
                    Icon(Iconsax.shield_tick, color: Color(0xFF16A34A), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stored privately: Clients never see full certificate files or links.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRouter.trainerCertificates,
                    arguments: {
                      'trainerId': uid,
                      'category': category,
                    },
                  );
                },
                icon: const Icon(Iconsax.document_upload, size: 16, color: kDark),
                label: Text(
                  certs.isEmpty ? 'Upload Certificates' : 'Manage Certificates (${certs.length})',
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLime,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, double sf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (14.0 * sf).clamp(13.0, 16.0),
            fontWeight: FontWeight.w800,
            color: kDark,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Container(width: 36, height: 3, color: kLime),
      ],
    );
  }

  Widget _buildCompletionCard(TrainerProfileCompletion completion, double sf) {
    final isDone = completion.isComplete;
    final color = isDone ? const Color(0xFF2E7D32) : const Color(0xFFE65100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF1F8E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isDone ? Icons.check_circle_rounded : Iconsax.chart_2, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Profile Completion: ${completion.score}%',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.0 * sf).clamp(13.0, 16.0),
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDone ? 'READY FOR REVIEW' : 'DRAFT',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completion.score / 100.0,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          if (!isDone) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showChecklistExpanded = !_showChecklistExpanded),
              child: Row(
                children: [
                  Text(
                    '${completion.missingFields.length} required items remaining',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showChecklistExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
            ),
            if (_showChecklistExpanded) ...[
              const SizedBox(height: 8),
              ...completion.missingFields.map((field) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      const Icon(Icons.circle_outlined, size: 8, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        field,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF555555)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoPicker(double sf) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: kField,
                    shape: BoxShape.circle,
                    border: Border.all(color: kDark, width: 2.5),
                  ),
                  child: ClipOval(
                    child: _localPhotoPath != null && _localPhotoPath!.isNotEmpty
                        ? Image.file(File(_localPhotoPath!), fit: BoxFit.cover)
                        : (_photoUrl != null && _photoUrl!.isNotEmpty
                            ? Image.network(
                                _photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Iconsax.user, size: 40, color: kDark),
                              )
                            : const Icon(Iconsax.user, size: 40, color: kGrey)),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: kDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.camera, color: kLime, size: 16),
                  ),
                ),
              ),
            ],
          ),
          if (_isUploadingPhoto) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: kField,
                    valueColor: const AlwaysStoppedAnimation<Color>(kDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uploading ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: kGrey),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Upload Profile Photo (JPG, PNG, WebP < 5MB)',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildDobSelector(double sf) {
    final formattedDob = _selectedDob != null
        ? '${_selectedDob!.day.toString().padLeft(2, '0')} ${_monthNames[_selectedDob!.month - 1]} ${_selectedDob!.year}'
        : 'Select Date of Birth';

    return InkWell(
      onTap: _selectDateOfBirth,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kField,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.calendar, size: 18, color: Color(0xFFAAAAAA)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date of Birth',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDob,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _selectedDob != null ? kDark : kGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector(double sf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Iconsax.shield_tick, size: 16, color: kDark),
              SizedBox(width: 6),
              Text(
                'Gender (Protected for matching eligibility)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Enforces TRAIN Z private gender matching rules in backend logic. Never displayed publicly to clients.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: kGrey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Male')),
                  selected: _selectedGender == Gender.male,
                  selectedColor: kLime,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: _selectedGender == Gender.male ? FontWeight.w700 : FontWeight.w500,
                    color: kDark,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedGender = Gender.male);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Female')),
                  selected: _selectedGender == Gender.female,
                  selectedColor: kLime,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: _selectedGender == Gender.female ? FontWeight.w700 : FontWeight.w500,
                    color: kDark,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedGender = Gender.female);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup({
    required String title,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onChanged,
    TextEditingController? customController,
    String? customPlaceholder,
    required double sf,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: kDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.map((opt) {
            final isSel = selected.contains(opt);
            return FilterChip(
              label: Text(
                opt,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  color: isSel ? kDark : const Color(0xFF424242),
                ),
              ),
              selected: isSel,
              selectedColor: kLime,
              backgroundColor: kField,
              checkmarkColor: kDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSel ? kDark : kBorder),
              ),
              onSelected: (val) {
                if (val) {
                  selected.add(opt);
                } else {
                  selected.remove(opt);
                }
                onChanged(selected);
              },
            );
          }).toList(),
        ),
        if (customController != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customController,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  decoration: InputDecoration(
                    hintText: customPlaceholder ?? 'Add other...',
                    filled: true,
                    fillColor: kField,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = customController.text.trim();
                  if (text.isNotEmpty) {
                    selected.add(text);
                    customController.clear();
                    onChanged(selected);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Add', style: TextStyle(fontFamily: 'Syne', color: kLime)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
