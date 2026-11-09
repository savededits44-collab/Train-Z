import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_home_screen.dart';

/// Screen displayed when a verified client has not yet completed their fitness preferences.
class ClientProfileCompletionScreen extends StatefulWidget {
  const ClientProfileCompletionScreen({super.key});

  @override
  State<ClientProfileCompletionScreen> createState() =>
      _ClientProfileCompletionScreenState();
}

class _ClientProfileCompletionScreenState
    extends State<ClientProfileCompletionScreen> {
  final _emergencyContactController = TextEditingController();

  int _selectedGoalIndex = 0;
  int _selectedLevelIndex = 1;
  String _selectedCityId = 'city_mumbai';
  bool _saving = false;

  final List<Map<String, dynamic>> _goals = [
    {
      'title': 'Build Muscle & Strength',
      'icon': Icons.fitness_center_rounded,
      'desc': 'Hypertrophy, barbell lifts & progressive overload',
    },
    {
      'title': 'Fat Loss & Body Recomp',
      'icon': Icons.local_fire_department_rounded,
      'desc': 'Caloric deficit, HIIT & high energy conditioning',
    },
    {
      'title': 'Cardio & Stamina',
      'icon': Icons.directions_run_rounded,
      'desc': 'Endurance, functional mobility & VO2 max',
    },
    {
      'title': 'Athletic Peak Performance',
      'icon': Icons.bolt_rounded,
      'desc': 'Speed, agility, power & injury prevention',
    },
  ];

  final List<String> _fitnessLevels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void dispose() {
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final selectedGoal = _goals[_selectedGoalIndex]['title'] as String;
      final selectedLevel = _fitnessLevels[_selectedLevelIndex];
      final emergency = _emergencyContactController.text.trim();

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update client_profiles document
      final clientProfileRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.clientProfiles)
          .doc(uid);

      batch.set(clientProfileRef, {
        'uid': uid,
        'fitnessGoals': [selectedGoal],
        'fitnessLevel': selectedLevel,
        'preferredCityId': _selectedCityId,
        'emergencyContact': emergency.isNotEmpty ? emergency : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Mark user as onboarded in users document
      final userRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid);

      batch.update(userRef, {
        'onboarded': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      setState(() => _saving = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: const Color(0xFF1E1E24),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const AppLogo(fontSize: 16),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.02 * sf).clamp(12.0, 24.0)),

              Text(
                'Complete your\nfitness profile.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (28.0 * sf).clamp(24.0, 36.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Help coaches tailor their personalized sessions to your fitness baseline.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.5 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                  height: 1.4,
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(20.0, 32.0)),

              // ── 1. Primary Fitness Target ──
              Text(
                'PRIMARY FITNESS GOAL',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 10),

              ...List.generate(_goals.length, (index) {
                final goal = _goals[index];
                final isSelected = _selectedGoalIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedGoalIndex = index);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? kLime : const Color(0xFFEEEEEE),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            goal['icon'] as IconData,
                            size: 22,
                            color: isSelected ? kLime : const Color(0xFF888888),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal['title'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (13.5 * sf).clamp(12.0, 15.0),
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : kDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  goal['desc'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: (11.0 * sf).clamp(10.0, 12.5),
                                    color: isSelected ? const Color(0xFFBBBBBB) : kGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // ── 2. Fitness Level ──
              Text(
                'FITNESS EXPERIENCE LEVEL',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: List.generate(_fitnessLevels.length, (index) {
                  final level = _fitnessLevels[index];
                  final isSelected = _selectedLevelIndex == index;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index > 0 ? 6.0 : 0.0,
                        right: index < _fitnessLevels.length - 1 ? 6.0 : 0.0,
                      ),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedLevelIndex = index);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? kLime : const Color(0xFFEEEEEE),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              level,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (12.5 * sf).clamp(11.0, 14.0),
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : kDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // ── 3. City Selection ──
              Text(
                'LAUNCH CITY',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.5 * sf).clamp(10.5, 13.0),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCityId,
                    isExpanded: true,
                    icon: const Icon(Iconsax.arrow_down_1, size: 18, color: kDark),
                    items: AppConstants.initialLaunchCities.map((city) {
                      return DropdownMenuItem<String>(
                        value: city['id'] as String,
                        child: Row(
                          children: [
                            const Icon(Iconsax.location, size: 16, color: Color(0xFF888888)),
                            const SizedBox(width: 8),
                            Text(
                              '${city['name']} (${city['state']})',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (13.0 * sf).clamp(12.0, 14.5),
                                fontWeight: FontWeight.w500,
                                color: kDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCityId = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── 4. Emergency Contact (Optional) ──
              AppTextField(
                controller: _emergencyContactController,
                label: 'Emergency Contact Number (Optional)',
                icon: Iconsax.call_calling,
                keyboardType: TextInputType.phone,
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

              // Save Button
              AppPrimaryButton(
                label: 'Save & Explore Coaches',
                loading: _saving,
                onTap: _handleSaveProfile,
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),
            ],
          ),
        ),
      ),
    );
  }
}

