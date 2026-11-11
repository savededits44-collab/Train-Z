import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/client_auth_controller.dart';
import '../widgets/client_gender_selector.dart';
import 'client_email_verification_screen.dart';
import 'client_login_screen.dart';

/// Premium Registration Screen for TRAIN Z Clients (Athletes seeking personal trainers).
class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ClientAuthController _authController = ClientAuthController();

  Gender? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = true;

  @override
  void initState() {
    super.initState();
    _authController.addListener(_onAuthControllerUpdate);
  }

  void _onAuthControllerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthControllerUpdate);
    _authController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (!_agreeToTerms) {
      _showToast('Please agree to the platform Terms & Privacy Policy.');
      return;
    }

    if (_selectedGender == null) {
      _showToast('Please select your gender to complete registration.');
      return;
    }

    final success = await _authController.registerClient(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      gender: _selectedGender,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClientEmailVerificationScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else if (_authController.errorMessage != null) {
      HapticFeedback.heavyImpact();
      _showToast(_authController.errorMessage!);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
          icon: const Icon(Iconsax.arrow_left, color: kDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
                SizedBox(height: (h * 0.015 * sf).clamp(10.0, 20.0)),

                // Role Identifier Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Client & Athlete Portal',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (11.0 * sf).clamp(10.0, 12.5),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Heading
                Text(
                  'Start your\ntransformation.',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (28.0 * sf).clamp(24.0, 36.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Create your account to train with verified 1-on-1 personal trainers.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.5 * sf).clamp(11.0, 14.0),
                    color: kGrey,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: (h * 0.03 * sf).clamp(20.0, 32.0)),

                // Full Name
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Iconsax.user,
                  keyboardType: TextInputType.name,
                ),

                const SizedBox(height: 14),

                // Email Address
                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Iconsax.sms,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 14),

                // Mobile Number
                AppTextField(
                  controller: _phoneController,
                  label: 'Mobile Number (+91)',
                  icon: Iconsax.call,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 18),

                // Gender Selection (Section 5: Matching rule)
                ClientGenderSelector(
                  selectedGender: _selectedGender,
                  onGenderSelected: (gender) {
                    setState(() => _selectedGender = gender);
                  },
                ),

                const SizedBox(height: 18),

                // Password
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Iconsax.lock,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                      size: (18.0 * sf).clamp(16.0, 22.0),
                      color: const Color(0xFFAAAAAA),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 14),

                // Confirm Password
                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Iconsax.lock_1,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                      size: (18.0 * sf).clamp(16.0, 22.0),
                      color: const Color(0xFFAAAAAA),
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),

                const SizedBox(height: 16),

                // Terms & Privacy Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreeToTerms,
                        activeColor: kDark,
                        checkColor: kLime,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onChanged: (val) => setState(() => _agreeToTerms = val ?? true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.5, 13.0),
                            color: kGrey,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kDark,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kDark,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: (h * 0.03 * sf).clamp(20.0, 32.0)),

                // Submit Button
                AppPrimaryButton(
                  label: 'Create Client Account',
                  loading: _authController.isLoading,
                  onTap: _handleRegister,
                ),

                const SizedBox(height: 20),

                // Link to Login
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (13.0 * sf).clamp(11.0, 14.5),
                          color: kGrey,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                          );
                        },
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (13.0 * sf).clamp(11.0, 14.5),
                            fontWeight: FontWeight.w700,
                            color: kDark,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

