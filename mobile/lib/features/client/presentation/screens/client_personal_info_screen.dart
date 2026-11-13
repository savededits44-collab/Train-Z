import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/validators.dart';
import '../../../../services/client_settings_service.dart';
import '../../../../shared/models/client_profile_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';

class ClientPersonalInfoScreen extends StatefulWidget {
  final String clientId;
  final UserModel? userModel;
  final ClientProfileModel? profileModel;

  const ClientPersonalInfoScreen({
    super.key,
    required this.clientId,
    this.userModel,
    this.profileModel,
  });

  @override
  State<ClientPersonalInfoScreen> createState() => _ClientPersonalInfoScreenState();
}

class _ClientPersonalInfoScreenState extends State<ClientPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientSettingsService _settingsService = ClientSettingsService.instance;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emergencyContactController;

  File? _newPhotoFile;
  DateTime? _selectedDob;
  String? _preferredVenue;
  String? _fitnessLevel;
  final List<String> _fitnessGoals = [];

  bool _isSaving = false;
  String? _errorMessage;

  static const List<String> _venueOptions = [
    'Commercial Gym',
    'Home Gym',
    'Outdoor Park',
    'Trainer Studio',
  ];

  static const List<String> _fitnessLevelOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static const List<String> _availableGoals = [
    'Build Muscle & Strength',
    'Fat Loss & Conditioning',
    'Core Strength & Posture',
    'Athletic Performance',
    'Endurance & Cardio',
    'Mobility & Flexibility',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel?.displayName ?? '');
    _phoneController = TextEditingController(text: widget.userModel?.phoneNumber ?? '');
    _emergencyContactController = TextEditingController(text: widget.profileModel?.emergencyContact ?? '');
    _selectedDob = widget.profileModel?.dateOfBirth;
    _preferredVenue = widget.profileModel?.preferredTrainingLocation ?? _venueOptions.first;
    _fitnessLevel = widget.profileModel?.fitnessLevel ?? _fitnessLevelOptions.first;
    _fitnessGoals.addAll(widget.profileModel?.fitnessGoals ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final file = File(picked.path);
        final length = await file.length();
        if (length > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected photo exceeds the 5MB size limit.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
          return;
        }
        setState(() {
          _newPhotoFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select image: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16, color: kDark),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Iconsax.camera, color: kDark),
                title: const Text('Take a Photo', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.gallery, color: kDark),
                title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // 1. Upload photo if changed
      if (_newPhotoFile != null) {
        await _settingsService.updateProfilePhoto(
          uid: widget.clientId,
          imageFile: _newPhotoFile!,
        );
      }

      // 2. Update Personal & Fitness Profile
      await _settingsService.updatePersonalInfo(
        uid: widget.clientId,
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        dateOfBirth: _selectedDob,
        preferredVenue: _preferredVenue,
        emergencyContact: _emergencyContactController.text.trim(),
        fitnessGoals: _fitnessGoals,
        fitnessLevel: _fitnessLevel,
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal profile updated successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('TrainZException: ', '').replaceAll('SettingsException: ', '');
      });
    }
  }

  void _showChangeEmailDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Email Address', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16, color: kDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A verification email will be dispatched to your new address. Your account email will update once verified.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'New Email Address',
                hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newEmail = emailCtrl.text.trim();
              if (newEmail.isEmpty || !newEmail.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _settingsService.requestEmailUpdate(newEmail);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification sent to $newEmail. Please confirm via your inbox.'),
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kDark, foregroundColor: kLime, elevation: 0),
            child: const Text('Send Verification', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.25);
    final currentPhoto = widget.userModel?.photoUrl;
    final currentEmail = widget.userModel?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Personal Information',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Avatar Picker ──
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: kDark,
                      backgroundImage: _newPhotoFile != null
                          ? FileImage(_newPhotoFile!)
                          : (currentPhoto != null && currentPhoto.isNotEmpty
                              ? NetworkImage(currentPhoto)
                              : null) as ImageProvider?,
                      child: (_newPhotoFile == null && (currentPhoto == null || currentPhoto.isEmpty))
                          ? const Icon(Iconsax.user, size: 40, color: kLime)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
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
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _showImagePickerSheet,
                  child: const Text(
                    'Change Profile Photo',
                    style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12, color: kDark),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── 2. Full Name ──
              _buildInputLabel('Full Name *', sf),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                validator: Validators.validateName,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                decoration: _buildInputDecoration(hint: 'Enter your full name', icon: Iconsax.user),
              ),

              const SizedBox(height: 16),

              // ── 3. Phone Number ──
              _buildInputLabel('Phone Number', sf),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                decoration: _buildInputDecoration(hint: 'e.g. +91 98765 43210', icon: Iconsax.call),
              ),

              const SizedBox(height: 16),

              // ── 4. Email Address (Verified) ──
              _buildInputLabel('Registered Email', sf),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.sms, size: 18, color: Color(0xFF6B7280)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentEmail,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF4B5563)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _showChangeEmailDialog,
                      child: const Text(
                        'Change',
                        style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12, color: kDark, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 5. Date of Birth ──
              _buildInputLabel('Date of Birth', sf),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDob ?? DateTime(now.year - 25, 1, 1),
                    firstDate: DateTime(1940),
                    lastDate: DateTime(now.year - 14, now.month, now.day),
                  );
                  if (picked != null) {
                    setState(() => _selectedDob = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar, size: 18, color: kDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDob != null
                              ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}'
                              : 'Select your date of birth',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: _selectedDob != null ? kDark : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 6. Preferred Workout Venue ──
              _buildInputLabel('Preferred Workout Venue', sf),
              DropdownButtonFormField<String>(
                initialValue: _preferredVenue,
                items: _venueOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _preferredVenue = val),
                decoration: _buildInputDecoration(hint: 'Select venue', icon: Iconsax.location),
              ),

              const SizedBox(height: 16),

              // ── 7. Fitness Experience Level ──
              _buildInputLabel('Fitness Experience Level', sf),
              DropdownButtonFormField<String>(
                initialValue: _fitnessLevel,
                items: _fitnessLevelOptions.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _fitnessLevel = val),
                decoration: _buildInputDecoration(hint: 'Select experience level', icon: Iconsax.activity),
              ),

              const SizedBox(height: 16),

              // ── 8. Emergency Contact ──
              _buildInputLabel('Emergency Contact (Name & Phone)', sf),
              TextFormField(
                controller: _emergencyContactController,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: kDark),
                decoration: _buildInputDecoration(hint: 'e.g. Priya (Sister) +91 98765 00000', icon: Iconsax.call_calling),
              ),

              const SizedBox(height: 16),

              // ── 9. Fitness Goals ──
              _buildInputLabel('Fitness Goals & Focus', sf),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableGoals.map((goal) {
                  final isSelected = _fitnessGoals.contains(goal);
                  return FilterChip(
                    label: Text(goal),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _fitnessGoals.add(goal);
                        } else {
                          _fitnessGoals.remove(goal);
                        }
                      });
                    },
                    selectedColor: kDark,
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? kLime : kDark,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? kDark : const Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    foregroundColor: kLime,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLime))
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 15, color: kLime),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, double sf) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Syne',
          fontSize: (12.0 * sf).clamp(11.0, 13.5),
          fontWeight: FontWeight.w700,
          color: kDark,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFA0A0A0)),
      prefixIcon: Icon(icon, size: 18, color: kDark),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDark, width: 1.5)),
    );
  }
}
