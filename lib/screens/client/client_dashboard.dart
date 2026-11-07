import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../widgets/app_widgets.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
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

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w  = MediaQuery.of(context).size.width;

    final pages = [
      _HomeTab(sf: sf, w: w),
      _PlaceholderTab(icon: Iconsax.search_normal, label: 'Find Trainers'),
      _PlaceholderTab(icon: Iconsax.calendar_1, label: 'Sessions'),
      _PlaceholderTab(icon: Iconsax.profile_circle, label: 'Profile'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages[_tab],
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
        sf: sf,
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final double sf;
  final double w;
  const _HomeTab({required this.sf, required this.w});

  @override
  Widget build(BuildContext context) {
    final h    = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: (h * 0.03).clamp(16, 28)),

            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppLogo(fontSize: (14.0 * sf).clamp(12, 18)),
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
              ],
            ),

            SizedBox(height: (h * 0.03).clamp(16, 28)),

            // Greeting
            Text(
              'Good morning 👋',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (13.0 * sf).clamp(11, 15),
                color: kGrey,
              ),
            ),
            SizedBox(height: (4.0 * sf).clamp(2, 6)),
            Text(
              'Let\'s get moving.',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (26.0 * sf).clamp(20, 32),
                fontWeight: FontWeight.w800,
                color: kDark,
                height: 1.1,
              ),
            ),

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            // Streak card
            _StreakCard(sf: sf),

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            // Section: Featured Trainers
            Text(
              'Featured Trainers',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (15.0 * sf).clamp(13, 18),
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),

            SizedBox(height: (h * 0.015).clamp(10, 18)),

            SizedBox(
              height: (140.0 * sf).clamp(120, 170),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _trainers.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: (12.0 * sf).clamp(8, 16)),
                itemBuilder: (_, i) => _TrainerCard(
                  trainer: _trainers[i],
                  sf: sf,
                ),
              ),
            ),

            SizedBox(height: (h * 0.025).clamp(14, 24)),

            // Section: Quick Stats
            Text(
              'Your Progress',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (15.0 * sf).clamp(13, 18),
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),

            SizedBox(height: (h * 0.015).clamp(10, 18)),

            Row(
              children: [
                Expanded(child: _StatCard(label: 'Sessions', value: '0', icon: Iconsax.weight, sf: sf)),
                SizedBox(width: (12.0 * sf).clamp(8, 16)),
                Expanded(child: _StatCard(label: 'Streak', value: '0d', icon: Iconsax.flash_1, sf: sf, accent: true)),
              ],
            ),

            SizedBox(height: (h * 0.03).clamp(20, 32)),
          ],
        ),
      ),
    );
  }

  static const _trainers = [
    {'name': 'Alex R.', 'spec': 'Strength & HIIT'},
    {'name': 'Maya S.', 'spec': 'Yoga & Wellness'},
    {'name': 'Jordan K.', 'spec': 'CrossFit'},
    {'name': 'Sam T.', 'spec': 'Nutrition'},
  ];
}

class _StreakCard extends StatelessWidget {
  final double sf;
  const _StreakCard({required this.sf});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((18.0 * sf).clamp(14, 22)),
      decoration: BoxDecoration(
        color: kDark,
        borderRadius: BorderRadius.circular((16.0 * sf).clamp(12, 20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start your first session',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (16.0 * sf).clamp(13, 19),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: (6.0 * sf).clamp(4, 8)),
                Text(
                  'Find a trainer and book today.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (12.0 * sf).clamp(10, 13),
                    color: Colors.white.withValues(alpha: 0.6),
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
                    borderRadius: BorderRadius.circular((8.0 * sf).clamp(6, 10)),
                  ),
                  child: Text(
                    'Find Trainer',
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
            Iconsax.flash_1,
            size: (48.0 * sf).clamp(36, 60),
            color: kLime.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final Map<String, String> trainer;
  final double sf;
  const _TrainerCard({required this.trainer, required this.sf});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (120.0 * sf).clamp(100, 150),
      padding: EdgeInsets.all((12.0 * sf).clamp(10, 16)),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular((14.0 * sf).clamp(10, 18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: (40.0 * sf).clamp(32, 50),
            height: (40.0 * sf).clamp(32, 50),
            decoration: BoxDecoration(
              color: kDark,
              borderRadius: BorderRadius.circular((10.0 * sf).clamp(8, 14)),
            ),
            child: Icon(
              Iconsax.profile_circle,
              size: (22.0 * sf).clamp(18, 28),
              color: kLime,
            ),
          ),
          SizedBox(height: (8.0 * sf).clamp(6, 12)),
          Text(
            trainer['name']!,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (13.0 * sf).clamp(11, 15),
              fontWeight: FontWeight.w700,
              color: kDark,
            ),
          ),
          SizedBox(height: (2.0 * sf).clamp(1, 4)),
          Text(
            trainer['spec']!,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (10.0 * sf).clamp(9, 12),
              color: kGrey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double sf;
  final bool accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.sf,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all((16.0 * sf).clamp(12, 20)),
      decoration: BoxDecoration(
        color: accent ? kDark : kField,
        borderRadius: BorderRadius.circular((14.0 * sf).clamp(10, 18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: (20.0 * sf).clamp(16, 24), color: accent ? kLime : kDark),
          SizedBox(height: (8.0 * sf).clamp(6, 12)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (22.0 * sf).clamp(18, 28),
              fontWeight: FontWeight.w800,
              color: accent ? Colors.white : kDark,
            ),
          ),
          SizedBox(height: (2.0 * sf).clamp(1, 4)),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(9, 13),
              color: accent ? Colors.white.withValues(alpha: 0.6) : kGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final double sf;

  const _BottomNav({
    required this.current,
    required this.onTap,
    required this.sf,
  });

  static final _items = [
    (Iconsax.home_2, Iconsax.home_2, 'Home'),
    (Iconsax.search_normal, Iconsax.search_normal, 'Trainers'),
    (Iconsax.calendar, Iconsax.calendar_1, 'Sessions'),
    (Iconsax.profile_circle, Iconsax.profile_circle, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final iconSz = (22.0 * sf).clamp(18.0, 26.0);
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
                  padding: EdgeInsets.symmetric(vertical: (10.0 * sf).clamp(8, 14)),
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
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

// ── Placeholder tab ───────────────────────────────────────────────────────────
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

