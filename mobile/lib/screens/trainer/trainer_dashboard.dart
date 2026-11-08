import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/logout_dialog.dart';

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
      _TrainerHomeTab(sf: sf, onLogout: _onLogout),
      const _PlaceholderTab(icon: Iconsax.people, label: 'My Clients'),
      const _PlaceholderTab(icon: Iconsax.calendar_tick, label: 'Schedule'),
      _TrainerProfileTab(sf: sf, onLogout: _onLogout),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages[_tab],
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

  const _TrainerHomeTab({
    required this.sf,
    required this.onLogout,
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

            // Header
            Row(
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
                    const SizedBox(width: 8),
                    // Quick logout
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onLogout,
                      child: Container(
                        width: (36.0 * sf).clamp(30, 44),
                        height: (36.0 * sf).clamp(30, 44),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
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

            SizedBox(height: (h * 0.03).clamp(16, 28)),

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

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _TStatCard(
                    label: 'Clients',
                    value: '0',
                    icon: Iconsax.people,
                    sf: sf,
                  ),
                ),
                SizedBox(width: (10.0 * sf).clamp(8, 14)),
                Expanded(
                  child: _TStatCard(
                    label: 'Sessions',
                    value: '0',
                    icon: Iconsax.calendar_tick,
                    sf: sf,
                    accent: true,
                  ),
                ),
                SizedBox(width: (10.0 * sf).clamp(8, 14)),
                Expanded(
                  child: _TStatCard(
                    label: 'Rating',
                    value: '—',
                    icon: Iconsax.star,
                    sf: sf,
                  ),
                ),
              ],
            ),

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            // Complete profile CTA
            Container(
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
                            color: Colors.white.withValues(alpha: 0.55),
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

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            Text(
              'Upcoming Sessions',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (15.0 * sf).clamp(13, 18),
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),

            SizedBox(height: (h * 0.015).clamp(10, 18)),

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
    return Container(
      padding: EdgeInsets.all((14.0 * sf).clamp(10, 18)),
      decoration: BoxDecoration(
        color: accent ? kLime : kField,
        borderRadius: BorderRadius.circular((14.0 * sf).clamp(10, 18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: (18.0 * sf).clamp(14, 22),
              color: accent ? kDark : kDark),
          SizedBox(height: (6.0 * sf).clamp(4, 10)),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Coach Profile',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (24.0 * sf).clamp(20.0, 30.0),
                    fontWeight: FontWeight.w800,
                    color: kDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Coach',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Trainer Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kField,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: kDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.teacher, color: kLime, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coach Marcus',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'marcus.fit@trainuspro.com',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: kGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Coach Settings',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            const SizedBox(height: 12),
            _CoachProfileTile(icon: Iconsax.user_edit, label: 'Edit Coach Profile', sf: sf),
            _CoachProfileTile(icon: Iconsax.card, label: 'Payout & Earnings', sf: sf),
            _CoachProfileTile(icon: Iconsax.calendar_edit, label: 'Availability & Slots', sf: sf),
            _CoachProfileTile(icon: Iconsax.notification, label: 'Notification Settings', sf: sf),
            _CoachProfileTile(icon: Iconsax.shield_tick, label: 'Security & Certifications', sf: sf),

            const SizedBox(height: 32),

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
  }
}

class _CoachProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double sf;

  const _CoachProfileTile({
    required this.icon,
    required this.label,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: (10.0 * sf).clamp(8, 14)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.$2 : item.$1,
                        size: iconSz,
                        color: selected ? kDark : const Color(0xFFBBBBBB),
                      ),
                      SizedBox(height: (3.0 * sf).clamp(2, 4)),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: labelSz,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? kDark : const Color(0xFFBBBBBB),
                        ),
                      ),
                      SizedBox(height: (3.0 * sf).clamp(2, 4)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: selected ? (20.0 * sf).clamp(14, 24) : 0,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(2),
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

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: (48.0 * sf).clamp(36, 60), color: kBorder),
            SizedBox(height: (12.0 * sf).clamp(8, 16)),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (18.0 * sf).clamp(14, 22),
                fontWeight: FontWeight.w700,
                color: const Color(0xFFDDDDDD),
              ),
            ),
            SizedBox(height: (6.0 * sf).clamp(4, 8)),
            Text(
              'Coming soon',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.0 * sf).clamp(10, 14),
                color: const Color(0xFFCCCCCC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
