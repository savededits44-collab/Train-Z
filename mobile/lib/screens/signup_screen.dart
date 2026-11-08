import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'client/client_dashboard.dart';
import 'login_screen.dart';
import 'onboarding/role_selection_screen.dart';
import 'trainer/trainer_dashboard.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeSlide;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

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

  void _navigateAfterAuth({
    String? role,
    required bool isOnboarded,
  }) {
    if (!mounted) return;
    if (isOnboarded && role != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => role == 'trainer'
              ? const TrainerDashboard()
              : const ClientDashboard(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
      );
    }
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
      );

      if (!mounted) return;
      setState(() => _loading = false);

      // New email signup goes directly to role selection onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
      );
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
      final credential = await AuthService().signInWithGoogle();
      if (!mounted) return;
      setState(() => _loading = false);

      if (credential == null) return; // User cancelled

      final user = credential.user;
      String? role;
      bool isOnboarded = false;

      if (user != null) {
        final profile = await AuthService().getUserProfile(user.uid);
        if (profile != null) {
          role = profile['role'] as String?;
          isOnboarded = profile['onboarded'] == true;
        }
      }

      if (!mounted) return;
      _navigateAfterAuth(
        role: role,
        isOnboarded: isOnboarded,
      );
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
                SizedBox(height: (h * 0.04 * sf).clamp(20.0, 40.0)),

                Text(
                  'Create an\naccount.',
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
                  'Join Trainzto connect with trainers and track your progress.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (13.0 * sf).clamp(11.0, 14.0),
                    color: kGrey,
                  ),
                ),

                SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

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
