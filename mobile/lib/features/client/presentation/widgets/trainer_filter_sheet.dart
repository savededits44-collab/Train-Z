import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/app_widgets.dart';

/// Filter state parameters for discovering trainers
class TrainerFilterState {
  final Set<String> specializations;
  final String experienceLevel; // 'All', '1-3 years', '3-5 years', '5+ years'
  final double minRating; // 0.0, 4.0, 4.5, 4.8
  final String? cityId; // null = any or client's current city
  final bool availableSlotsOnly;
  final Set<String> trainingGoals;

  const TrainerFilterState({
    this.specializations = const {},
    this.experienceLevel = 'All',
    this.minRating = 0.0,
    this.cityId,
    this.availableSlotsOnly = false,
    this.trainingGoals = const {},
  });

  bool get hasActiveFilters =>
      specializations.isNotEmpty ||
      experienceLevel != 'All' ||
      minRating > 0.0 ||
      (cityId != null && cityId!.isNotEmpty) ||
      availableSlotsOnly ||
      trainingGoals.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (specializations.isNotEmpty) count += specializations.length;
    if (experienceLevel != 'All') count += 1;
    if (minRating > 0.0) count += 1;
    if (cityId != null && cityId!.isNotEmpty) count += 1;
    if (availableSlotsOnly) count += 1;
    if (trainingGoals.isNotEmpty) count += trainingGoals.length;
    return count;
  }

  TrainerFilterState copyWith({
    Set<String>? specializations,
    String? experienceLevel,
    double? minRating,
    String? cityId,
    bool? availableSlotsOnly,
    Set<String>? trainingGoals,
  }) {
    return TrainerFilterState(
      specializations: specializations ?? this.specializations,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      minRating: minRating ?? this.minRating,
      cityId: cityId ?? this.cityId,
      availableSlotsOnly: availableSlotsOnly ?? this.availableSlotsOnly,
      trainingGoals: trainingGoals ?? this.trainingGoals,
    );
  }
}

/// Comprehensive filter bottom sheet for the Find Trainer section
class TrainerFilterSheet extends StatefulWidget {
  final TrainerFilterState initialFilter;
  final ValueChanged<TrainerFilterState> onApply;

  const TrainerFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required TrainerFilterState initialFilter,
    required ValueChanged<TrainerFilterState> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrainerFilterSheet(
        initialFilter: initialFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<TrainerFilterSheet> createState() => _TrainerFilterSheetState();
}

class _TrainerFilterSheetState extends State<TrainerFilterSheet> {
  late Set<String> _specializations;
  late String _experienceLevel;
  late double _minRating;
  late String? _cityId;
  late bool _availableSlotsOnly;
  late Set<String> _trainingGoals;

  final List<String> _specialtyOptions = [
    'Hypertrophy & Strength',
    'Calisthenics',
    'HIIT & Conditioning',
    'Fat Loss',
    'Core & Mobility',
    'Form Correction',
    'Boxing & Martial Arts',
    'Yoga & Mobility',
  ];

  final List<String> _goalOptions = [
    'Build Muscle & Strength',
    'Fat Loss & Body Recomp',
    'Cardio & Stamina',
    'Functional Mobility',
    'Athletic Peak Performance',
  ];

  final List<String> _experienceOptions = [
    'All',
    '1-3 years',
    '3-5 years',
    '5+ years',
  ];

  final List<double> _ratingOptions = [0.0, 4.0, 4.5, 4.8];

