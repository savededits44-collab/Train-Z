import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/booking_model.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/notifications_bottom_sheet.dart';
import '../../widgets/trainer_animations.dart';
import '../../widgets/trainer_session_card.dart';
import 'trainer_profile_setup_screen.dart';
import 'trainer_schedule_section.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  int _tab = 0;

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
  }

  void _onLogout() {
    showLogoutDialog(context, isTrainer: true);
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final pages = [
      _TrainerHomeTab(
        sf: sf,
        onLogout: _onLogout,
        onGoToSchedule: () => setState(() => _tab = 2),
      ),
      _TrainerClientsTab(sf: sf, onGoToSchedule: () => setState(() => _tab = 2)),
      _TrainerScheduleTab(sf: sf),
      _TrainerProfileTab(sf: sf, onLogout: _onLogout),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_tab),
          child: pages[_tab],
        ),
      ),
      bottomNavigationBar: _TrainerBottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
        sf: sf,
      ),
    );
  }
}

// ── Trainer Home Tab ──────────────────────────────────────────────────────────
class _TrainerHomeTab extends StatelessWidget {
  final double sf;
  final VoidCallback onLogout;
  final VoidCallback onGoToSchedule;

  const _TrainerHomeTab({
    required this.sf,
    required this.onLogout,
    required this.onGoToSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final h    = MediaQuery.of(context).size.height;
    final w    = MediaQuery.of(context).size.width;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: (h * 0.03).clamp(16, 28)),

            // Header with luxury entrance animation
            TrainerFadeSlide(
              delayMs: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppLogo(fontSize: (14.0 * sf).clamp(12, 18)),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (10.0 * sf).clamp(8, 14),
                          vertical: (5.0 * sf).clamp(4, 8),
                        ),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular((8.0 * sf).clamp(6, 10)),
                        ),
                        child: Text(
                          'Trainer',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (11.0 * sf).clamp(9, 13),
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                      ),
                      SizedBox(width: (8.0 * sf).clamp(6, 12)),
                      TrainerPressScale(
                        onTap: () => NotificationsBottomSheet.show(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: (36.0 * sf).clamp(30, 44),
                              height: (36.0 * sf).clamp(30, 44),
                              decoration: const BoxDecoration(
                                color: kField,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Iconsax.notification,
                                size: (18.0 * sf).clamp(14, 22),
                                color: kDark,
                              ),
                            ),
                            ListenableBuilder(
                              listenable: NotificationService.instance,
                              builder: (context, _) {
                                final count = NotificationService.instance.unreadCount;
                                if (count == 0) return const SizedBox.shrink();
                                return Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDC2626),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Center(
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontFamily: 'Syne',
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quick logout
                      TrainerPressScale(
                        onTap: onLogout,
                        child: Container(
                          width: (36.0 * sf).clamp(30, 44),
                          height: (36.0 * sf).clamp(30, 44),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.logout,
                            size: (17.0 * sf).clamp(14, 20),
                            color: const Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: (h * 0.03).clamp(16, 28)),

            // Title with smooth stagger
            TrainerFadeSlide(
              delayMs: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your dashboard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (13.0 * sf).clamp(11, 15),
                      color: kGrey,
                    ),
                  ),
                  SizedBox(height: (4.0 * sf).clamp(2, 6)),
                  Text(
                    'Build your\nclientele.',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (26.0 * sf).clamp(20, 32),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            // Stats row (Live Real-Time with rolling counters & spring scale)
            TrainerFadeSlide(
              delayMs: 140,
              child: ListenableBuilder(
                listenable: BookingService.instance,
                builder: (context, _) {
                  final bService = BookingService.instance;
                  final confirmedCount = bService.confirmedBookings.length;
                  final uniqueClients = bService.confirmedBookings
                      .map((b) => b.displayClientName)
                      .toSet()
                      .length;

                  return Row(
                    children: [
                      Expanded(
                        child: _TStatCard(
                          label: 'Clients',
                          value: '$uniqueClients',
                          icon: Iconsax.people,
                          sf: sf,
                        ),
                      ),
                      SizedBox(width: (10.0 * sf).clamp(8, 14)),
                      Expanded(
                        child: _TStatCard(
                          label: 'Sessions',
                          value: '$confirmedCount',
                          icon: Iconsax.calendar_tick,
                          sf: sf,
                          accent: true,
                        ),
                      ),
                      SizedBox(width: (10.0 * sf).clamp(8, 14)),
                      Expanded(
                        child: _TStatCard(
                          label: 'Rating',
                          value: '5.0',
                          icon: Iconsax.star,
                          sf: sf,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            SizedBox(height: (h * 0.02).clamp(12, 20)),

            // Today's Income Box Column (Live Real-Time Daily Revenue with pulsing glow)
            TrainerFadeSlide(
              delayMs: 200,
              child: _TrainerTodaysIncomeCard(
                sf: sf,
                onGoToSchedule: onGoToSchedule,
              ),
            ),

            SizedBox(height: (h * 0.02).clamp(12, 20)),

            // Dynamic Trainer Status Card (Profile Setup, Application In Process, or Approved)
            TrainerFadeSlide(
              delayMs: 260,
              child: ListenableBuilder(
                listenable: TrainerProfileService.instance,
                builder: (context, _) {
                  final service = TrainerProfileService.instance;
                  final isDone = service.isProfileCompleted;
                  final isPending = service.isPendingApproval;
                  final isApproved = service.isApproved;

                Widget content;

                if (!isDone) {
                  // State 1: Incomplete Profile Setup
                  content = InkWell(
                    borderRadius: BorderRadius.circular((16.0 * sf).clamp(12, 20)),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrainerProfileSetupScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all((18.0 * sf).clamp(14, 24)),
                      decoration: BoxDecoration(
                        color: kDark,
                        borderRadius:
                            BorderRadius.circular((16.0 * sf).clamp(12, 20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete your profile',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (15.0 * sf).clamp(12, 18),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: (4.0 * sf).clamp(2, 6)),
                                Text(
                                  'Attract more clients with a full profile.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (11.0 * sf).clamp(9, 13),
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                                SizedBox(height: (12.0 * sf).clamp(8, 16)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: (14.0 * sf).clamp(10, 18),
                                    vertical: (8.0 * sf).clamp(6, 10),
                                  ),
                                  decoration: BoxDecoration(
                                    color: kLime,
                                    borderRadius:
                                        BorderRadius.circular((8.0 * sf).clamp(6, 10)),
                                  ),
                                  child: Text(
                                    'Set up now',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (12.0 * sf).clamp(10, 14),
                                      fontWeight: FontWeight.w700,
                                      color: kDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Iconsax.profile_tick,
                            size: (48.0 * sf).clamp(36, 60),
                            color: kLime.withValues(alpha: 0.15),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (isPending) {
                  // State 2: Application in Process (Under Admin Review)
                  content = Container(
                    width: double.infinity,
                    padding: EdgeInsets.all((16.0 * sf).clamp(14, 22)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF5),
                      borderRadius: BorderRadius.circular((16.0 * sf).clamp(12, 20)),
                      border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFB300)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Iconsax.clock, size: 12, color: Color(0xFFE65100)),
                              SizedBox(width: 5),
                              Text(
                                'Under Admin Review',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your Application is in Process',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (16.0 * sf).clamp(14.0, 18.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Your profile details and credentials have been submitted to the TrainZ Admin. While the Admin is deciding on your application, session booking acceptance is temporarily on hold. You will be notified once approved.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.0, 13.0),
                            color: const Color(0xFF6D4C41),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (isApproved) {
                  // State 3: Approved & Eligible to Give Service on TrainZ
                  content = Container(
                    width: double.infinity,
                    padding: EdgeInsets.all((16.0 * sf).clamp(14, 22)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular((16.0 * sf).clamp(12, 20)),
                      border: Border.all(color: const Color(0xFF66BB6A), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF81C784)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Verified & Approved',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kLime,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Active Coach',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You are approved!',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (17.0 * sf).clamp(15.0, 20.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are approved and now eligible to give your service on TrainZ.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (12.0 * sf).clamp(10.5, 13.5),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your profile and credentials have been verified. You can now accept client bookings and start coaching athletes.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.0, 12.5),
                            color: kGrey,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: onGoToSchedule,
                          icon: const Icon(Iconsax.calendar_tick, size: 15, color: kDark),
                          label: const Text(
                            'View Session Requests',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLime,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // State 4: Rejected
                  content = Container(
                    width: double.infinity,
                    padding: EdgeInsets.all((16.0 * sf).clamp(14, 22)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular((16.0 * sf).clamp(12, 20)),
                      border: Border.all(color: const Color(0xFFE53935), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.cancel_rounded, color: Color(0xFFC62828), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Application Rejected',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reason: ${service.adminNotes ?? "Credentials could not be verified."}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TrainerProfileSetupScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'Update Profile & Re-submit',
                            style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    content,
                    SizedBox(height: (h * 0.025).clamp(14, 24)),
                  ],
                );
              },
            ),
          ),

            // Live Upcoming Sessions & Booking Requests
            TrainerFadeSlide(
              delayMs: 320,
              child: ListenableBuilder(
                listenable: BookingService.instance,
                builder: (context, _) {
                  final bService = BookingService.instance;
                  final pending = bService.pendingBookings;
                  final confirmed = bService.confirmedBookings;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Upcoming Sessions',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (15.0 * sf).clamp(13, 18),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          if (pending.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF9800),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${pending.length} pending',
                                    style: const TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: (h * 0.015).clamp(10, 18)),
                      if (pending.isNotEmpty) ...[
                        ...pending.map((b) => TrainerSessionCard(booking: b, sf: sf, compact: true)),
                      ],
                      if (confirmed.isNotEmpty) ...[
                        ...confirmed.take(2).map((b) => TrainerSessionCard(booking: b, sf: sf, compact: true)),
                      ],
                      if (pending.isEmpty && confirmed.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all((20.0 * sf).clamp(14, 24)),
                          decoration: BoxDecoration(
                            color: kField,
                            borderRadius:
                                BorderRadius.circular((14.0 * sf).clamp(10, 18)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Iconsax.calendar_remove,
                                size: (32.0 * sf).clamp(24, 42),
                                color: const Color(0xFFCCCCCC),
                              ),
                              SizedBox(height: (8.0 * sf).clamp(6, 12)),
                              Text(
                                'No sessions yet',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (12.0 * sf).clamp(10, 14),
                                  color: const Color(0xFFBBBBBB),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            SizedBox(height: (h * 0.03).clamp(20, 32)),
          ],
        ),
      ),
    );
  }
}

class _TStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double sf;
  final bool accent;

  const _TStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.sf,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final numValue = num.tryParse(value);

    return TrainerPressScale(
      child: Container(
        padding: EdgeInsets.all((14.0 * sf).clamp(10, 18)),
        decoration: BoxDecoration(
          color: accent ? kLime : kField,
          borderRadius: BorderRadius.circular((14.0 * sf).clamp(10, 18)),
          boxShadow: accent
              ? [
                  BoxShadow(
                    color: kLime.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: (18.0 * sf).clamp(14, 22),
              color: kDark,
            ),
            SizedBox(height: (6.0 * sf).clamp(4, 10)),
            if (numValue != null)
              TrainerCountUp(
                value: numValue,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (20.0 * sf).clamp(16, 26),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              )
            else
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (20.0 * sf).clamp(16, 26),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),
            SizedBox(height: (2.0 * sf).clamp(1, 4)),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (10.0 * sf).clamp(9, 12),
                color: accent ? kDark.withValues(alpha: 0.6) : kGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trainer Today's Income Card (Box-Type Column Container) ─────────────────
class _TrainerTodaysIncomeCard extends StatelessWidget {
  final double sf;
  final VoidCallback onGoToSchedule;

  const _TrainerTodaysIncomeCard({
    required this.sf,
    required this.onGoToSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BookingService.instance,
        TrainerProfileService.instance,
      ]),
      builder: (context, _) {
        final bService = BookingService.instance;
        final pService = TrainerProfileService.instance;
        final income = bService.todaysIncome;
        final todayConfirmed = bService.todayConfirmedBookings;
        final todayCount = todayConfirmed.length;
        final rate = pService.hourlyRate;

        return TrainerBreathingGlow(
          glowColor: kLime,
          active: true,
          minBlur: 4,
          maxBlur: 14,
          borderRadius: (18.0 * sf).clamp(14.0, 22.0),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all((18.0 * sf).clamp(14.0, 22.0)),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular((18.0 * sf).clamp(14.0, 22.0)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Icon + Title + Real-Time Badge
                Row(
                  children: [
                    Container(
                      width: (34.0 * sf).clamp(28.0, 40.0),
                      height: (34.0 * sf).clamp(28.0, 40.0),
                      decoration: BoxDecoration(
                        color: kLime,
                        borderRadius: BorderRadius.circular((10.0 * sf).clamp(8.0, 12.0)),
                      ),
                      child: Icon(
                        Iconsax.wallet_3,
                        size: (18.0 * sf).clamp(14.0, 22.0),
                        color: kDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY'S INCOME",
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (11.0 * sf).clamp(9.5, 12.5),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: kLime,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Estimated Daily Earnings',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(9.5, 12.0),
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          TrainerLivePulseDot(
                            color: Color(0xFF4CAF50),
                            size: 6.5,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Live',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: (16.0 * sf).clamp(12.0, 20.0)),

                // Big Revenue Display + Rate Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (22.0 * sf).clamp(18.0, 26.0),
                        fontWeight: FontWeight.w800,
                        color: kLime,
                      ),
                    ),
                    const SizedBox(width: 3),
                    TrainerCountUp(
                      value: income,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (34.0 * sf).clamp(28.0, 40.0),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kLime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kLime.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        '₹$rate / Session',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (11.0 * sf).clamp(9.5, 12.5),
                          fontWeight: FontWeight.w700,
                          color: kLime,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: (14.0 * sf).clamp(10.0, 18.0)),

                // Subtle Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),

                SizedBox(height: (12.0 * sf).clamp(8.0, 14.0)),

                // Footer Status & Quick Action
                if (income > 0)
                  Row(
                    children: [
                      const Icon(
                        Iconsax.tick_circle,
                        size: 14,
                        color: Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$todayCount session${todayCount == 1 ? '' : 's'} accepted for today',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.0, 12.5),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      TrainerPressScale(
                        onTap: onGoToSchedule,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Schedule',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (11.0 * sf).clamp(9.5, 12.0),
                                fontWeight: FontWeight.w700,
                                color: kLime,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: kLime,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '0 sessions accepted today',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(9.5, 12.0),
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      TrainerPressScale(
                        onTap: onGoToSchedule,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'View Requests',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (10.5 * sf).clamp(9.0, 11.5),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Trainer Schedule & Live Session Requests Tab ─────────────────────────────
class _TrainerScheduleTab extends StatelessWidget {
  final double sf;
  const _TrainerScheduleTab({required this.sf});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: TrainerScheduleSection(sf: sf),
    );
  }
}

// ── Trainer Profile Tab with Log Out ──────────────────────────────────────────
class _TrainerProfileTab extends StatelessWidget {
  final double sf;
  final VoidCallback onLogout;

  const _TrainerProfileTab({
    required this.sf,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return SafeArea(
      child: ListenableBuilder(
        listenable: TrainerProfileService.instance,
        builder: (context, _) {
          final service = TrainerProfileService.instance;
          final isPending = service.isPendingApproval;
          final isApproved = service.isApproved;
          final isRejected = service.isRejected;
          final photoPath = service.photoPath;
          final hasPhoto = photoPath != null && File(photoPath).existsSync();

          final badgeColor = isApproved
              ? kLime
              : isPending
                  ? const Color(0xFFFFECB3)
                  : isRejected
                      ? const Color(0xFFFFCDD2)
                      : const Color(0xFFFFECB3);

          final badgeText = isApproved
              ? 'Verified Coach'
              : isPending
                  ? 'Application In Process'
                  : isRejected
                      ? 'Application Rejected'
                      : 'Setup Pending';

          final badgeTextColor = isRejected ? const Color(0xFFB71C1C) : kDark;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: TrainerFadeSlide(
              delayMs: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Coach Profile',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (24.0 * sf).clamp(20.0, 30.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Main Profile Header Card (Live Photo + Name + Phone) ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      // Avatar / Live Photo
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TrainerProfileSetupScreen(),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kDark,
                                border: Border.all(
                                  color: hasPhoto ? kLime : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipOval(
                                child: hasPhoto
                                    ? Image.file(
                                        File(photoPath),
                                        fit: BoxFit.cover,
                                        width: 64,
                                        height: 64,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Iconsax.user, color: kLime, size: 30),
                                      )
                                    : const Icon(Iconsax.user, color: kLime, size: 30),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: kDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Iconsax.camera, color: kLime, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.fullName ?? 'Coach Profile',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (16.0 * sf).clamp(14.0, 18.0),
                                fontWeight: FontWeight.w700,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              service.mobileNumber ?? 'Mobile number not added',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (12.0 * sf).clamp(10.5, 13.0),
                                color: kGrey,
                              ),
                            ),
                            if (service.gymName != null && service.gymName!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Iconsax.building, size: 13, color: kDark),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      service.gymName!,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: (11.5 * sf).clamp(10.0, 12.5),
                                        fontWeight: FontWeight.w500,
                                        color: kDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.edit_2, size: 18, color: kDark),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TrainerProfileSetupScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Coaching Details & Credentials ──
                Text(
                  'Coaching Identity',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.5, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Iconsax.building,
                        title: 'Gym / Fitness Studio',
                        value: service.gymName ?? 'Not specified yet',
                        sf: sf,
                      ),
                      const Divider(height: 20, color: kBorder),
                      _DetailRow(
                        icon: Iconsax.user,
                        title: 'Age',
                        value: service.age != null && service.age!.isNotEmpty
                            ? '${service.age} Years Old'
                            : 'Not set',
                        sf: sf,
                      ),
                      const Divider(height: 20, color: kBorder),
                      _DetailRow(
                        icon: Iconsax.clock,
                        title: 'Working Since',
                        value: service.sinceWhen ?? 'Not specified',
                        sf: sf,
                      ),
                      const Divider(height: 20, color: kBorder),
                      _DetailRow(
                        icon: Iconsax.award,
                        title: 'Experience',
                        value: service.experience,
                        sf: sf,
                      ),
                      const Divider(height: 20, color: kBorder),
                      _DetailRow(
                        icon: Iconsax.call,
                        title: 'Contact Phone',
                        value: service.mobileNumber ?? 'Not added',
                        sf: sf,
                      ),
                      const Divider(height: 20, color: kBorder),
                      _DetailRow(
                        icon: Iconsax.document_text,
                        title: 'Certification',
                        value: service.certificatePath != null && service.certificatePath!.isNotEmpty
                            ? 'Uploaded (Document Attached)'
                            : 'Not uploaded (Optional)',
                        sf: sf,
                      ),
                      const Divider(height: 20, color: kBorder),
                      _DetailRow(
                        icon: Icons.shield_rounded,
                        title: 'Verification Status',
                        value: isApproved
                            ? 'Approved & Eligible on TrainZ'
                            : isPending
                                ? 'Application In Process'
                                : isRejected
                                    ? 'Rejected by Admin'
                                    : 'Profile Incomplete',
                        sf: sf,
                      ),
                    ],
                  ),
                ),

                if (service.certificatePath != null &&
                    File(service.certificatePath!).existsSync()) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(service.certificatePath!),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Iconsax.award, color: kDark, size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Coaching Credential Attached',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Syne',
                                        fontSize: (12.0 * sf).clamp(11.0, 13.0),
                                        fontWeight: FontWeight.w700,
                                        color: kDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                service.certificatePath!.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: kGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TrainerProfileSetupScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: kDark,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Specialties ──
                Text(
                  'Specialties',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.5, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: service.specialties.map((spec) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: kLime, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            spec,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.5 * sf).clamp(10.0, 12.5),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Training Philosophy ──
                Text(
                  'Training Philosophy',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.5, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Iconsax.quote_down, size: 18, color: kDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          service.philosophy,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (12.5 * sf).clamp(11.0, 13.5),
                            fontStyle: FontStyle.italic,
                            color: kDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Coach Settings ──
                Text(
                  'Coach Settings',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (14.0 * sf).clamp(12.5, 16.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 12),
                _CoachProfileTile(
                  icon: Iconsax.user_edit,
                  label: 'Edit Coach Profile & Photo',
                  sf: sf,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TrainerProfileSetupScreen(),
                      ),
                    );
                  },
                ),
                _CoachProfileTile(
                  icon: Iconsax.card,
                  label: 'Payout & Earnings',
                  sf: sf,
                  onTap: () {},
                ),
                _CoachProfileTile(
                  icon: Iconsax.calendar_edit,
                  label: 'Availability & Slots',
                  sf: sf,
                  onTap: () {},
                ),
                _CoachProfileTile(
                  icon: Iconsax.notification,
                  label: 'Notification Settings',
                  sf: sf,
                  onTap: () {},
                ),
                _CoachProfileTile(
                  icon: Iconsax.shield_tick,
                  label: 'Security & Certifications',
                  sf: sf,
                  onTap: () {},
                ),

                const SizedBox(height: 28),

                // Prominent Log Out Button
                SizedBox(
                  width: double.infinity,
                  height: (50.0 * sf).clamp(44.0, 56.0),
                  child: ElevatedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Iconsax.logout, size: 18, color: Color(0xFFE53935)),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double sf;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kDark),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (12.0 * sf).clamp(10.5, 13.0),
            color: kGrey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (12.5 * sf).clamp(11.0, 13.5),
              fontWeight: FontWeight.w600,
              color: kDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double sf;
  final VoidCallback? onTap;

  const _CoachProfileTile({
    required this.icon,
    required this.label,
    required this.sf,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: kDark),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (13.0 * sf).clamp(11.0, 14.0),
                    fontWeight: FontWeight.w500,
                    color: kDark,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBBBBBB)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _TrainerBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final double sf;

  const _TrainerBottomNav({
    required this.current,
    required this.onTap,
    required this.sf,
  });

  static final _items = [
    (Iconsax.home_2, Iconsax.home_2, 'Home'),
    (Iconsax.people, Iconsax.people, 'Clients'),
    (Iconsax.calendar, Iconsax.calendar_tick, 'Schedule'),
    (Iconsax.profile_circle, Iconsax.profile_circle, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final iconSz  = (22.0 * sf).clamp(18.0, 26.0);
    final labelSz = (10.0 * sf).clamp(9.0, 12.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final selected = i == current;
            final item = _items[i];
            return Expanded(
              child: TrainerPressScale(
                scaleDown: 0.92,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: (10.0 * sf).clamp(8, 14)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          selected ? item.$2 : item.$1,
                          size: iconSz,
                          color: selected ? kDark : const Color(0xFFBBBBBB),
                        ),
                      ),
                      SizedBox(height: (3.0 * sf).clamp(2, 4)),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: labelSz,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected ? kDark : const Color(0xFFBBBBBB),
                        ),
                        child: Text(item.$3),
                      ),
                      SizedBox(height: (3.0 * sf).clamp(2, 4)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        height: 3,
                        width: selected ? (22.0 * sf).clamp(16, 26) : 0,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: kLime.withValues(alpha: 0.6),
                                    blurRadius: 4,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Trainer My Clients Tab (Live Accepted Bookings) ───────────────────────────
class _TrainerClientsTab extends StatelessWidget {
  final double sf;
  final VoidCallback onGoToSchedule;

  const _TrainerClientsTab({
    required this.sf,
    required this.onGoToSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return SafeArea(
      child: ListenableBuilder(
        listenable: BookingService.instance,
        builder: (context, _) {
          final accepted = BookingService.instance.confirmedBookings;
          final uniqueClientsCount =
              accepted.map((b) => b.displayClientName).toSet().length;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: TrainerFadeSlide(
              delayMs: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'My Clients',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (22.0 * sf).clamp(18.0, 28.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accepted.isNotEmpty
                            ? const Color(0xFFE8F5E9)
                            : kField,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        accepted.isNotEmpty
                            ? '$uniqueClientsCount Accepted ${uniqueClientsCount == 1 ? "Client" : "Clients"}'
                            : '0 Clients',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accepted.isNotEmpty ? const Color(0xFF2E7D32) : kGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Athletes whose session requests have been accepted by you.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(10.5, 13.5),
                    color: kGrey,
                  ),
                ),

                const SizedBox(height: 20),

                if (accepted.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: kField,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Iconsax.people,
                          size: 44,
                          color: Color(0xFFCCCCCC),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No accepted clients yet',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (15.0 * sf).clamp(13.0, 17.0),
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'When you accept a session request from an athlete, they will immediately appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.0, 13.0),
                            color: kGrey,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: onGoToSchedule,
                          icon: const Icon(Iconsax.calendar_tick, size: 16, color: kDark),
                          label: const Text(
                            'View Session Requests',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLime,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...accepted.map((b) => _AcceptedClientCard(booking: b, sf: sf)),

                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}

class _AcceptedClientCard extends StatelessWidget {
  final BookingModel booking;
  final double sf;

  const _AcceptedClientCard({
    required this.booking,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;

    return TrainerPressScale(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all((16.0 * sf).clamp(12.0, 20.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLime.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Avatar + Name + Active Status Badge
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: kDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    b.displayClientName.isNotEmpty ? b.displayClientName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kLime,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.displayClientName,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (15.5 * sf).clamp(14.0, 18.0),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    if (b.clientPhone != null && b.clientPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Iconsax.call, size: 12, color: kGrey),
                          const SizedBox(width: 4),
                          Text(
                            b.clientPhone!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.5 * sf).clamp(10.0, 12.5),
                              color: kGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Accepted',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Accepted Session Details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kField,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.clock, size: 14, color: kDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${b.startTime} - ${b.endTime}  •  ${_formatDate(b.sessionDate)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (12.0 * sf).clamp(10.5, 13.0),
                          fontWeight: FontWeight.w600,
                          color: kDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Iconsax.weight, size: 14, color: kGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.displayWorkoutType,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.5 * sf).clamp(10.0, 12.5),
                          color: kDark,
                        ),
                      ),
                    ),
                  ],
                ),
                if (b.meetingLocation != null && b.meetingLocation!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Iconsax.building, size: 14, color: kGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.meetingLocation!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.5 * sf).clamp(10.0, 12.5),
                            color: kGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Package Progress & Health Section
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      b.resolvedPackageName,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (12.5 * sf).clamp(11.0, 14.0),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '✓ Paid',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Sessions Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sessions: ${b.resolvedSessionsCompleted}/${b.resolvedTotalSessions} Completed',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: kDark),
                    ),
                    Text(
                      '${b.resolvedTotalSessions - b.resolvedSessionsCompleted} Left',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: b.packageHealthStatus == 'red' ? const Color(0xFFDC2626) : kGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: b.resolvedTotalSessions > 0
                        ? (b.resolvedSessionsCompleted / b.resolvedTotalSessions).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: kField,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      b.packageHealthStatus == 'red'
                          ? const Color(0xFFDC2626)
                          : (b.packageHealthStatus == 'orange' ? const Color(0xFFF59E0B) : kDark),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                // Days Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Validity: ${b.resolvedDaysCompleted}/${b.resolvedTotalDays} Days',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: kGrey),
                    ),
                    Text(
                      '${b.resolvedDaysRemaining} Days Left',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: b.packageHealthStatus == 'red' ? const Color(0xFFDC2626) : kGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (b.notes != null && b.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Goals / Notes: "${b.notes}"',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.0 * sf).clamp(9.5, 12.0),
                fontStyle: FontStyle.italic,
                color: kGrey,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) {
      return 'Tomorrow';
    }
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }
}
