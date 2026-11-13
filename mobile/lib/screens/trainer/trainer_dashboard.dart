import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../features/trainer/presentation/screens/trainer_pending_approval_screen.dart';
import '../../features/trainer/presentation/screens/trainer_rejected_screen.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/models/notification_model.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/notifications_bottom_sheet.dart';
import '../../widgets/trainer_animations.dart';
import 'trainer_availability_screen.dart';
import 'trainer_bookings_screen.dart';
import 'trainer_certificates_screen.dart';
import 'trainer_clients_screen.dart';
import 'trainer_earnings_screen.dart';
import 'trainer_messages_screen.dart';
import 'trainer_notification_preferences_screen.dart';
import 'trainer_notifications_screen.dart';
import 'trainer_package_management_screen.dart';
import 'trainer_profile_setup_screen.dart';
import 'trainer_reviews_screen.dart';
import 'trainer_schedule_section.dart';
import 'trainer_settings_screen.dart';

class TrainerDashboard extends StatefulWidget {
  final String? trainerId;
  const TrainerDashboard({super.key, this.trainerId});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final uid = widget.trainerId ?? AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      TrainerProfileService.instance.loadProfile(uid);
    }
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
    return ListenableBuilder(
      listenable: TrainerProfileService.instance,
      builder: (context, _) {
        final profileService = TrainerProfileService.instance;
        final uid = widget.trainerId ??
            AuthService().currentUser?.uid ??
            '';

        // Security & Status Protection: Pending, Rejected, or Suspended Accounts
        if (profileService.isSuspended) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Account Suspended',
                      style: TextStyle(fontFamily: 'Syne', fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your coach account has been suspended by platform administration. Please contact support@trainz.fit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (profileService.isPendingApproval) {
          return const TrainerPendingApprovalScreen();
        }

        if (profileService.isRejected) {
          return TrainerRejectedScreen(
            profile: profileService.toModel(uid: uid),
          );
        }

        final sf = scaleFactor(context);
        final pages = [
          _TrainerHomeTab(
            sf: sf,
            trainerId: uid,
            onLogout: _onLogout,
            onGoToSchedule: () => setState(() => _tab = 2),
            onGoToProfile: () => setState(() => _tab = 3),
            onGoToClients: () => setState(() => _tab = 1),
          ),
          _TrainerClientsTab(
            sf: sf,
            trainerId: uid,
            onGoToSchedule: () => setState(() => _tab = 2),
          ),
          _TrainerScheduleTab(sf: sf),
          _TrainerProfileTab(sf: sf, trainerId: uid, onLogout: _onLogout),
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
      },
    );
  }
}

// ── Trainer Home Tab ──────────────────────────────────────────────────────────
class _TrainerHomeTab extends StatelessWidget {
  final double sf;
  final String? trainerId;
  final VoidCallback onLogout;
  final VoidCallback onGoToSchedule;
  final VoidCallback onGoToProfile;
  final VoidCallback onGoToClients;

  const _TrainerHomeTab({
    required this.sf,
    this.trainerId,
    required this.onLogout,
    required this.onGoToSchedule,
    required this.onGoToProfile,
    required this.onGoToClients,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          TrainerProfileService.instance,
          BookingService.instance,
          NotificationService.instance,
        ]),
        builder: (context, _) {
          final profileService = TrainerProfileService.instance;
          final bService = BookingService.instance;
          final nService = NotificationService.instance;

          final effectiveUid = trainerId ??
              AuthService().currentUser?.uid ??
              '';

          final isAdvanced = profileService.isAdvancedTrainer;
          final isApproved = profileService.isApproved;
          final isProfileDone = profileService.isProfileCompleted;
          final completionScore = profileService.profileCompletionScore;
          final trainerName = profileService.fullName ?? 'Trainer';
          final photoUrl = profileService.photoUrl;

          // Requirement 2: Summary Cards from actual Firebase records (NO sample data)
          final upcoming = effectiveUid.isNotEmpty
              ? bService.upcomingBookingsForTrainer(effectiveUid)
              : bService.confirmedBookings;
          final todaySessions = effectiveUid.isNotEmpty
              ? bService.todaySessionsForTrainer(effectiveUid)
              : bService.todayConfirmedBookings;
          final completed = effectiveUid.isNotEmpty
              ? bService.completedBookingsForTrainer(effectiveUid)
              : bService.historyBookings.where((b) => b.status == BookingStatus.completed).toList();
          final activeClientsCount = effectiveUid.isNotEmpty
              ? bService.activeClientsCountForTrainer(effectiveUid)
              : bService.confirmedBookings.map((b) => b.displayClientName).toSet().length;
          final totalEarnings = effectiveUid.isNotEmpty
              ? bService.earningsForTrainer(effectiveUid)
              : bService.todaysIncome;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: (h * 0.025).clamp(14, 24)),

