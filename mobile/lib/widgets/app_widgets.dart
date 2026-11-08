import 'package:flutter/material.dart';

// ─── Shared design tokens ────────────────────────────────────────────────────
const kDark   = Color(0xFF111111);
const kLime   = Color(0xFFB2FF59);
const kGrey   = Color(0xFF999999);
const kField  = Color(0xFFF7F7F7);
const kBorder = Color(0xFFEEEEEE);

// ─── Responsive scale factor ─────────────────────────────────────────────────
double scaleFactor(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  return (w / 360).clamp(0.75, 1.3);
}

// ─── App logo (trainus|pro) ───────────────────────────────────────────────────
class AppLogo extends StatelessWidget {
  final double fontSize;
  const AppLogo({super.key, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Train',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: kDark,
              letterSpacing: fontSize * 0.04,
            ),
          ),
          TextSpan(
            text: 'Z',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: kLime,
              letterSpacing: fontSize * 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Responsive input field ───────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final fontSize  = (13.0 * sf).clamp(11.0, 15.0);
    final iconSize  = (17.0 * sf).clamp(14.0, 20.0);
    final radius    = (13.0 * sf).clamp(10.0, 16.0);
    final vPad      = (14.0 * sf).clamp(12.0, 18.0);

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: kDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: fontSize - 1,
          color: kGrey,
        ),
        prefixIcon: Icon(icon, size: iconSize, color: const Color(0xFFAAAAAA)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: kField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: kLime, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: iconSize * 0.9,
          vertical: vPad,
        ),
      ),
    );
  }
}

// ─── Primary black button ─────────────────────────────────────────────────────
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final sf        = scaleFactor(context);
    final h         = MediaQuery.of(context).size.height;
    final btnH      = (h * 0.062 * sf).clamp(44.0, 58.0);
    final fontSize  = (14.0 * sf).clamp(13.0, 16.0);
    final radius    = (13.0 * sf).clamp(10.0, 16.0);
    final iconSize  = (17.0 * sf).clamp(14.0, 20.0);

    return SizedBox(
      width: double.infinity,
      height: btnH,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kDark.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: loading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

// ─── Google G logo (CustomPainter, official colors) ───────────────────────────
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const double _pi = 3.14159265358979;
  static double _rad(double deg) => deg * _pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final r  = size.width / 2;
    final sw = r * 0.37;              // stroke width for the ring
    final ir = r - sw / 2;           // inner radius center of stroke

    final rect = Rect.fromCircle(
      center: Offset(r, r),
      radius: ir,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    // ── Ring segments (CW from 3-o'clock = 0°) ───────────────────────────
    // Blue   : from -88° → ~8°  (gap before crossbar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _rad(-88), _rad(96), false, paint);

    // Green  : 8° → 90°
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _rad(8), _rad(82), false, paint);

    // Yellow : 90° → 210°
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _rad(90), _rad(120), false, paint);

    // Red    : 210° → 272°
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _rad(210), _rad(62), false, paint);

    // ── Blue crossbar ─────────────────────────────────────────────────────
    final barH   = sw * 0.98;
    final barTop = r - barH / 2;
    final barLeft  = r + ir * 0.03;         // slightly past center
    final barRight = r + ir + sw / 2 - 1.0; // to outer edge

    final fillPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(barLeft, barTop, barRight, barTop + barH),
        const Radius.circular(1),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── or-divider row ───────────────────────────────────────────────────────────
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    return Row(
      children: [
        const Expanded(child: Divider(color: kBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: (12.0 * sf).clamp(8, 14)),
          child: Text(
            'or',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (12.0 * sf).clamp(10, 13),
              color: const Color(0xFFCCCCCC),
            ),
          ),
        ),
        const Expanded(child: Divider(color: kBorder)),
      ],
    );
  }
}

// ─── Google sign-in outlined button ──────────────────────────────────────────
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  const GoogleSignInButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sf       = scaleFactor(context);
    final h        = MediaQuery.of(context).size.height;
    final w        = MediaQuery.of(context).size.width;
    final btnH     = (h * 0.062 * sf).clamp(44.0, 58.0);
    final fontSize = (13.0 * sf).clamp(11.0, 15.0);
    final radius   = (13.0 * sf).clamp(10.0, 16.0);
    final logoSz   = (19.0 * sf).clamp(15.0, 22.0);

    return SizedBox(
      width: double.infinity,
      height: btnH,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GoogleLogo(size: logoSz),
            SizedBox(width: (w * 0.025).clamp(8, 12)),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