  @override
  void initState() {
    super.initState();
    _specializations = Set.from(widget.initialFilter.specializations);
    _experienceLevel = widget.initialFilter.experienceLevel;
    _minRating = widget.initialFilter.minRating;
    _cityId = widget.initialFilter.cityId;
    _availableSlotsOnly = widget.initialFilter.availableSlotsOnly;
    _trainingGoals = Set.from(widget.initialFilter.trainingGoals);
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _specializations.clear();
      _experienceLevel = 'All';
      _minRating = 0.0;
      _cityId = null;
      _availableSlotsOnly = false;
      _trainingGoals.clear();
    });
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    final filter = TrainerFilterState(
      specializations: _specializations,
      experienceLevel: _experienceLevel,
      minRating: _minRating,
      cityId: _cityId,
      availableSlotsOnly: _availableSlotsOnly,
      trainingGoals: _trainingGoals,
    );
    widget.onApply(filter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final h = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.88),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: kDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Iconsax.filter_edit, color: kLime, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Filters',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: (18.0 * sf).clamp(16.0, 22.0),
                              fontWeight: FontWeight.w800,
                              color: kDark,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _reset,
                        child: const Text(
                          'Reset All',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // Filter Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Availability Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _availableSlotsOnly,
                      activeThumbColor: kDark,
                      activeTrackColor: kLime,
                      title: Text(
                        'Available Slots Only',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (13.5 * sf).clamp(12.5, 15.0),
                          fontWeight: FontWeight.w700,
                          color: kDark,
                        ),
                      ),
                      subtitle: const Text(
                        'Show only trainers with open booking slots.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: kGrey),
                      ),
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _availableSlotsOnly = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // 2. Training Goals
                    _FilterSectionTitle(title: 'TARGET TRAINING GOALS', sf: sf),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _goalOptions.map((goal) {
                        final isSelected = _trainingGoals.contains(goal);
                        return FilterChip(
                          label: Text(goal),
                          selected: isSelected,
                          selectedColor: kDark,
                          backgroundColor: const Color(0xFFF7F7F7),
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(10.0, 12.5),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : kDark,
                          ),
                          checkmarkColor: kLime,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? kLime : const Color(0xFFEEEEEE)),
                          ),
                          onSelected: (selected) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (selected) {
                                _trainingGoals.add(goal);
                              } else {
                                _trainingGoals.remove(goal);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // 3. Training Specialization
                    _FilterSectionTitle(title: 'FITNESS SPECIALIZATION', sf: sf),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _specialtyOptions.map((spec) {
                        final isSelected = _specializations.contains(spec);
                        return FilterChip(
                          label: Text(spec),
                          selected: isSelected,
                          selectedColor: kDark,
                          backgroundColor: const Color(0xFFF7F7F7),
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (11.0 * sf).clamp(10.0, 12.5),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : kDark,
                          ),
                          checkmarkColor: kLime,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? kLime : const Color(0xFFEEEEEE)),
                          ),
                          onSelected: (selected) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (selected) {
                                _specializations.add(spec);
                              } else {
                                _specializations.remove(spec);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // 4. Experience Level
                    _FilterSectionTitle(title: 'YEARS OF COACHING EXPERIENCE', sf: sf),
                    const SizedBox(height: 8),
                    Row(
                      children: _experienceOptions.map((exp) {
                        final isSelected = _experienceLevel == exp;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _experienceLevel = exp);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected ? kDark : const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? kLime : const Color(0xFFEEEEEE),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    exp,
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : kDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // 5. Minimum Rating
                    _FilterSectionTitle(title: 'MINIMUM RATING', sf: sf),
                    const SizedBox(height: 8),
                    Row(
                      children: _ratingOptions.map((rating) {
                        final isSelected = _minRating == rating;
                        final label = rating == 0.0 ? 'All Ratings' : '${rating.toStringAsFixed(1)}+ ★';

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _minRating = rating);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected ? kDark : const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? kLime : const Color(0xFFEEEEEE),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (11.0 * sf).clamp(10.0, 12.5),
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? kLime : kDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // 6. Launch City Filter
                    _FilterSectionTitle(title: 'SERVICE CITY', sf: sf),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _cityId,
                          isExpanded: true,
                          hint: const Text('All Launch Cities', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Launch Cities', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                            ),
                            ...AppConstants.initialLaunchCities.map((city) {
                              return DropdownMenuItem<String?>(
                                value: city['id'] as String,
                                child: Text('${city['name']} (${city['state']})', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _cityId = val),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Apply Action
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: AppPrimaryButton(
                label: 'Apply Filters',
                onTap: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final String title;
  final double sf;

  const _FilterSectionTitle({required this.title, required this.sf});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Syne',
        fontSize: (11.0 * sf).clamp(10.0, 12.5),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF888888),
        letterSpacing: 0.8,
      ),
    );
  }
}
