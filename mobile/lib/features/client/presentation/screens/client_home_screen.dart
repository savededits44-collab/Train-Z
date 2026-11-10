import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/credit_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../shared/models/booking_model.dart';
import '../../../../shared/models/client_profile_model.dart';
import '../../../../shared/models/session_credit_model.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../shared/models/training_plan_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../../../widgets/logout_dialog.dart';
import '../widgets/client_bottom_nav.dart';
import '../widgets/client_location_sheet.dart';
import '../widgets/client_package_card.dart';
import '../widgets/client_trainer_card.dart';
import '../widgets/client_upcoming_session_card.dart';
import '../widgets/trainer_filter_sheet.dart';
import 'client_profile_setup_screen.dart';

/// Comprehensive Client Home Dashboard for TRAIN Z.
/// Features 5 main navigation tabs: Home, Find Trainer, Bookings, Messages, Profile.
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentTab = 0;
  final TextEditingController _homeSearchController = TextEditingController();
  final TextEditingController _findTrainerSearchController = TextEditingController();
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _findTrainerScrollController = ScrollController();
  final GlobalKey _packagesKey = GlobalKey();

  String _searchFilter = '';
  String _selectedSpecialty = 'All';
  String _sortBy = 'rating'; // 'rating', 'experience', 'relevance'
  int _trainerLimit = 10;
  TrainerFilterState _filterState = const TrainerFilterState();

  @override
  void initState() {
    super.initState();
    _findTrainerScrollController.addListener(_onFindTrainerScroll);
  }

  void _onFindTrainerScroll() {
    if (_findTrainerScrollController.hasClients &&
        _findTrainerScrollController.position.pixels >=
            _findTrainerScrollController.position.maxScrollExtent - 200) {
      if (mounted) {
        setState(() {
          _trainerLimit += 10;
        });
      }
    }
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    _findTrainerSearchController.dispose();
    _homeScrollController.dispose();
    _findTrainerScrollController.dispose();
    super.dispose();
  }

  void _switchTab(int tabIndex, {String? searchQuery}) {
    setState(() {
      _currentTab = tabIndex;
      if (searchQuery != null) {
        _findTrainerSearchController.text = searchQuery;
        _searchFilter = searchQuery;
      }
    });
  }

  void _scrollToPackages() {
    final ctx = _packagesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return StreamBuilder<UserModel?>(
      stream: AuthService().currentUserProfileStream,
      builder: (context, userSnap) {
        final clientUser = userSnap.data;
        final clientGender = clientUser?.gender ?? Gender.male;
        final displayName = clientUser?.displayName ?? user?.displayName ?? 'Athlete';

        return StreamBuilder<ClientProfileModel?>(
          stream: FirestoreService().streamClientProfile(uid),
          builder: (context, profileSnap) {
            final clientProfile = profileSnap.data;
            final selectedCityId = clientProfile?.preferredCityId ?? 'city_mumbai';
            final preferredVenue = clientProfile?.preferredTrainingLocation ?? 'Commercial Gym';

            final cityName = AppConstants.initialLaunchCities.firstWhere(
              (c) => c['id'] == selectedCityId,
              orElse: () => {'name': 'Mumbai'},
            )['name'] as String;

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: const AppLogo(fontSize: 16),
                actions: [
                  // Location Pill Action
                  InkWell(
                    onTap: () {
                      ClientLocationSheet.show(
                        context,
                        clientId: uid,
                        currentCityId: selectedCityId,
                        currentVenue: preferredVenue,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.location, size: 14, color: kDark),
                          const SizedBox(width: 4),
                          Text(
                            cityName,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (11.5 * sf).clamp(10.5, 13.0),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 16, color: kDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sign Out
                  IconButton(
                    icon: const Icon(Iconsax.logout, color: kDark, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () => showLogoutDialog(context),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: IndexedStack(
                index: _currentTab,
                children: [
                  // TAB 0: Home Dashboard
                  _buildHomeTab(
                    context: context,
                    sf: sf,
                    uid: uid,
                    clientUser: clientUser,
                    clientProfile: clientProfile,
                    displayName: displayName,
                    clientGender: clientGender,
                    selectedCityId: selectedCityId,
                    cityName: cityName,
                    preferredVenue: preferredVenue,
                  ),

                  // TAB 1: Find Trainer
                  _buildFindTrainerTab(
                    context: context,
                    sf: sf,
                    uid: uid,
                    clientGender: clientGender,
                    selectedCityId: selectedCityId,
                    cityName: cityName,
                  ),

                  // TAB 2: Bookings
                  _buildBookingsTab(
                    context: context,
                    sf: sf,
                    uid: uid,
                    clientGender: clientGender,
                  ),

                  // TAB 3: Messages
                  _buildMessagesTab(
                    context: context,
                    sf: sf,
                    uid: uid,
                    displayName: displayName,
                    clientGender: clientGender,
                  ),

                  // TAB 4: Profile
                  _buildProfileTab(
                    context: context,
                    sf: sf,
                    uid: uid,
                    clientUser: clientUser,
                    clientProfile: clientProfile,
                    displayName: displayName,
                    clientGender: clientGender,
                    cityName: cityName,
                    preferredVenue: preferredVenue,
                  ),
                ],
              ),
              bottomNavigationBar: ClientBottomNav(
                currentIndex: _currentTab,
                onTap: (index) => setState(() => _currentTab = index),
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 0: HOME DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHomeTab({
    required BuildContext context,
    required double sf,
    required String uid,
    required UserModel? clientUser,
    required ClientProfileModel? clientProfile,
    required String displayName,
    required Gender clientGender,
    required String selectedCityId,
    required String cityName,
    required String preferredVenue,
  }) {
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.065).clamp(18.0, 28.0);
    final genderStr = clientGender == Gender.female ? 'Female' : 'Male';

    return SingleChildScrollView(
      controller: _homeScrollController,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Welcome & Greeting Section ──
          Row(
            children: [
              GestureDetector(
                onTap: () => _switchTab(4),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: (26.0 * sf).clamp(22.0, 30.0),
                      backgroundColor: const Color(0xFF111111),
                      backgroundImage: (clientUser?.photoUrl != null && clientUser!.photoUrl!.isNotEmpty)
                          ? NetworkImage(clientUser.photoUrl!)
                          : null,
                      child: (clientUser?.photoUrl == null || clientUser!.photoUrl!.isEmpty)
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (18.0 * sf).clamp(16.0, 22.0),
                                fontWeight: FontWeight.w800,
                                color: kLime,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: kDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.circle, size: 7, color: kLime),
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
                      '${_getGreeting()},',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        color: kGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (20.0 * sf).clamp(17.0, 24.0),
                              fontWeight: FontWeight.w800,
                              color: kDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: Color(0xFF16A34A)),
                      ],
                    ),
                  ],
                ),
              ),
              // Location shortcut button
              IconButton(
                icon: const Icon(Iconsax.location, color: kDark, size: 22),
                tooltip: 'Change City',
                onPressed: () {
                  ClientLocationSheet.show(
                    context,
                    clientId: uid,
                    currentCityId: selectedCityId,
                    currentVenue: preferredVenue,
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 2. Prominent Search Bar ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: TextField(
              controller: _homeSearchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  _switchTab(1, searchQuery: query.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'Search $genderStr trainers by name or specialty...',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.0 * sf).clamp(11.0, 13.5),
                  color: const Color(0xFFA0A0A0),
                ),
                prefixIcon: const Icon(Iconsax.search_normal_1, color: kDark, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Iconsax.arrow_right_3, color: kDark, size: 18),
                  onPressed: () {
                    final query = _homeSearchController.text.trim();
                    _switchTab(1, searchQuery: query.isNotEmpty ? query : null);
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 3. Gender Alignment & Area Security Banner ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    clientGender == Gender.female ? Icons.female : Icons.male,
                    size: 16,
                    color: kLime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matching with $genderStr Coaches in $cityName',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (12.0 * sf).clamp(11.0, 13.5),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Venue: $preferredVenue • Strict 1-on-1 backend verified.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (10.0 * sf).clamp(9.0, 11.5),
                          color: kGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── 4. Real-time Session Credits Card (Double-Entry Balance) ──
          StreamBuilder<SessionCreditModel?>(
            stream: CreditService().streamClientCredits(uid),
            builder: (context, creditSnap) {
              final credits = creditSnap.data;
              final available = credits?.availableBalance ?? 0;
              final reserved = credits?.totalReserved ?? 0;
              final consumed = credits?.totalConsumed ?? 0;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SESSION CREDITS',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (11.0 * sf).clamp(10.0, 12.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFAAAAAA),
                            letterSpacing: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kLime.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '60 Min / Session',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (10.0 * sf).clamp(9.0, 11.5),
                              fontWeight: FontWeight.w700,
                              color: kLime,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$available',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (42.0 * sf).clamp(34.0, 50.0),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Available Sessions',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (13.0 * sf).clamp(12.0, 15.0),
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFCCCCCC),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _scrollToPackages,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kLime,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '+ Add Credits',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF262626), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reserved: $reserved',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(10.0, 12.5),
                            color: const Color(0xFF999999),
                          ),
                        ),
                        Text(
                          'Completed: $consumed',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(10.0, 12.5),
                            color: const Color(0xFF999999),
                          ),
                        ),
                        InkWell(
                          onTap: _scrollToPackages,
                          child: Text(
                            'View Plans',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.5),
                              fontWeight: FontWeight.w700,
                              color: kLime,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 22),

          // ── 5. Quick Actions Row ──
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Iconsax.search_normal_1,
                  label: 'Find Trainer',
                  sf: sf,
                  onTap: () => _switchTab(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Iconsax.calendar_1,
                  label: 'My Bookings',
                  sf: sf,
                  onTap: () => _switchTab(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Iconsax.card,
                  label: 'My Packages',
                  sf: sf,
                  onTap: _scrollToPackages,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Iconsax.message,
                  label: 'Messages',
                  sf: sf,
                  onTap: () => _switchTab(3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          // ── 6. Upcoming Sessions Section ──
          _SectionHeader(
            title: 'UPCOMING SESSIONS',
            actionLabel: 'View All',
            sf: sf,
            onAction: () => _switchTab(2),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<BookingModel>>(
            stream: FirestoreService().streamClientBookings(uid),
            builder: (context, bookingSnap) {
              if (bookingSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: kDark, strokeWidth: 2),
                  ),
                );
              }

              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);

              final upcoming = (bookingSnap.data ?? [])
                  .where((b) =>
                      b.status == BookingStatus.confirmed &&
                      !b.sessionDate.isBefore(todayStart))
                  .toList();

              if (upcoming.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: const Icon(Iconsax.calendar_remove, size: 24, color: Color(0xFF888888)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No upcoming workouts scheduled',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (13.5 * sf).clamp(12.5, 15.0),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Book a certified coach to lock in your next training session.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.5),
                          color: kGrey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _switchTab(1),
                        icon: const Icon(Iconsax.calendar_add, size: 15, color: kDark),
                        label: const Text(
                          'Schedule Workout',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLime,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: upcoming.take(2).map((booking) {
                  return ClientUpcomingSessionCard(
                    booking: booking,
                    clientId: uid,
                    onCancelled: () => setState(() {}),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 26),

          // ── 7. Featured Trainers Section (Gender & Area Matched) ──
          _SectionHeader(
            title: 'VERIFIED 1-ON-1 COACHES',
            actionLabel: 'See All ($genderStr)',
            sf: sf,
            onAction: () => _switchTab(1),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<TrainerDisplayModel>>(
            stream: FirestoreService().streamApprovedTrainersDisplay(
              clientGender: clientGender,
              cityId: selectedCityId,
            ),
            builder: (context, trainerSnap) {
              if (trainerSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: kDark, strokeWidth: 2),
                  ),
                );
              }

              final trainers = trainerSnap.data ?? [];

              if (trainers.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Iconsax.user_search, size: 28, color: Color(0xFF888888)),
                      const SizedBox(height: 10),
                      Text(
                        'No approved $genderStr coaches in $cityName yet',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (13.5 * sf).clamp(12.5, 15.0),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try switching to Mumbai or Bengaluru, or explore coaches across other launch cities.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (11.0 * sf).clamp(10.0, 12.5),
                          color: kGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          ClientLocationSheet.show(
                            context,
                            clientId: uid,
                            currentCityId: selectedCityId,
                            currentVenue: preferredVenue,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Switch City',
                          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: trainers.take(4).map((trainer) {
                  return ClientTrainerCard(
                    trainer: trainer,
                    clientGender: clientGender,
                    clientId: uid,
                    onBooked: () => setState(() {}),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 26),

          // ── 8. Training Packages Section (Fetched from Firestore) ──
          Container(key: _packagesKey),
          _SectionHeader(
            title: 'PLATFORM PACKAGES & PRICING',
            sf: sf,
          ),
          const SizedBox(height: 4),
          Text(
            'Fixed rates from ₹500. Credits never expire during validity window.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.0 * sf).clamp(10.0, 12.5),
              color: kGrey,
            ),
          ),
          const SizedBox(height: 14),

          StreamBuilder<List<TrainingPlanModel>>(
            stream: FirestoreService().streamTrainingPlans(),
            builder: (context, planSnap) {
              List<TrainingPlanModel> plans = planSnap.data ?? [];

              // Fallback to platform presets if Firestore collection has not yet been seeded
              if (plans.isEmpty) {
                plans = AppConstants.fixedTrainingPlans.map((p) {
                  return TrainingPlanModel(
                    id: p['id'] as String,
                    title: p['title'] as String,
                    price: p['price'] as int,
                    sessionsCount: p['sessions'] as int,
                    validityDays: p['validityDays'] as int,
                    description: p['description'] as String,
                    popular: p['popular'] as bool? ?? false,
                  );
                }).toList();
              }

              return SizedBox(
                height: 270,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return ClientPackageCard(
                      plan: plan,
                      clientId: uid,
                      onPurchased: () => setState(() {}),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: FIND TRAINER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFindTrainerTab({
    required BuildContext context,
    required double sf,
    required String uid,
    required Gender clientGender,
    required String selectedCityId,
    required String cityName,
  }) {
    final genderStr = clientGender == Gender.female ? 'Female' : 'Male';
    final effectiveCityId = _filterState.cityId ?? selectedCityId;
    final effectiveCityName = AppConstants.initialLaunchCities.firstWhere(
      (c) => c['id'] == effectiveCityId,
      orElse: () => {'name': cityName},
    )['name'] as String;

    final quickSpecialties = [
      'All',
      'Hypertrophy & Strength',
      'Calisthenics',
      'HIIT & Conditioning',
      'Fat Loss',
      'Core & Mobility',
      'Form Correction',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title & Matching Banner ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Your Coach',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (22.0 * sf).clamp(18.0, 26.0),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Approved $genderStr trainers in $effectiveCityName • Strict 1-on-1 verified.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        color: kGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Search Bar ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: TextField(
              controller: _findTrainerSearchController,
              onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by coach name, specialty, goal or gym...',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.0 * sf).clamp(11.0, 13.5),
                  color: const Color(0xFFA0A0A0),
                ),
                prefixIcon: const Icon(Iconsax.search_normal_1, color: kDark, size: 18),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: kGrey),
                        onPressed: () {
                          _findTrainerSearchController.clear();
                          setState(() => _searchFilter = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Action Row: Sort Dropdown & Filter Sheet Trigger ──
          Row(
            children: [
              // Sort Menu Button
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy = val);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rating',
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Text('Highest Rating', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'experience',
                    child: Row(
                      children: [
                        Icon(Iconsax.award, size: 18, color: kDark),
                        SizedBox(width: 8),
                        Text('Most Experience', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'relevance',
                    child: Row(
                      children: [
                        Icon(Iconsax.magicpen, size: 18, color: kDark),
                        SizedBox(width: 8),
                        Text('Relevance', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortBy == 'rating'
                            ? Icons.star_rounded
                            : _sortBy == 'experience'
                                ? Iconsax.award
                                : Iconsax.magicpen,
                        size: 14,
                        color: _sortBy == 'rating' ? const Color(0xFFD97706) : kDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sortBy == 'rating'
                            ? 'Top Rated'
                            : _sortBy == 'experience'
                                ? 'Experience'
                                : 'Relevance',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (11.0 * sf).clamp(10.0, 12.5),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16, color: kDark),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Filter Sheet Trigger Button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  TrainerFilterSheet.show(
                    context,
                    initialFilter: _filterState,
                    onApply: (applied) {
                      setState(() {
                        _filterState = applied;
                        if (applied.specializations.isNotEmpty) {
                          _selectedSpecialty = applied.specializations.first;
                        }
                      });
                    },
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filterState.hasActiveFilters ? kDark : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _filterState.hasActiveFilters ? kDark : const Color(0xFFE5E5E5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.filter_search,
                        size: 14,
                        color: _filterState.hasActiveFilters ? kLime : kDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (11.0 * sf).clamp(10.0, 12.5),
                          fontWeight: FontWeight.w700,
                          color: _filterState.hasActiveFilters ? Colors.white : kDark,
                        ),
                      ),
                      if (_filterState.activeFilterCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: kLime,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_filterState.activeFilterCount}',
                            style: const TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: kDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Reset All shortcut if active
              if (_filterState.hasActiveFilters || _searchFilter.isNotEmpty || _selectedSpecialty != 'All')
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _findTrainerSearchController.clear();
                    setState(() {
                      _searchFilter = '';
                      _selectedSpecialty = 'All';
                      _filterState = const TrainerFilterState();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Quick Specialty Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: quickSpecialties.map((spec) {
                final isSelected = _selectedSpecialty == spec;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(spec),
                    selected: isSelected,
                    selectedColor: kDark,
                    backgroundColor: const Color(0xFFF7F7F7),
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.5 * sf).clamp(9.5, 12.0),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.white : kDark,
                    ),
                    checkmarkColor: kLime,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? kLime : const Color(0xFFEEEEEE),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedSpecialty = spec;
                          if (spec != 'All') {
                            _filterState = _filterState.copyWith(specializations: {spec});
                          } else {
                            _filterState = _filterState.copyWith(specializations: {});
                          }
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Live Trainer Stream List ──
          Expanded(
            child: StreamBuilder<List<TrainerDisplayModel>>(
              stream: FirestoreService().streamApprovedTrainersDisplay(
                clientGender: clientGender,
                cityId: effectiveCityId,
              ),
              builder: (context, trainerSnap) {
                if (trainerSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kDark));
                }

                if (trainerSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load trainers',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (14.0 * sf).clamp(13.0, 16.0),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${trainerSnap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.5),
                              color: kGrey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Retry', style: TextStyle(fontFamily: 'Syne', color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var list = trainerSnap.data ?? [];

                // ── Search Query Filter ──
                if (_searchFilter.isNotEmpty) {
                  list = list.where((t) {
                    final q = _searchFilter;
                    final nameMatch = t.displayName.toLowerCase().contains(q);
                    final gymMatch = (t.gymName ?? '').toLowerCase().contains(q);
                    final areaMatch = (t.serviceArea ?? '').toLowerCase().contains(q);
                    final specMatch = t.specialties.any((s) => s.toLowerCase().contains(q));
                    final goalMatch = t.trainingGoals.any((g) => g.toLowerCase().contains(q));
                    final expMatch = t.experienceText.toLowerCase().contains(q) ||
                        '${t.experienceYears} years'.contains(q);
                    final certMatch = t.certifications.any((c) => c.toLowerCase().contains(q));
                    final bioMatch = (t.profile.bio ?? '').toLowerCase().contains(q);
                    return nameMatch ||
                        gymMatch ||
                        areaMatch ||
                        specMatch ||
                        goalMatch ||
                        expMatch ||
                        certMatch ||
                        bioMatch;
                  }).toList();
                }

                // ── Specialization Filter ──
                if (_filterState.specializations.isNotEmpty) {
                  list = list.where((t) {
                    return _filterState.specializations.any((spec) => t.specialties.contains(spec));
                  }).toList();
                } else if (_selectedSpecialty != 'All') {
                  list = list.where((t) => t.specialties.contains(_selectedSpecialty)).toList();
                }

                // ── Experience Filter ──
                if (_filterState.experienceLevel != 'All') {
                  list = list.where((t) {
                    final exp = t.experienceYears;
                    if (_filterState.experienceLevel == '1-3 years') return exp >= 1 && exp <= 3;
                    if (_filterState.experienceLevel == '3-5 years') return exp >= 3 && exp <= 5;
                    if (_filterState.experienceLevel == '5+ years') return exp >= 5;
                    return true;
                  }).toList();
                }

                // ── Rating Filter ──
                if (_filterState.minRating > 0.0) {
                  list = list.where((t) => t.rating >= _filterState.minRating).toList();
                }

                // ── Available Slots Filter ──
                if (_filterState.availableSlotsOnly) {
                  list = list.where((t) => t.hasAvailableSlots).toList();
                }

                // ── Training Goals Filter ──
                if (_filterState.trainingGoals.isNotEmpty) {
                  list = list.where((t) {
                    return _filterState.trainingGoals.any(
                      (g) => t.trainingGoals.contains(g) || t.specialties.contains(g),
                    );
                  }).toList();
                }

                // ── Sorting ──
                final sortedList = List<TrainerDisplayModel>.from(list);
                switch (_sortBy) {
                  case 'experience':
                    sortedList.sort((a, b) {
                      final cmp = b.experienceYears.compareTo(a.experienceYears);
                      if (cmp != 0) return cmp;
                      return b.rating.compareTo(a.rating);
                    });
                    break;
                  case 'relevance':
                    if (_searchFilter.isNotEmpty) {
                      final q = _searchFilter;
                      sortedList.sort((a, b) {
                        final aName = a.displayName.toLowerCase().contains(q) ? 1 : 0;
                        final bName = b.displayName.toLowerCase().contains(q) ? 1 : 0;
                        if (aName != bName) return bName.compareTo(aName);
                        return b.rating.compareTo(a.rating);
                      });
                    } else {
                      sortedList.sort((a, b) {
                        if (a.hasAvailableSlots != b.hasAvailableSlots) {
                          return a.hasAvailableSlots ? -1 : 1;
                        }
                        return b.rating.compareTo(a.rating);
                      });
                    }
                    break;
                  case 'rating':
                  default:
                    sortedList.sort((a, b) {
                      final cmp = b.rating.compareTo(a.rating);
                      if (cmp != 0) return cmp;
                      return b.totalReviews.compareTo(a.totalReviews);
                    });
                    break;
                }

                // ── Empty State ──
                if (sortedList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF7F7F7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.user_search, size: 36, color: Color(0xFF888888)),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No matching coaches found',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (15.0 * sf).clamp(14.0, 17.0),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No verified $genderStr coaches match your search or filters in $effectiveCityName. Try expanding your criteria.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.5),
                              color: kGrey,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _findTrainerSearchController.clear();
                              setState(() {
                                _searchFilter = '';
                                _selectedSpecialty = 'All';
                                _filterState = const TrainerFilterState();
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 16, color: kDark),
                            label: const Text(
                              'Reset All Filters',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kDark,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kLime,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayed = sortedList.take(_trainerLimit).toList();
                final hasMore = sortedList.length > _trainerLimit;

                return RefreshIndicator(
                  color: kDark,
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.builder(
                    controller: _findTrainerScrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: displayed.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < displayed.length) {
                        final trainer = displayed[index];
                        return ClientTrainerCard(
                          trainer: trainer,
                          clientGender: clientGender,
                          clientId: uid,
                          onBooked: () => setState(() {}),
                        );
                      } else {
                        // Pagination Load More Card / Button
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _trainerLimit += 10;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDDDDDD)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Load More Coaches (${sortedList.length - _trainerLimit} remaining)',
                                style: const TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: BOOKINGS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBookingsTab({
    required BuildContext context,
    required double sf,
    required String uid,
    required Gender clientGender,
  }) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Workouts',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (22.0 * sf).clamp(18.0, 26.0),
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                    ),
                    Text(
                      'Manage confirmed sessions and booking requests.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.5, 13.0),
                        color: kGrey,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Iconsax.calendar_add, color: kDark),
                  tooltip: 'Book New Session',
                  onPressed: () => _switchTab(1),
                ),
              ],
            ),
          ),

          // Sub-tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: kDark,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: kLime,
              unselectedLabelColor: kGrey,
              labelStyle: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
              tabs: const [
                Tab(text: 'Confirmed'),
                Tab(text: 'Pending'),
                Tab(text: 'History'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<List<BookingModel>>(
              stream: FirestoreService().streamClientBookings(uid),
              builder: (context, bookingSnap) {
                if (bookingSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kDark));
                }

                final all = bookingSnap.data ?? [];
                final confirmed = all.where((b) => b.status == BookingStatus.confirmed).toList();
                final pending = all.where((b) => b.status == BookingStatus.pending).toList();
                final history = all.where((b) =>
                    b.status != BookingStatus.confirmed &&
                    b.status != BookingStatus.pending).toList();

                return TabBarView(
                  children: [
                    _BookingListTab(
                      bookings: confirmed,
                      clientId: uid,
                      emptyTitle: 'No confirmed upcoming workouts',
                      emptySubtitle: 'Book a certified trainer to see sessions here.',
                      sf: sf,
                      onBookNew: () => _switchTab(1),
                      onCancelled: () => setState(() {}),
                    ),
                    _BookingListTab(
                      bookings: pending,
                      clientId: uid,
                      emptyTitle: 'No pending booking requests',
                      emptySubtitle: 'When you request a session, it appears here until coach approval.',
                      sf: sf,
                      onBookNew: () => _switchTab(1),
                      onCancelled: () => setState(() {}),
                    ),
                    _BookingListTab(
                      bookings: history,
                      clientId: uid,
                      emptyTitle: 'No session history yet',
                      emptySubtitle: 'Completed workouts and refunded cancellations will appear here.',
                      sf: sf,
                      onBookNew: () => _switchTab(1),
                      onCancelled: () => setState(() {}),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessagesTab({
    required BuildContext context,
    required double sf,
    required String uid,
    required String displayName,
    required Gender clientGender,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Messages',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (22.0 * sf).clamp(18.0, 26.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Direct communication with your booked 1-on-1 trainers.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (11.5 * sf).clamp(10.5, 13.0),
              color: kGrey,
            ),
          ),

          const SizedBox(height: 20),

          // Security & Safety Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Direct chat activates automatically with trainers once a training session is requested or confirmed.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                      color: const Color(0xFF555555),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Message Thread Previews
          Expanded(
            child: StreamBuilder<List<BookingModel>>(
              stream: FirestoreService().streamClientBookings(uid),
              builder: (context, snap) {
                final bookings = snap.data ?? [];
                final coachNames = <String>{};
                for (final b in bookings) {
                  coachNames.add(b.displayTrainerName);
                }

                if (coachNames.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.message_notif, size: 44, color: Color(0xFFB0B0B0)),
                          const SizedBox(height: 14),
                          Text(
                            'No active chats yet',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (14.5 * sf).clamp(13.0, 16.5),
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Book a coach to discuss workout routines, meeting venues, and progressive targets.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (11.0 * sf).clamp(10.0, 12.5),
                              color: kGrey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _switchTab(1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: const Text(
                              'Browse Trainers',
                              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kLime),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  children: coachNames.map((name) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: kDark,
                            child: Text(
                              name.isNotEmpty ? name[0] : 'C',
                              style: const TextStyle(fontFamily: 'Syne', color: kLime, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Syne',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kDark,
                                      ),
                                    ),
                                    const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ready for upcoming workout session.',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Iconsax.message, size: 18, color: kDark),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Direct chat thread with $name ready!')),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab({
    required BuildContext context,
    required double sf,
    required String uid,
    required UserModel? clientUser,
    required ClientProfileModel? clientProfile,
    required String displayName,
    required Gender clientGender,
    required String cityName,
    required String preferredVenue,
  }) {
    final genderStr = clientGender == Gender.female ? 'Female' : 'Male';
    final completion = clientProfile?.calculateCompletion(
          hasName: clientUser?.displayName != null && clientUser!.displayName!.trim().length >= 2,
          hasPhone: clientUser?.phoneNumber != null && clientUser!.phoneNumber!.trim().isNotEmpty,
          hasPhoto: clientUser?.photoUrl != null && clientUser!.photoUrl!.isNotEmpty,
          hasGender: clientUser?.gender != null,
        ) ??
        (clientUser?.isOnboarded == true ? 100 : 40);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Profile',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (22.0 * sf).clamp(18.0, 26.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ClientProfileSetupScreen(isEditMode: true),
                    ),
                  );
                },
                icon: const Icon(Iconsax.edit_2, size: 14, color: kDark),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: kDark, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // User Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: kDark,
                  backgroundImage: (clientUser?.photoUrl != null && clientUser!.photoUrl!.isNotEmpty)
                      ? NetworkImage(clientUser.photoUrl!)
                      : null,
                  child: (clientUser?.photoUrl == null || clientUser!.photoUrl!.isEmpty)
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                          style: const TextStyle(fontFamily: 'Syne', fontSize: 22, color: kLime, fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontFamily: 'Syne', fontSize: 16, fontWeight: FontWeight.w800, color: kDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clientUser?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                      ),
                      if (clientUser?.phoneNumber != null && clientUser!.phoneNumber!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          clientUser.phoneNumber!,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF666666)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Profile Completion Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Completion',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: (12.0 * sf).clamp(11.0, 13.5),
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    Text(
                      '$completion%',
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completion / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: const AlwaysStoppedAnimation<Color>(kLime),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Gender Lock Badge (Section 5)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                Icon(clientGender == Gender.female ? Icons.female : Icons.male, size: 20, color: kDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Gender: $genderStr Athlete',
                            style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13, color: kDark),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.lock, size: 12, color: kGrey),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Locked to protect 1-on-1 coach matching rules.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: kGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Location & Preferences
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Location & Workout Venue',
                      style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13, color: kDark),
                    ),
                    InkWell(
                      onTap: () {
                        ClientLocationSheet.show(
                          context,
                          clientId: uid,
                          currentCityId: clientProfile?.preferredCityId ?? 'city_mumbai',
                          currentVenue: preferredVenue,
                        );
                      },
                      child: const Text(
                        'Change',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: kDark, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('City: $cityName', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF444444))),
                const SizedBox(height: 4),
                Text('Preferred Venue: $preferredVenue', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF444444))),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Fitness Targets
          if (clientProfile != null && clientProfile.fitnessGoals.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fitness Goals & Focus',
                    style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13, color: kDark),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: clientProfile.fitnessGoals.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(g, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kDark)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Sign Out Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showLogoutDialog(context),
              icon: const Icon(Iconsax.logout, color: Color(0xFFDC2626), size: 16),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECACA)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double sf;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (11.5 * sf).clamp(10.5, 13.0),
            fontWeight: FontWeight.w800,
            color: const Color(0xFF888888),
            letterSpacing: 0.8,
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.0 * sf).clamp(10.0, 12.5),
                fontWeight: FontWeight.w700,
                color: kDark,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double sf;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.sf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Icon(icon, size: (16.0 * sf).clamp(14.0, 18.0), color: kDark),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (10.0 * sf).clamp(9.0, 11.5),
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingListTab extends StatelessWidget {
  final List<BookingModel> bookings;
  final String clientId;
  final String emptyTitle;
  final String emptySubtitle;
  final double sf;
  final VoidCallback onBookNew;
  final VoidCallback onCancelled;

  const _BookingListTab({
    required this.bookings,
    required this.clientId,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.sf,
    required this.onBookNew,
    required this.onCancelled,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.calendar_remove, size: 40, color: Color(0xFFB0B0B0)),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (14.0 * sf).clamp(13.0, 16.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (11.0 * sf).clamp(10.0, 12.5),
                  color: kGrey,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onBookNew,
                icon: const Icon(Iconsax.calendar_add, size: 15, color: kDark),
                label: const Text(
                  'Book a Session',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, color: kDark),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLime,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        return ClientUpcomingSessionCard(
          booking: b,
          clientId: clientId,
          onCancelled: onCancelled,
        );
      },
    );
  }
}
