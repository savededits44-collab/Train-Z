import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/trainer_profile_service.dart';
import '../../widgets/app_widgets.dart';

class TrainerProfileSetupScreen extends StatefulWidget {
  const TrainerProfileSetupScreen({super.key});

  @override
  State<TrainerProfileSetupScreen> createState() => _TrainerProfileSetupScreenState();
}

class _TrainerProfileSetupScreenState extends State<TrainerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _sinceController;
  late TextEditingController _gymController;
  late TextEditingController _phoneController;

  String? _capturedPhotoPath;
  String? _certificatePath;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final service = TrainerProfileService.instance;
    _nameController = TextEditingController(text: service.fullName ?? '');
    _ageController = TextEditingController(text: service.age ?? '');
    _sinceController = TextEditingController(text: service.sinceWhen ?? '');
    _gymController = TextEditingController(text: service.gymName ?? '');
    _phoneController = TextEditingController(text: service.mobileNumber ?? '');
    _capturedPhotoPath = service.photoPath;
    _certificatePath = service.certificatePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _sinceController.dispose();
    _gymController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        setState(() {
          _capturedPhotoPath = file.path;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open camera/gallery: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
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
                  'Upload Live Photo',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (18.0 * sf).clamp(16.0, 22.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a clear live selfie or headshot to establish trust with athletes.',
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
                    'Take Live Photo (Camera)',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: kDark,
                    ),
                  ),
                  subtitle: const Text(
                    'Capture directly from front/back camera',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
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
                    'Select existing professional headshot',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
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

  Future<void> _pickCertificate(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (file != null) {
        setState(() {
          _certificatePath = file.path;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error picking certificate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open camera/gallery: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  void _showCertificateOptions() {
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
                  'Upload Certification (Optional)',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (18.0 * sf).clamp(16.0, 22.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Attach your coaching certificate, diploma or fitness credentials from your camera or gallery.',
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
                    'Click photo of physical certificate',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCertificate(ImageSource.camera);
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
                    'Select saved photo or document image',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCertificate(ImageSource.gallery);
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_capturedPhotoPath == null || _capturedPhotoPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please take or upload your Live Photo.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      await TrainerProfileService.instance.saveProfileDetails(
        fullName: _nameController.text,
        age: _ageController.text,
        sinceWhen: _sinceController.text,
        gymName: _gymController.text,
        mobileNumber: _phoneController.text,
        photoPath: _capturedPhotoPath,
        certificatePath: _certificatePath,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Trainer profile completed successfully!',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

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
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Step 2 of 2',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
          ),
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
                SizedBox(height: (h * 0.02).clamp(12.0, 24.0)),

                Text(
                  'Complete Your\nProfile.',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (26.0 * sf).clamp(22.0, 32.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in your verified coaching identity to show on your profile and get matched with athletes.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.5 * sf).clamp(11.0, 14.0),
                    color: kGrey,
                  ),
                ),

                SizedBox(height: (h * 0.03).clamp(18.0, 30.0)),

                // ── Live Photo Avatar Section ──
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              width: (110.0 * sf).clamp(90.0, 130.0),
                              height: (110.0 * sf).clamp(90.0, 130.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kField,
                                border: Border.all(
                                  color: _capturedPhotoPath != null ? kLime : kBorder,
                                  width: _capturedPhotoPath != null ? 3.0 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _capturedPhotoPath != null
                                    ? Image.file(
                                        File(_capturedPhotoPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Iconsax.user, size: 48, color: kGrey),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Iconsax.camera,
                                            size: (36.0 * sf).clamp(28.0, 42.0),
                                            color: kDark,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Live Photo',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: (10.0 * sf).clamp(9.0, 11.5),
                                              fontWeight: FontWeight.w600,
                                              color: kGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: _showPhotoOptions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Iconsax.camera,
                                  color: kLime,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _showPhotoOptions,
                        icon: const Icon(Iconsax.camera, size: 16, color: kDark),
                        label: Text(
                          _capturedPhotoPath != null ? 'Retake Live Photo' : 'Upload / Capture Photo',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (12.5 * sf).clamp(11.0, 14.0),
                            fontWeight: FontWeight.w600,
                            color: kDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.025).clamp(16.0, 26.0)),

                // ── Form Inputs ──

                // 1. Full Name
                Text(
                  'Full Name',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _nameController,
                  label: 'e.g. Vikram Sharma',
                  icon: Iconsax.user,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (v.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // 2. Age & Since When working as trainer (Side by side)
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Age',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (14.0 * sf).clamp(12.0, 16.0),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _ageController,
                            label: 'e.g. 28',
                            icon: Iconsax.calendar,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter age';
                              }
                              final age = int.tryParse(v.trim());
                              if (age == null || age < 18 || age > 80) {
                                return 'Valid age (18-80)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Working Since',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (14.0 * sf).clamp(12.0, 16.0),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _sinceController,
                            label: 'e.g. 2019 / Jan 2020',
                            icon: Iconsax.clock,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter starting year';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Gym Name where they are working
                Text(
                  'Current Gym / Fitness Studio Name',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _gymController,
                  label: "e.g. Gold's Gym Bandra / Cult.fit",
                  icon: Iconsax.building,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your current gym or studio name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // 4. Mobile Number
                Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _phoneController,
                  label: '+91 98765 43210',
                  icon: Iconsax.call,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (clean.length < 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // 5. Certification (Optional)
                Row(
                  children: [
                    Text(
                      'Certification',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (14.0 * sf).clamp(12.0, 16.0),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kField,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kBorder),
                      ),
                      child: Text(
                        '(Optional)',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.0),
                          fontWeight: FontWeight.w500,
                          color: kGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload your coaching certificate, diploma or fitness credentials.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(10.5, 13.0),
                    color: kGrey,
                  ),
                ),
                const SizedBox(height: 12),

                if (_certificatePath == null || _certificatePath!.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: kField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorder),
                          ),
                          child: const Icon(
                            Iconsax.award,
                            color: kDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Attach Coaching Certificate',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (13.0 * sf).clamp(11.5, 14.5),
                            fontWeight: FontWeight.w600,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload photo from gallery or take a picture',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(10.0, 12.0),
                            color: kGrey,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickCertificate(ImageSource.camera),
                                icon: const Icon(Iconsax.camera, size: 16, color: kDark),
                                label: const Text(
                                  'Take Photo',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kDark,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: kBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickCertificate(ImageSource.gallery),
                                icon: const Icon(Iconsax.gallery, size: 16, color: kDark),
                                label: const Text(
                                  'From Gallery',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kDark,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: kBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kLime, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: kField,
                            child: Image.file(
                              File(_certificatePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Iconsax.document, color: kDark, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_circle_rounded,
                                            size: 11, color: Color(0xFF2E7D32)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Attached',
                                          style: TextStyle(
                                            fontFamily: 'Syne',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _certificatePath!.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Certificate ready to save',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10.5,
                                  color: kGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              tooltip: 'Change Certificate',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Iconsax.edit_2, size: 18, color: kDark),
                              onPressed: _showCertificateOptions,
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: Color(0xFFE53935)),
                              onPressed: () {
                                setState(() {
                                  _certificatePath = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: (h * 0.04).clamp(24.0, 44.0)),

                // ── Save Button ──
                AppPrimaryButton(
                  label: 'Save & Complete Profile',
                  loading: _saving,
                  onTap: _handleSave,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

