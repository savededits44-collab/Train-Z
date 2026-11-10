import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../widgets/app_widgets.dart';

/// Premium 5-tab bottom navigation bar for TRAIN Z Client experience.
class ClientBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ClientBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);

    final items = [
      {'icon': Iconsax.home, 'activeIcon': Iconsax.home_1, 'label': 'Home'},
      {'icon': Iconsax.search_normal_1, 'activeIcon': Iconsax.search_normal, 'label': 'Find Trainer'},
      {'icon': Iconsax.calendar_1, 'activeIcon': Iconsax.calendar, 'label': 'Bookings'},
      {'icon': Iconsax.message, 'activeIcon': Iconsax.message_text, 'label': 'Messages'},
      {'icon': Iconsax.user, 'activeIcon': Iconsax.profile_circle, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              return InkWell(
                onTap: () {
                  if (currentIndex != index) {
                    HapticFeedback.selectionClick();
                    onTap(index);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 12 : 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? kDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                        size: (20.0 * sf).clamp(18.0, 22.0),
                        color: isSelected ? kLime : const Color(0xFF888888),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (11.0 * sf).clamp(10.0, 12.0),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

