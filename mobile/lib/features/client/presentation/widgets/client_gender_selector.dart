import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Gender Selector for TRAIN Z Registration.
/// Male clients book male trainers; female clients book female trainers.
class ClientGenderSelector extends StatelessWidget {
  final Gender? selectedGender;
  final ValueChanged<Gender> onGenderSelected;

  const ClientGenderSelector({
    super.key,
    required this.selectedGender,
    required this.onGenderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final cardH = (64.0 * sf).clamp(56.0, 72.0);
    final fontSize = (13.5 * sf).clamp(12.0, 15.0);
    final iconSize = (20.0 * sf).clamp(18.0, 24.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Your Gender',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.5 * sf).clamp(11.0, 14.0),
                fontWeight: FontWeight.w600,
                color: kDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Male Option
            Expanded(
              child: _GenderOptionCard(
                label: 'Male',
                icon: Icons.male_rounded,
                isSelected: selectedGender == Gender.male,
                cardHeight: cardH,
                fontSize: fontSize,
                iconSize: iconSize,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onGenderSelected(Gender.male);
                },
              ),
            ),
            const SizedBox(width: 12),
            // Female Option
            Expanded(
              child: _GenderOptionCard(
                label: 'Female',
                icon: Icons.female_rounded,
                isSelected: selectedGender == Gender.female,
                cardHeight: cardH,
                fontSize: fontSize,
                iconSize: iconSize,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onGenderSelected(Gender.female);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final double cardHeight;
  final double fontSize;
  final double iconSize;
  final VoidCallback onTap;

  const _GenderOptionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.cardHeight,
    required this.fontSize,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: cardHeight,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? kLime : const Color(0xFFEEEEEE),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: kLime.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? kLime : const Color(0xFF888888),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : kDark,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

