import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';
import 'trainer_category_selection_screen.dart';
import 'trainer_login_screen.dart';

class TrainerRegisterScreen extends StatefulWidget {
  const TrainerRegisterScreen({super.key});

  @override
  State<TrainerRegisterScreen> createState() => _TrainerRegisterScreenState();
}

class _TrainerRegisterScreenState extends State<TrainerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _trainerAuthController = TrainerAuthController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _inlineError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _trainerAuthController.dispose();
    super.dispose();
  }

  void _proceedToCategorySelection() {
    setState(() => _inlineError = null);

    final error = _trainerAuthController.validateRegistrationForm(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (error != null) {
      setState(() => _inlineError = error);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerCategorySelectionScreen(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        ),
      ),
    );
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: (h * 0.015 * sf).clamp(8.0, 20.0)),

                // Badge: Trainer Partner Network
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'COACH / TRAINER PORTAL',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kLime,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Join as a Trainer.',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (28.0 * sf).clamp(24.0, 34.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Create your professional coaching profile and begin your application for TRAIN Z partnership.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (13.0 * sf).clamp(11.5, 14.0),
                    color: kGrey,
                    height: 1.35,
                  ),
                ),

                SizedBox(height: (h * 0.03 * sf).clamp(18.0, 30.0)),

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

                // 1. Full Name
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Iconsax.user,
                  keyboardType: TextInputType.name,
                ),

                SizedBox(height: (12.0 * sf).clamp(10.0, 16.0)),

                // 2. Email Address
                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Iconsax.sms,
                  keyboardType: TextInputType.emailAddress,
                ),

                SizedBox(height: (12.0 * sf).clamp(10.0, 16.0)),

                // 3. Phone Number
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone Number (e.g. +91 9876543210)',
                  icon: Iconsax.call,
                  keyboardType: TextInputType.phone,
                ),

                SizedBox(height: (12.0 * sf).clamp(10.0, 16.0)),

                // 4. Password
                AppTextField(
                  controller: _passwordController,
                  label: 'Password (min. 6 characters)',
                  icon: Iconsax.lock,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                      size: 18,
                      color: kGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                SizedBox(height: (12.0 * sf).clamp(10.0, 16.0)),

                // 5. Confirm Password
                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Iconsax.lock_1,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                      size: 18,
                      color: kGrey,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),

                SizedBox(height: (h * 0.04 * sf).clamp(24.0, 42.0)),

                // Continue Button
                AppPrimaryButton(
                  label: 'Select Trainer Category',
                  onTap: _proceedToCategorySelection,
                ),

                SizedBox(height: (h * 0.03 * sf).clamp(16.0, 28.0)),

                // Already registered link
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already registered as trainer? ',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (12.5 * sf).clamp(11.0, 13.5),
                          color: kGrey,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const TrainerLoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (12.5 * sf).clamp(11.0, 13.5),
                            fontWeight: FontWeight.w700,
                            color: kDark,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

