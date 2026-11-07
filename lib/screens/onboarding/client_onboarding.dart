import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../widgets/app_widgets.dart';
import '../client/client_dashboard.dart';

class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
  int _selectedGoal = 0;
  int _selectedLevel = 1;

  final List<String> _goals = [
    'Build Muscle & Strength',
    'Lose Weight & Get Lean',
    'Cardio & Endurance',
    'General Fitness & Health',
  ];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

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
              Text(
                'Personalize\nyour journey.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (28.0 * sf).clamp(22.0, 36.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Help us match you with the best coaches and plans.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                ),
              ),
              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 32.0)),
              Text(
                'What is your primary goal?',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (15.0 * sf).clamp(13.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              SizedBox(height: 12),
              ...List.generate(_goals.length, (i) {
                final selected = _selectedGoal == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selectedGoal = i),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: (14.0 * sf).clamp(12.0, 18.0),
                      ),
                      decoration: BoxDecoration(
                        color: selected ? kDark : kField,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? kDark : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Iconsax.tick_circle : Iconsax.record,
                            size: 18,
                            color: selected ? kLime : const Color(0xFFBBBBBB),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _goals[i],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: (13.0 * sf).clamp(11.0, 14.0),
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected ? Colors.white : kDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              SizedBox(height: (h * 0.02 * sf).clamp(14.0, 24.0)),
              Text(
                'Fitness Level',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (15.0 * sf).clamp(13.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: List.generate(_levels.length, (i) {
                  final selected = _selectedLevel == i;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < _levels.length - 1 ? 8.0 : 0,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedLevel = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? kDark : kField,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _levels[i],
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: (12.0 * sf).clamp(10.0, 13.0),
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected ? Colors.white : kDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: (h * 0.045 * sf).clamp(24.0, 48.0)),
              AppPrimaryButton(
                label: 'Get Started',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const ClientDashboard(),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
