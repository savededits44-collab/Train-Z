import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';

class TrainerCategoryCard extends StatelessWidget {
  final TrainerCategory category;
  final bool isSelected;
  final VoidCallback? onTap;

  const TrainerCategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final isComingSoon = !category.isAvailableAtLaunch;

    return Opacity(
      opacity: isComingSoon ? 0.6 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isComingSoon ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: EdgeInsets.all((16.0 * sf).clamp(14.0, 20.0)),
          decoration: BoxDecoration(
            color: isSelected ? kDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? kDark : kBorder,
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title & Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.12) : kField,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: isSelected ? kLime : kDark,
                      size: (20.0 * sf).clamp(18.0, 24.0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              category.displayName,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: (16.0 * sf).clamp(14.0, 19.0),
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : kDark,
                              ),
                            ),
                            if (isComingSoon) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF5252),
                                  ),
                                ),
                              ),
                            ] else if (category == TrainerCategory.advancedTrainer) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kLime.withValues(alpha: 0.2)
                                      : kLime.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '3.5+ Yrs Exp',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? kLime : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isComingSoon)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? kLime : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? kLime : kGrey.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: kDark,
                              size: 14,
                            )
                          : null,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Requirements
              Text(
                'Requirement: ${category.requirementText}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.0 * sf).clamp(11.0, 13.5),
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF424242),
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 6),

              // Package & Rate Rules
              Text(
                'Platform Rule: ${category.packageRuleText}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (11.5 * sf).clamp(10.5, 12.5),
                  fontWeight: FontWeight.w400,
                  color: isSelected ? Colors.white.withValues(alpha: 0.65) : kGrey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(TrainerCategory cat) {
    switch (cat) {
      case TrainerCategory.trainer:
        return Iconsax.user_octagon;
      case TrainerCategory.advancedTrainer:
        return Iconsax.medal_star;
      case TrainerCategory.professionalTrainer:
        return Iconsax.crown;
    }
  }
}
