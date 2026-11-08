import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'login_screen.dart';
import 'onboarding/client_onboarding.dart';
import 'onboarding/trainer_onboarding.dart';

class SignupScreen extends StatefulWidget {
  final bool initialIsTrainer;

  const SignupScreen({super.key, this.initialIsTrainer = false});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeSlide;

  late bool _isTrainer;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isTrainer = widget.initialIsTrainer;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeSlide = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields.'),
          backgroundColor: Color(0xFF111111),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password should be at least 6 characters.'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService().signUpWithEmail(
        name: name,
        email: email,
        password: password,
        isTrainer: _isTrainer,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (_isTrainer) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TrainerOnboardingScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClientOnboardingScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg = 'Signup failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        msg = 'An account already exists for this email.';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address is badly formatted.';
      } else if (e.code == 'weak-password') {
        msg = 'The password is too weak.';
      } else if (e.message != null) {
        msg = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  void _handleGoogleSignup() async {
    setState(() => _loading = true);
    try {
      final credential = await AuthService().signInWithGoogle(isTrainer: _isTrainer);
      if (!mounted) return;
      setState(() => _loading = false);

      if (credential == null) return; // User cancelled

      if (_isTrainer) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TrainerOnboardingScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClientOnboardingScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeSlide,
          builder: (context, child) => Opacity(
            opacity: _fadeSlide.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _fadeSlide.value)),
              child: child,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: (h * 0.045 * sf).clamp(24.0, 48.0)),
                const AppLogo(fontSize: 16),
                SizedBox(height: (h * 0.035 * sf).clamp(16.0, 36.0)),

                // Role selector toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isTrainer = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isTrainer ? kDark : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.user,
                                  size: 16,
                                  color: !_isTrainer ? kLime : const Color(0xFF999999),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Client / Athlete',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (12.0 * sf).clamp(11.0, 13.0),
                                    fontWeight: FontWeight.w700,
                                    color: !_isTrainer ? Colors.white : const Color(0xFF888888),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isTrainer = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isTrainer ? kDark : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.teacher,
                                  size: 16,
                                  color: _isTrainer ? kLime : const Color(0xFF999999),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Coach / Trainer',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (12.0 * sf).clamp(11.0, 13.0),
                                    fontWeight: FontWeight.w700,
                                    color: _isTrainer ? Colors.white : const Color(0xFF888888),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.03 * sf).clamp(14.0, 28.0)),

                Text(
                  _isTrainer ? 'Join as a\nTrainer.' : 'Create an\naccount.',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (30.0 * sf).clamp(24.0, 38.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isTrainer
                      ? 'Reach clients and grow your fitness career.'
                      : 'Find top trainers and achieve peak performance.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (13.0 * sf).clamp(11.0, 14.0),
                    color: kGrey,
                  ),
                ),

                SizedBox(height: (h * 0.03 * sf).clamp(16.0, 32.0)),

                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Iconsax.user,
                ),

                SizedBox(height: (12.0 * sf).clamp(8.0, 14.0)),

                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  icon: Iconsax.sms,
                ),

                SizedBox(height: (12.0 * sf).clamp(8.0, 14.0)),

                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscure: _obscurePassword,
                  icon: Iconsax.lock,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                      size: 18,
                      color: const Color(0xFFAAAAAA),
                    ),
                  ),
                ),

                SizedBox(height: (h * 0.035 * sf).clamp(18.0, 32.0)),

                AppPrimaryButton(
                  label: 'Create Account',
                  loading: _loading,
                  onTap: _handleSignup,
                ),

                SizedBox(height: (14.0 * sf).clamp(10.0, 18.0)),
                const OrDivider(),
                SizedBox(height: (14.0 * sf).clamp(10.0, 18.0)),

                GoogleSignInButton(
                  onTap: _handleGoogleSignup,
                ),

                SizedBox(height: (h * 0.04 * sf).clamp(20.0, 36.0)),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Already have an account?  ',
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
                              builder: (_) => const LoginScreen(),
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

