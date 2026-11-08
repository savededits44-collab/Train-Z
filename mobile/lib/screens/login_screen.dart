import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'client/client_dashboard.dart';
import 'signup_screen.dart';
import 'trainer/trainer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final bool initialIsTrainer;

  const LoginScreen({super.key, this.initialIsTrainer = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeSlide;

  late bool _isTrainer;
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
      duration: const Duration(milliseconds: 700),
    );
    _fadeSlide = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password.'),
          backgroundColor: Color(0xFF111111),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = await AuthService().signInWithEmail(
        email: email,
        password: password,
      );

      final user = credential.user;
      bool targetIsTrainer = _isTrainer;

      if (user != null) {
        final profile = await AuthService().getUserProfile(user.uid);
        if (profile != null && profile['role'] != null) {
          targetIsTrainer = profile['role'] == 'trainer';
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);

      if (!mounted) return;
      if (targetIsTrainer) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TrainerDashboard()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClientDashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg = 'Authentication failed. Please check your credentials.';
      if (e.code == 'user-not-found') {
        msg = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        msg = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address is badly formatted.';
      } else if (e.code == 'invalid-credential') {
        msg = 'Invalid email or password.';
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
          content: Text('Sign-in error: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  void _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      final credential = await AuthService().signInWithGoogle(isTrainer: _isTrainer);
      if (!mounted) return;
      setState(() => _loading = false);

      if (credential == null) return; // User cancelled

      final user = credential.user;
      bool targetIsTrainer = _isTrainer;

      if (user != null) {
        final profile = await AuthService().getUserProfile(user.uid);
        if (profile != null && profile['role'] != null) {
          targetIsTrainer = profile['role'] == 'trainer';
        }
      }

      if (!mounted) return;
      if (targetIsTrainer) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TrainerDashboard()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClientDashboard()),
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
    final mq = MediaQuery.of(context);
    final double w = mq.size.width;
    final double h = mq.size.height;
    final double sf = scaleFactor(context);

    final double hPad = (w * 0.072).clamp(18.0, 32.0);
    final double topGap = (h * 0.045 * sf).clamp(24.0, 48.0);
    final double headingTop = (h * 0.03 * sf).clamp(14.0, 28.0);
    final double afterSub = (h * 0.035 * sf).clamp(16.0, 32.0);
    final double fieldGap = (h * 0.016 * sf).clamp(10.0, 16.0);
    final double btnTop = (h * 0.030 * sf).clamp(16.0, 30.0);
    final double divGap = (h * 0.018 * sf).clamp(10.0, 18.0);
    final double headingSize = (32.0 * sf).clamp(24.0, 38.0);
    final double subSize = (13.0 * sf).clamp(11.0, 14.0);

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
                SizedBox(height: topGap),

                const AppLogo(fontSize: 16),

                SizedBox(height: (h * 0.03 * sf).clamp(14.0, 26.0)),

                // Role selector pill
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

                SizedBox(height: headingTop),

                Text(
                  _isTrainer ? 'Trainer\nPortal.' : 'Welcome\nback.',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: headingSize,
                    fontWeight: FontWeight.w800,
                    color: kDark,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _isTrainer
                      ? 'Sign in to manage your athletes & sessions.'
                      : 'Sign in to access your workout plan & trainers.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: subSize,
                    fontWeight: FontWeight.w400,
                    color: kGrey,
                  ),
                ),

                SizedBox(height: afterSub),

                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  icon: Iconsax.sms,
                ),

                SizedBox(height: fieldGap),

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

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: subSize - 1,
                        fontWeight: FontWeight.w500,
                        color: kDark,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: btnTop),

                AppPrimaryButton(
                  label: 'Log In',
                  loading: _loading,
                  onTap: _handleLogin,
                ),

                SizedBox(height: divGap),
                const OrDivider(),
                SizedBox(height: divGap),

                GoogleSignInButton(
                  onTap: _handleGoogleLogin,
                ),

                SizedBox(height: (h * 0.045 * sf).clamp(20.0, 38.0)),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Don't have an account?  ",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: subSize - 1,
                          color: kGrey,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => SignupScreen(
                                initialIsTrainer: _isTrainer,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: subSize - 1,
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
