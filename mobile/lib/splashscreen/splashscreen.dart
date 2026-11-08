import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

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
      duration: const Duration(milliseconds: 900),
    );

    // Pop-up spring scale: 0.6 → 1.0 with easeOutBack overshoot
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Fade in
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (ctx, a1, a2) => const LoginScreen(),
              transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
                opacity: anim,
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive font size: scales with screen width, clamped 18–30px
    final double screenWidth = MediaQuery.of(context).size.width;
    final double fontSize = (screenWidth * 0.055).clamp(18.0, 30.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            );
          },
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'train',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: fontSize * 0.07,
                  ),
                ),
                TextSpan(
                  text: 'z',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB2FF59),
                    letterSpacing: fontSize * 0.07,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
