import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import 'app_widgets.dart';

Future<void> showLogoutDialog(BuildContext context, {bool isTrainer = false}) async {
  final sf = scaleFactor(context);

  final bool? confirm = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (24.0 * sf).clamp(18.0, 32.0),
            vertical: (20.0 * sf).clamp(16.0, 28.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: (50.0 * sf).clamp(42, 58),
                height: (50.0 * sf).clamp(42, 58),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.logout,
                  color: Color(0xFFE53935),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (18.0 * sf).clamp(16.0, 22.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to log out of Trainuspro?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                ),
              ),
              SizedBox(height: (24.0 * sf).clamp(18.0, 32.0)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (13.0 * sf).clamp(11.0, 14.0),
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (13.0 * sf).clamp(11.0, 14.0),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );

  if (confirm == true && context.mounted) {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }
}

