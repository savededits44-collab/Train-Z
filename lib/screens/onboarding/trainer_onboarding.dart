import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../widgets/app_widgets.dart';
import '../trainer/trainer_dashboard.dart';

class TrainerOnboardingScreen extends StatefulWidget {
  const TrainerOnboardingScreen({super.key});

  @override
  State<TrainerOnboardingScreen> createState() =>
      _TrainerOnboardingScreenState();
}

class _TrainerOnboardingScreenState extends State<TrainerOnboardingScreen> {
  final Set<String> _selectedSpecialties = {'Strength & Conditioning'};
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();

  final List<String> _specialties = [
    'Strength & Conditioning',
    'Weight Loss & Diet',
    'HIIT & Cardio',
    'CrossFit Specialist',
    'Yoga & Mobility',
    'Rehabilitation',
  ];

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 40.0)),
              const AppLogo(fontSize: 16),
              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kLime,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Trainer Setup',
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
              const SizedBox(height: 10),
              Text(
                'Coach profile\ncredentials.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (28.0 * sf).clamp(22.0, 36.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Showcase your expertise to prospective athletes.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                ),
              ),
              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 32.0)),
              Text(
                'Specialties',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (15.0 * sf).clamp(13.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _specialties.map((spec) {
                  final selected = _selectedSpecialties.contains(spec);
                  return FilterChip(
                    label: Text(
                      spec,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (11.5 * sf).clamp(10.0, 13.0),
                        color: selected ? Colors.white : kDark,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedSpecialties.add(spec);
                        } else {
                          if (_selectedSpecialties.length > 1) {
                            _selectedSpecialties.remove(spec);
                          }
                        }
                      });
                    },
                    selectedColor: kDark,
                    backgroundColor: kField,
                    checkmarkColor: kLime,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide.none,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: (h * 0.025 * sf).clamp(16.0, 24.0)),
              Text(
                'Years of Experience',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (15.0 * sf).clamp(13.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _experienceController,
                label: 'e.g. 5 Years',
                icon: Iconsax.award,
              ),
              SizedBox(height: (h * 0.02 * sf).clamp(14.0, 20.0)),
              Text(
                'Short Bio / Philosophy',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (15.0 * sf).clamp(13.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _bioController,
                label: 'Brief introduction to clients',
                icon: Iconsax.edit_2,
              ),
              SizedBox(height: (h * 0.045 * sf).clamp(24.0, 48.0)),
              AppPrimaryButton(
                label: 'Complete Setup',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const TrainerDashboard(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
