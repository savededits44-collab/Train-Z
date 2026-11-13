import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';
import '../widgets/trainer_category_card.dart';
import 'trainer_registration_success_screen.dart';

class TrainerCategorySelectionScreen extends StatefulWidget {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String confirmPassword;

  const TrainerCategorySelectionScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.confirmPassword,
  });

  @override
  State<TrainerCategorySelectionScreen> createState() =>
      _TrainerCategorySelectionScreenState();
}

class _TrainerCategorySelectionScreenState
    extends State<TrainerCategorySelectionScreen> {
  final _trainerAuthController = TrainerAuthController();
  final _experienceController = TextEditingController(text: '3.5');

  TrainerCategory _selectedCategory = TrainerCategory.trainer;
  bool _hasConfirmedCertificate = false;
  bool _isLoading = false;
  String? _inlineError;

  @override
  void dispose() {
    _experienceController.dispose();
    _trainerAuthController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitApplication() async {
    setState(() {
      _inlineError = null;
    });

    double experienceYears = 0.0;
    if (_selectedCategory == TrainerCategory.advancedTrainer) {
      final parsed = double.tryParse(_experienceController.text.trim());
      if (parsed == null) {
        setState(() {
          _inlineError = 'Please enter a valid numeric value for years of experience.';
        });
        return;
      }
      experienceYears = parsed;
    }

    final validationError = _trainerAuthController.validateCategorySelection(
      category: _selectedCategory,
      experienceYears: experienceYears,
      hasConfirmedCertificate: _hasConfirmedCertificate,
    );

    if (validationError != null) {
      setState(() => _inlineError = validationError);
      return;
    }

    setState(() => _isLoading = true);

    final success = widget.password.isEmpty
        ? await _trainerAuthController.assignCategoryForCurrentTrainer(
            category: _selectedCategory,
            experienceYears: experienceYears,
            hasConfirmedCertificate: _hasConfirmedCertificate,
          )
        : await _trainerAuthController.registerTrainer(
            name: widget.fullName,
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            password: widget.password,
            confirmPassword: widget.confirmPassword,
            category: _selectedCategory,
            experienceYears: experienceYears,
            hasConfirmedCertificate: _hasConfirmedCertificate,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => TrainerRegistrationSuccessScreen(
            fullName: widget.fullName,
            email: widget.email,
            category: _selectedCategory,
            experienceYears: experienceYears,
          ),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _inlineError = _trainerAuthController.errorMessage ??
            'Registration could not be completed. Please try again.';
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AppLogo(fontSize: 16),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.015 * sf).clamp(8.0, 20.0)),

              // Step indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'STEP 2 OF 2',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kLime,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                'Select Trainer Category.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (26.0 * sf).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Choose the tier that matches your qualifications and coaching experience.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.5, 14.0),
                  color: kGrey,
                  height: 1.35,
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(18.0, 28.0)),

              if (_inlineError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Iconsax.warning_2,
                        color: Color(0xFFD32F2F),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Trainer (Standard)
              TrainerCategoryCard(
                category: TrainerCategory.trainer,
                isSelected: _selectedCategory == TrainerCategory.trainer,
                onTap: () {
                  setState(() {
                    _selectedCategory = TrainerCategory.trainer;
                    _inlineError = null;
                  });
                },
              ),

              const SizedBox(height: 14),

              // 2. Advanced Trainer
              TrainerCategoryCard(
                category: TrainerCategory.advancedTrainer,
                isSelected: _selectedCategory == TrainerCategory.advancedTrainer,
                onTap: () {
                  setState(() {
                    _selectedCategory = TrainerCategory.advancedTrainer;
                    _inlineError = null;
                  });
                },
              ),

              if (_selectedCategory == TrainerCategory.advancedTrainer) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Years of Relevant Coaching Experience (Min. 3.5 Years Required):',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _experienceController,
                        label: 'Experience in years (e.g. 4.0)',
                        icon: Iconsax.clock,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 3. Professional Trainer (Coming Soon)
              TrainerCategoryCard(
                category: TrainerCategory.professionalTrainer,
                isSelected: _selectedCategory == TrainerCategory.professionalTrainer,
                onTap: null, // Disabled
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 24.0)),

              // Confirmation Checkbox
              InkWell(
                onTap: () =>
                    setState(() => _hasConfirmedCertificate = !_hasConfirmedCertificate),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _hasConfirmedCertificate,
                        activeColor: kDark,
                        checkColor: kLime,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() => _hasConfirmedCertificate = val ?? false);
                        },
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _selectedCategory == TrainerCategory.advancedTrainer
                                ? 'I confirm I possess relevant professional certificates and qualifications & at least 3.5 years of training experience. I understand that Advanced Trainer status requires Admin verification of private certificates.'
                                : 'I agree to the standard TRAIN Z predefined package guidelines and platform terms.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (12.0 * sf).clamp(11.0, 13.0),
                              color: kDark,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(20.0, 36.0)),

              AppPrimaryButton(
                label: 'Submit Application',
                loading: _isLoading,
                onTap: _handleSubmitApplication,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

