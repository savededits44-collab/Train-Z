import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/trainer_account_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/trainer_profile_model.dart';
import '../../shared/models/user_model.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

/// Dedicated Personal Information Management Screen for Trainers.
/// Allows updating permitted personal details while preventing role/category self-assignment.
class TrainerPersonalInfoScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerPersonalInfoScreen({super.key, this.trainerId});

  @override
  State<TrainerPersonalInfoScreen> createState() =>
      _TrainerPersonalInfoScreenState();
}

class _TrainerPersonalInfoScreenState extends State<TrainerPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TrainerProfileService _profileService = TrainerProfileService.instance;
  final TrainerAccountService _accountService = TrainerAccountService.instance;
  final ImagePicker _picker = ImagePicker();

  late final String _trainerId;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  Gender? _selectedGender;
  String? _dateOfBirth;
  String? _photoUrl;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        AuthService().currentUser?.uid ??
        '';

    final user = AuthService().currentUser;
    _nameCtrl = TextEditingController(
      text: _profileService.fullName ?? user?.displayName ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: _profileService.mobileNumber ?? user?.phoneNumber ?? '',
    );
    _emailCtrl = TextEditingController(
      text: user?.email ?? '',
    );

    _selectedGender = _profileService.gender;
    _dateOfBirth = _profileService.dateOfBirth;
    _photoUrl = _profileService.photoUrl ?? user?.photoURL;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploadingPhoto = true);
      HapticFeedback.lightImpact();

      final file = File(image.path);
      final downloadUrl = await StorageService().uploadProfilePicture(
        userId: _trainerId,
        file: file,
      );

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo updated successfully',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: _kCardSubBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice: Could not upload photo: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = DateTime.tryParse(_dateOfBirth ?? '') ??
        DateTime(now.year - 25, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kLime,
              onPrimary: _kDark,
              surface: _kCardBg,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _showUpdateEmailDialog() async {
    final newEmailCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text(
          'Update Email Address',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A verification link will be dispatched to your new address. You must verify it to finalize the update.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _kGrey),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: newEmailCtrl,
                style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Email Address',
                  labelStyle: const TextStyle(color: _kGrey),
                  filled: true,
                  fillColor: _kCardSubBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || !v.contains('@') || !v.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _kGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kLime,
              foregroundColor: _kDark,
            ),
            onPressed: () async {
              if (!dialogFormKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              try {
                await AuthService().updateEmailAddress(newEmailCtrl.text.trim());
                if (!mounted) return;
                setState(() => _emailCtrl.text = newEmailCtrl.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verification link dispatched to new email.'),
                    backgroundColor: _kCardSubBg,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Notice: $e'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Send Verification'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      await _accountService.updatePersonalDetails(
        trainerId: _trainerId,
        displayName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _dateOfBirth,
      );

      await _profileService.loadProfile(_trainerId);

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Personal details saved successfully',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: _kCardSubBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdvanced = _profileService.category == TrainerCategory.advancedTrainer;

    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Avatar Picker ─────────────────────────────────
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: _kCardSubBg,
                    backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                        ? NetworkImage(_photoUrl!)
                        : null,
                    child: _photoUrl == null || _photoUrl!.isEmpty
                        ? Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text[0].toUpperCase()
                                : 'T',
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: _kLime,
                            ),
                          )
                        : null,
                  ),
                  if (_isUploadingPhoto)
                    const Positioned.fill(
                      child: CircularProgressIndicator(color: _kLime),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: _kLime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.camera, size: 16, color: _kDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Tap to update photo (Max 5MB • JPG, PNG)',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
              ),
            ),

            const SizedBox(height: 24),

            // ── Locked Account Role & Category Banner ─────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.lock, color: _kLime, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isAdvanced ? 'Advanced Trainer' : 'Standard Trainer',
                              style: const TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kLime.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LOCKED',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _kLime,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Account role and coaching tier are designated by platform administration and cannot be modified here.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _kGrey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Editable Fields ───────────────────────────────
            _buildLabel('Full Name'),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
              decoration: _inputDecoration('Your official full name', Iconsax.user),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildLabel('Phone Number'),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
              decoration: _inputDecoration('+91 98765 43210', Iconsax.call),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildLabel('Email Address'),
            TextFormField(
              controller: _emailCtrl,
              readOnly: true,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70),
              decoration: _inputDecoration('Email address', Iconsax.sms).copyWith(
                suffixIcon: TextButton(
                  onPressed: _showUpdateEmailDialog,
                  child: const Text(
                    'Change',
                    style: TextStyle(fontFamily: 'Syne', color: _kLime, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildLabel('Gender'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Gender>(
                  value: _selectedGender,
                  dropdownColor: _kCardBg,
                  hint: const Text('Select gender', style: TextStyle(color: _kGrey, fontFamily: 'Poppins')),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: Gender.values.map((g) {
                    return DropdownMenuItem<Gender>(
                      value: g,
                      child: Text(
                        g == Gender.male ? 'Male' : 'Female',
                        style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (g) => setState(() => _selectedGender = g),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildLabel('Date of Birth'),
            InkWell(
              onTap: _selectDateOfBirth,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar_1, color: _kGrey, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _dateOfBirth ?? 'Select Date of Birth',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: _dateOfBirth != null ? Colors.white : _kGrey,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: _kGrey, size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Save Button ───────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kLime,
                  foregroundColor: _kDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: _kDark, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Personal Details',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Syne',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kGrey, fontFamily: 'Poppins', fontSize: 13),
      prefixIcon: Icon(icon, color: _kGrey, size: 20),
      filled: true,
      fillColor: _kCardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kLime),
      ),
    );
  }
}