                // ── 1. Top Header Bar ─────────────────────────────────────────
                TrainerFadeSlide(
                  delayMs: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppLogo(fontSize: (14.0 * sf).clamp(12, 18)),
                      Row(
                        children: [
                          // Trainer Category Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: (10.0 * sf).clamp(8, 14),
                              vertical: (5.0 * sf).clamp(4, 8),
                            ),
                            decoration: BoxDecoration(
                              color: isAdvanced ? const Color(0xFFFFF8E1) : kLime,
                              borderRadius: BorderRadius.circular((8.0 * sf).clamp(6, 10)),
                              border: isAdvanced
                                  ? Border.all(color: const Color(0xFFFFB300), width: 1.2)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAdvanced ? Iconsax.star : Iconsax.verify,
                                  size: (12.0 * sf).clamp(10, 14),
                                  color: isAdvanced ? const Color(0xFFE65100) : kDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAdvanced ? 'Advanced Trainer' : 'Trainer',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (11.0 * sf).clamp(9, 13),
                                    fontWeight: FontWeight.w700,
                                    color: isAdvanced ? const Color(0xFFE65100) : kDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: (8.0 * sf).clamp(6, 10)),

                          // Notifications Bell with Live Counter Badge
                          TrainerPressScale(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerNotificationsScreen(
                                    trainerId: effectiveUid,
                                  ),
                                ),
                              );
                            },
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
                                if (nService.unreadCount > 0)
                                  Positioned(
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
                                          '${nService.unreadCount}',
                                          style: const TextStyle(
                                            fontFamily: 'Syne',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: (8.0 * sf).clamp(6, 10)),

                          // Trainer Profile Photo Avatar (Tappable -> Profile Tab)
                          TrainerPressScale(
                            onTap: onGoToProfile,
                            child: Container(
                              width: (36.0 * sf).clamp(30, 44),
                              height: (36.0 * sf).clamp(30, 44),
                              decoration: BoxDecoration(
                                color: kDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: kLime, width: 1.5),
                              ),
                              child: ClipOval(
                                child: photoUrl != null && photoUrl.isNotEmpty
                                    ? (photoUrl.startsWith('http')
                                        ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _avatarFallback(trainerName))
                                        : (File(photoUrl).existsSync()
                                            ? Image.file(File(photoUrl), fit: BoxFit.cover)
                                            : _avatarFallback(trainerName)))
                                    : _avatarFallback(trainerName),
                              ),
                            ),
                          ),
                          SizedBox(width: (8.0 * sf).clamp(6, 10)),

                          // Logout Icon Button
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

                SizedBox(height: (h * 0.025).clamp(14, 24)),

                // ── 2. Welcome Banner & Identity ──────────────────────────────
                TrainerFadeSlide(
                  delayMs: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (13.0 * sf).clamp(11, 15),
                              color: kGrey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Account Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isApproved ? Icons.check_circle_rounded : Iconsax.clock,
                                  size: 11,
                                  color: isApproved ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isApproved ? 'Approved & Active' : 'Under Review',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: (4.0 * sf).clamp(2, 6)),
                      Text(
                        trainerName,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (26.0 * sf).clamp(20, 32),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: (8.0 * sf).clamp(6, 10)),

                      // Verification & Profile Status Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Profile Completion Status
                          _StatusChip(
                            icon: Iconsax.profile_tick,
                            label: isProfileDone ? 'Profile 100% Complete' : '$completionScore% Complete',
                            color: isProfileDone ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                            backgroundColor: isProfileDone ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                            sf: sf,
                          ),
                          // Qualification Status
                          if (isAdvanced)
                            _StatusChip(
                              icon: Iconsax.award,
                              label: 'Qualifications Verified (3.5+ Yrs Exp)',
                              color: const Color(0xFF7B1FA2),
                              backgroundColor: const Color(0xFFF3E5F5),
                              sf: sf,
                            )
                          else
                            _StatusChip(
                              icon: Iconsax.shield_tick,
                              label: 'Platform Verified Coach',
                              color: const Color(0xFF1565C0),
                              backgroundColor: const Color(0xFFE3F2FD),
                              sf: sf,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.025).clamp(16, 24)),

                // ── 3. Dashboard Overview (The 5 Summary Cards from Actual Firebase Records) ──
                TrainerFadeSlide(
                  delayMs: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (15.0 * sf).clamp(13, 18),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      SizedBox(height: (10.0 * sf).clamp(8, 14)),

                      // 4 Summary Metrics (2x2 Grid)
                      Row(
                        children: [
                          Expanded(
                            child: _TStatCard(
                              label: 'Upcoming Bookings',
                              value: '${upcoming.length}',
                              icon: Iconsax.calendar_1,
                              sf: sf,
                              onTap: onGoToSchedule,
                            ),
                          ),
                          SizedBox(width: (10.0 * sf).clamp(8, 14)),
                          Expanded(
                            child: _TStatCard(
                              label: "Today's Sessions",
                              value: '${todaySessions.length}',
                              icon: Iconsax.clock,
                              sf: sf,
                              accent: todaySessions.isNotEmpty,
                              onTap: onGoToSchedule,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: (10.0 * sf).clamp(8, 14)),
                      Row(
                        children: [
                          Expanded(
                            child: _TStatCard(
                              label: 'Completed Sessions',
                              value: '${completed.length}',
                              icon: Iconsax.tick_circle,
                              sf: sf,
                              onTap: () => _showCompletedSessionsSheet(context, completed, sf),
                            ),
                          ),
                          SizedBox(width: (10.0 * sf).clamp(8, 14)),
                          Expanded(
                            child: _TStatCard(
                              label: 'Active Clients',
                              value: '$activeClientsCount',
                              icon: Iconsax.people,
                              sf: sf,
                              onTap: onGoToClients,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: (12.0 * sf).clamp(10, 16)),

                      // 5th Card: Current Earnings Box (Real-time computed revenue from bookings)
                      _TrainerTodaysIncomeCard(
                        sf: sf,
                        trainerId: effectiveUid,
                        onGoToSchedule: onGoToSchedule,
                        onOpenEarnings: () => _showEarningsDetailSheet(
                          context,
                          sf,
                          totalEarnings,
                          completed,
                          upcoming,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.025).clamp(16, 24)),

                // ── 4. Trainer Category-Based Features ────────────────────────
                TrainerFadeSlide(
                  delayMs: 140,
                  child: isAdvanced
                      ? _AdvancedTrainerCard(sf: sf, trainerId: effectiveUid)
                      : _StandardTrainerPackageModelCard(sf: sf, trainerId: effectiveUid),
                ),

                SizedBox(height: (h * 0.025).clamp(16, 24)),

                // ── 5. Quick Actions ──────────────────────────────────────────
                TrainerFadeSlide(
                  delayMs: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (15.0 * sf).clamp(13, 18),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      SizedBox(height: (10.0 * sf).clamp(8, 14)),
                      Wrap(
                        spacing: (10.0 * sf).clamp(8, 14),
                        runSpacing: (10.0 * sf).clamp(8, 14),
                        children: [
                          _QuickActionButton(
                            icon: Iconsax.user,
                            title: 'My Profile',
                            subtitle: 'Edit details & photo',
                            sf: sf,
                            onTap: onGoToProfile,
                          ),
                          _QuickActionButton(
                            icon: Iconsax.calendar_edit,
                            title: 'My Availability',
                            subtitle: 'Working days & hours',
                            sf: sf,
                            onTap: () => _showAvailabilitySheet(context, effectiveUid, sf),
                          ),
                          _QuickActionButton(
                            icon: Iconsax.calendar_tick,
                            title: 'My Bookings',
                            subtitle: 'Scheduled sessions',
                            sf: sf,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerBookingsScreen(
                                    trainerId: effectiveUid,
                                  ),
                                ),
                              );
                            },
                          ),
                          _QuickActionButton(
                            icon: Iconsax.message,
                            title: 'Messages',
                            subtitle: 'Booked client chats',
                            sf: sf,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerMessagesScreen(
                                    trainerId: effectiveUid,
                                  ),
                                ),
                              );
                            },
                          ),
                          _QuickActionButton(
                            icon: Iconsax.wallet_money,
                            title: 'Earnings',
                            subtitle: 'Session payouts',
                            sf: sf,
                            onTap: () => _showEarningsDetailSheet(
                              context,
                              sf,
                              totalEarnings,
                              completed,
                              upcoming,
                            ),
                          ),
                          _QuickActionButton(
                            icon: Iconsax.award,
                            title: 'My Qualifications',
                            subtitle: 'Certificates & status',
                            sf: sf,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerCertificatesScreen(
                                    trainerId: effectiveUid,
                                    category: profileService.category,
                                  ),
                                ),
                              );
                            },
                          ),
                          _QuickActionButton(
                            icon: Iconsax.box_1,
                            title: 'Training Packages',
                            subtitle: isAdvanced ? 'Custom plans & rates' : 'Platform fixed plans',
                            sf: sf,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerPackageManagementScreen(
                                    trainerId: effectiveUid,
                                    isAdvanced: isAdvanced,
                                  ),
                                ),
                              );
                            },
                          ),
                          _QuickActionButton(
                            icon: Iconsax.star,
                            title: 'Client Reviews',
                            subtitle: 'Ratings & feedback',
                            sf: sf,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerReviewsScreen(
                                    trainerId: effectiveUid,
                                  ),
                                ),
                              );
                            },
                          ),
                          _QuickActionButton(
                            icon: Iconsax.people,
                            title: 'My Clients',
                            subtitle: 'Profiles & training notes',
                            sf: sf,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrainerClientsScreen(
                                    trainerId: effectiveUid,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.025).clamp(16, 24)),

                // ── 6. Upcoming Confirmed Sessions ────────────────────────────
                TrainerFadeSlide(
                  delayMs: 220,
                  child: Column(
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
                          if (upcoming.isNotEmpty)
                            TrainerPressScale(
                              onTap: onGoToSchedule,
                              child: Text(
                                'View Schedule',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: (11.5 * sf).clamp(10, 13),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1565C0),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: (10.0 * sf).clamp(8, 14)),
                      if (upcoming.isNotEmpty) ...[
                        ...upcoming.take(4).map(
                              (b) => _UpcomingSessionCard(
                                booking: b,
                                sf: sf,
                                onTap: () => _showBookingDetailSheet(context, b, sf),
                              ),
                            ),
                      ] else ...[
                        _EmptyStateCard(
                          icon: Iconsax.calendar_remove,
                          title: 'No upcoming sessions yet',
                          subtitle: 'Confirmed client training sessions will appear here.',
                          sf: sf,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.025).clamp(16, 24)),

                // ── 7. Notifications & Updates ────────────────────────────────
                TrainerFadeSlide(
                  delayMs: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Updates',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (15.0 * sf).clamp(13, 18),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          TrainerPressScale(
                            onTap: () => NotificationsBottomSheet.show(context),
                            child: Text(
                              'View All',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (11.5 * sf).clamp(10, 13),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: (10.0 * sf).clamp(8, 14)),
                      if (nService.notifications.isNotEmpty) ...[
                        ...nService.notifications.take(3).map(
                              (n) => _NotificationTile(
                                notification: n,
                                sf: sf,
                                onTap: () => NotificationsBottomSheet.show(context),
                              ),
                            ),
                      ] else ...[
                        _EmptyStateCard(
                          icon: Iconsax.notification,
                          title: 'No recent updates',
                          subtitle: 'Updates for booking requests, confirmations, client messages, and certificate reviews will appear here.',
                          sf: sf,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.04).clamp(24, 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'T';
    return Container(
      color: kDark,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Syne',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kLime,
          ),
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
  final VoidCallback? onTap;

  const _TStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.sf,
    this.accent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numValue = num.tryParse(value);

    return TrainerPressScale(
      onTap: onTap,
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
                color: accent ? kDark.withValues(alpha: 0.7) : kGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trainer Current Earnings Card (Real-Time Booking-Derived Ledger) ──────────
class _TrainerTodaysIncomeCard extends StatelessWidget {
  final double sf;
  final String? trainerId;
  final VoidCallback onGoToSchedule;
  final VoidCallback? onOpenEarnings;

  const _TrainerTodaysIncomeCard({
    required this.sf,
    this.trainerId,
    required this.onGoToSchedule,
    this.onOpenEarnings,
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
        final effectiveUid = trainerId ?? AuthService().currentUser?.uid ?? '';

        final income = effectiveUid.isNotEmpty
            ? bService.earningsForTrainer(effectiveUid)
            : bService.todaysIncome;
        final todayConfirmed = effectiveUid.isNotEmpty
            ? bService.todaySessionsForTrainer(effectiveUid)
            : bService.todayConfirmedBookings;
        final todayCount = todayConfirmed.length;
        final rate = pService.hourlyRate;

        return TrainerPressScale(
          onTap: onOpenEarnings ?? onGoToSchedule,
          child: TrainerBreathingGlow(
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
                              "CURRENT EARNINGS",
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
                              'Verified Session Revenue',
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

                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),

                  SizedBox(height: (12.0 * sf).clamp(8.0, 14.0)),

                  Row(
                    children: [
                      Icon(
                        todayCount > 0 ? Iconsax.tick_circle : Iconsax.info_circle,
                        size: 14,
                        color: todayCount > 0 ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          todayCount > 0
                              ? '$todayCount session${todayCount == 1 ? '' : 's'} scheduled for today'
                              : '0 sessions scheduled for today',
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Category Model Cards & Dashboard Sub-Components ──────────────────────────
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final double sf;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (10.0 * sf).clamp(8, 12),
        vertical: (4.0 * sf).clamp(3, 6),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (11.0 * sf).clamp(9, 13), color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (10.5 * sf).clamp(9, 12),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardTrainerPackageModelCard extends StatelessWidget {
  final double sf;
  final String? trainerId;
  const _StandardTrainerPackageModelCard({required this.sf, this.trainerId});

  @override
  Widget build(BuildContext context) {
    const packages = [
      ('1 Day', '₹500', '1 session', '1 day'),
      ('3 Days', '₹1,399', '3 sessions', '3 days'),
      ('1 Week', '₹2,799', '6 sessions', '7 days'),
      ('1 Month', '₹10,799', '26 sessions', '30 days'),
      ('3 Months', '₹29,999', '78 sessions', '90 days'),
      ('6-Month Transformation', '₹52,999', '150 sessions', '180 days'),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((16.0 * sf).clamp(14, 20)),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STANDARD TRAINER',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: kDark,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Iconsax.shield_tick, size: 16, color: kLime),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'TRAIN Z Platform Packages',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (16.0 * sf).clamp(14, 18),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Standard Trainers deliver coaching using the 6 predefined TRAIN Z packages. Pricing, session counts and validity are standardized platform-wide. Custom packages cannot be created.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(9.5, 12),
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: packages
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p.$1,
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${p.$2} • ${p.$3} (${p.$4})',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              color: kLime.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrainerPackageManagementScreen(
                    trainerId: trainerId,
                    isAdvanced: false,
                  ),
                ),
              );
            },
            icon: const Icon(Iconsax.eye, size: 14, color: kDark),
            label: const Text(
              'View Package Details',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kLime,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedTrainerCard extends StatelessWidget {
  final double sf;
  final String? trainerId;
  const _AdvancedTrainerCard({required this.sf, this.trainerId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((16.0 * sf).clamp(14, 20)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFB300)),
                ),
                child: const Text(
                  'ADVANCED TRAINER',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Iconsax.star, size: 16, color: const Color(0xFFE65100)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Custom Training Plans Eligible',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (16.0 * sf).clamp(14, 18),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'As an approved Advanced Trainer with verified qualifications (3.5+ years experience), you can create custom training plans and set independent pricing.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10, 12.5),
              color: const Color(0xFF5D4037),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCC80)),
            ),
            child: Row(
              children: const [
                Icon(Iconsax.info_circle, size: 14, color: Color(0xFFE65100)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Policy Requirement: Every custom training plan requires separate Admin approval before publication.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showAdvancedCustomPlanSheet(context, sf, trainerId: trainerId),
            icon: const Icon(Iconsax.add_circle, size: 15, color: kDark),
            label: const Text(
              'Manage Custom Plans',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kLime,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

void _showAdvancedCustomPlanSheet(BuildContext context, double sf, {String? trainerId}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB300)),
                  ),
                  child: const Icon(Iconsax.star, color: Color(0xFFE65100)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Training Plans',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w800, color: kDark),
                      ),
                      Text(
                        'Advanced Trainer Privileges',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'As an approved Advanced Trainer, you have the privilege to create tailored training plans with custom session counts and pricing.\n\nMandatory Platform Policy:\nEvery custom training plan requires separate TRAIN Z Admin verification and approval before it can be published to clients. Unpublished, draft, or pending plans will remain private to your account.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF4E342E), height: 1.45),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Got It', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrainerPackageManagementScreen(
                            trainerId: trainerId,
                            isAdvanced: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Open Manager', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double sf;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final itemWidth = (w - (sf * 48)) / 2 - 8;

    return TrainerPressScale(
      onTap: onTap,
      child: Container(
        width: itemWidth.clamp(140.0, 200.0),
        padding: EdgeInsets.all((12.0 * sf).clamp(10, 16)),
        decoration: BoxDecoration(
          color: kField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: (32.0 * sf).clamp(28, 38),
              height: (32.0 * sf).clamp(28, 38),
              decoration: BoxDecoration(
                color: kDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: (16.0 * sf).clamp(14, 20), color: kLime),
            ),
            SizedBox(height: (8.0 * sf).clamp(6, 10)),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (12.5 * sf).clamp(11, 14),
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (10.0 * sf).clamp(9, 11),
                color: kGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSessionCard extends StatelessWidget {
  final BookingModel booking;
  final double sf;
  final VoidCallback onTap;

  const _UpcomingSessionCard({
    required this.booking,
    required this.sf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;

    return TrainerPressScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all((14.0 * sf).clamp(12, 18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: kDark,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: b.clientPhotoUrl != null && b.clientPhotoUrl!.isNotEmpty
                    ? Image.network(
                        b.clientPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _initialsWidget(b.displayClientName),
                      )
                    : _initialsWidget(b.displayClientName),
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
                      fontSize: (13.5 * sf).clamp(12, 15),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Iconsax.calendar_1, size: 12, color: kGrey),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatSessionDate(b.sessionDate)} • ${b.startTime}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(9.5, 12),
                          color: kGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: kField,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '60m',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: kDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Iconsax.location, size: 12, color: kGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.meetingLocation ?? 'Personal Training Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (10.5 * sf).clamp(9, 11.5),
                            color: kGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'CONFIRMED',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final double sf;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.sf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    IconData icon = Iconsax.notification;
    Color iconColor = kDark;
    Color iconBg = kField;

    if (n.type.contains('BOOKING')) {
      icon = Iconsax.calendar_tick;
      iconColor = const Color(0xFF2E7D32);
      iconBg = const Color(0xFFE8F5E9);
    } else if (n.type.contains('CHAT')) {
      icon = Iconsax.message;
      iconColor = const Color(0xFF1565C0);
      iconBg = const Color(0xFFE3F2FD);
    } else if (n.type.contains('CERTIFICATE') || n.type.contains('PACKAGE')) {
      icon = Iconsax.award;
      iconColor = const Color(0xFFE65100);
      iconBg = const Color(0xFFFFF3E0);
    }

    return TrainerPressScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all((12.0 * sf).clamp(10, 16)),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.isRead ? kBorder : kLime.withValues(alpha: 0.8),
            width: n.isRead ? 1 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (12.0 * sf).clamp(10.5, 13.5),
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(9.5, 12.0),
                      color: kGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.isRead) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double sf;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: (16.0 * sf).clamp(14, 22),
        vertical: (20.0 * sf).clamp(16, 26),
      ),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: (28.0 * sf).clamp(22, 36), color: kGrey),
          SizedBox(height: (8.0 * sf).clamp(6, 10)),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (13.0 * sf).clamp(11.5, 15),
              fontWeight: FontWeight.w700,
              color: kDark,
            ),
          ),
          SizedBox(height: (4.0 * sf).clamp(2, 6)),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(9.5, 12),
              color: kGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: kGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Helper Modal Bottom Sheets ─────────────────────────────────────
void _showBookingDetailSheet(BuildContext context, BookingModel booking, double sf) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: kDark,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: booking.clientPhotoUrl != null && booking.clientPhotoUrl!.isNotEmpty
                        ? Image.network(
                            booking.clientPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _initialsWidget(booking.displayClientName),
                          )
                        : _initialsWidget(booking.displayClientName),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.displayClientName,
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                      Text(
                        booking.workoutType ?? 'Personal Training',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: kGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CONFIRMED',
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
            const Divider(height: 28),
            _DetailInfoRow(
              icon: Iconsax.calendar_1,
              label: 'Session Date',
              value: _formatSessionDate(booking.sessionDate),
            ),
            _DetailInfoRow(
              icon: Iconsax.clock,
              label: 'Time & Duration',
              value: '${booking.startTime} - ${booking.endTime} (60 min)',
            ),
            _DetailInfoRow(
              icon: Iconsax.location,
              label: 'Training Location',
              value: (booking.status == BookingStatus.confirmed)
                  ? (booking.meetingLocation ?? 'Personal Training Location')
                  : 'Location address hidden until booking is confirmed',
            ),
            _DetailInfoRow(
              icon: Iconsax.box,
              label: 'Package Plan',
              value: booking.resolvedPackageName,
            ),
            if (booking.notes != null && booking.notes!.isNotEmpty)
              _DetailInfoRow(
                icon: Iconsax.document_text,
                label: 'Client Goals / Notes',
                value: booking.notes!,
              ),
            const SizedBox(height: 20),
            if (booking.status == BookingStatus.confirmed) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerBookingsScreen(
                          trainerId: booking.trainerId,
                          initialTab: BookingFilterTab.upcoming,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kDark),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Manage in Bookings', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


void _showAvailabilitySheet(BuildContext context, String trainerId, double sf) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.calendar_edit, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trainer Availability',
                        style: TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w800, color: kDark),
                      ),
                      Text(
                        'Weekly Working Hours & Slots',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'The Availability Management module is scheduled for the upcoming release. Your sessions currently default to standard 60-minute slots during your preferred hours (06:00 AM - 08:00 PM).',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF555555), height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Understood', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrainerAvailabilityScreen(trainerId: trainerId),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kDark),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Manage Calendar', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEarningsDetailSheet(BuildContext context, double sf, int totalEarnings, List<BookingModel> completed, List<BookingModel> upcoming) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Trainer Earnings Overview',
              style: TextStyle(fontFamily: 'Syne', fontSize: 17, fontWeight: FontWeight.w800, color: kDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Calculated from confirmed & completed sessions',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL EARNINGS',
                    style: TextStyle(fontFamily: 'Syne', fontSize: 11, fontWeight: FontWeight.w800, color: kLime, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹$totalEarnings',
                    style: const TextStyle(fontFamily: 'Syne', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${completed.length} completed sessions • ${upcoming.length} upcoming scheduled',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'All trainer earnings are reconciled with completed session verification and processed securely in Indian Rupees (INR).',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: kGrey, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  final effectiveUid = completed.isNotEmpty
                      ? completed.first.trainerId
                      : (upcoming.isNotEmpty ? upcoming.first.trainerId : '');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainerEarningsScreen(trainerId: effectiveUid),
                    ),
                  );
                },
                icon: const Icon(Iconsax.wallet_3, size: 16, color: kDark),
                label: const Text(
                  'View Detailed Earnings & Payouts',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLime,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kDark),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showCompletedSessionsSheet(BuildContext context, List<BookingModel> completed, double sf) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Completed Sessions (${completed.length})',
              style: const TextStyle(fontFamily: 'Syne', fontSize: 17, fontWeight: FontWeight.w800, color: kDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Verified sessions delivered to your clients.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
            ),
            const SizedBox(height: 16),
            if (completed.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No sessions completed yet.',
                    style: TextStyle(fontFamily: 'Poppins', color: kGrey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: completed.length,
                  itemBuilder: (context, index) {
                    final b = completed[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.check_rounded, color: Color(0xFF2E7D32)),
                      ),
                      title: Text(b.displayClientName, style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
                      subtitle: Text('${_formatSessionDate(b.sessionDate)} • ${b.startTime} • ${b.resolvedPackageName}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _formatSessionDate(DateTime dt) {
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

Widget _initialsWidget(String name) {
  final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
  return Center(
    child: Text(
      initial,
      style: const TextStyle(
        fontFamily: 'Syne',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );
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
  final String? trainerId;
  final VoidCallback onLogout;

  const _TrainerProfileTab({
    required this.sf,
    this.trainerId,
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
                    IconButton(
                      tooltip: 'Settings & Account',
                      icon: Icon(
                        Iconsax.setting_2,
                        color: kDark,
                        size: (22.0 * sf).clamp(18.0, 26.0),
                      ),
                      onPressed: () {
                        final effectiveUid = trainerId ?? AuthService().currentUser?.uid;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TrainerSettingsScreen(trainerId: effectiveUid),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
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
                        icon: Iconsax.verify,
                        title: 'Category',
                        value: service.category.displayName,
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
                  icon: Iconsax.setting_2,
                  label: 'Settings & Account Management',
                  sf: sf,
                  onTap: () {
                    final effectiveUid = trainerId ?? AuthService().currentUser?.uid;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerSettingsScreen(trainerId: effectiveUid),
                      ),
                    );
                  },
                ),
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
                  onTap: () {
                    final effectiveUid = trainerId ?? AuthService().currentUser?.uid;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerEarningsScreen(trainerId: effectiveUid),
                      ),
                    );
                  },
                ),
                _CoachProfileTile(
                  icon: Iconsax.calendar_edit,
                  label: 'Availability & Slots',
                  sf: sf,
                  onTap: () {
                    final effectiveUid = trainerId ?? AuthService().currentUser?.uid;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerAvailabilityScreen(trainerId: effectiveUid),
                      ),
                    );
                  },
                ),
                _CoachProfileTile(
                  icon: Iconsax.notification,
                  label: 'Notification Settings',
                  sf: sf,
                  onTap: () {
                    final effectiveUid = trainerId ?? AuthService().currentUser?.uid;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerNotificationPreferencesScreen(trainerId: effectiveUid),
                      ),
                    );
                  },
                ),
                _CoachProfileTile(
                  icon: Iconsax.shield_tick,
                  label: 'Security & Certifications',
                  sf: sf,
                  onTap: () {
                    final effectiveUid = trainerId ?? AuthService().currentUser?.uid;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainerCertificatesScreen(trainerId: effectiveUid),
                      ),
                    );
                  },
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
  final String? trainerId;
  final VoidCallback onGoToSchedule;

  const _TrainerClientsTab({
    required this.sf,
    this.trainerId,
    required this.onGoToSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUid = trainerId ?? AuthService().currentUser?.uid ?? '';
    return TrainerClientsScreen(
      trainerId: effectiveUid,
      showAppBar: false,
    );
  }
}
