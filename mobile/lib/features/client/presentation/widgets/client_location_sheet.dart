import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/location_service.dart';
import '../../../../widgets/app_widgets.dart';

/// Interactive modal sheet allowing clients to select their active launch city
/// and preferred training venue in real time. Synchronized through [LocationService].
class ClientLocationSheet extends StatefulWidget {
  final String clientId;
  final String currentCityId;
  final String? currentVenue;
  final ValueChanged<String>? onCityChanged;

  const ClientLocationSheet({
    super.key,
    required this.clientId,
    required this.currentCityId,
    this.currentVenue,
    this.onCityChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String clientId,
    String? currentCityId,
    String? currentVenue,
    ValueChanged<String>? onCityChanged,
  }) {
    final effectiveCityId = (currentCityId != null && currentCityId.isNotEmpty)
        ? currentCityId
        : LocationService.instance.currentCityId;
    final effectiveVenue = currentVenue ?? LocationService.instance.currentVenue;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClientLocationSheet(
        clientId: clientId,
        currentCityId: effectiveCityId,
        currentVenue: effectiveVenue,
        onCityChanged: onCityChanged,
      ),
    );
  }

  @override
  State<ClientLocationSheet> createState() => _ClientLocationSheetState();
}

class _ClientLocationSheetState extends State<ClientLocationSheet> {
  late String _selectedCityId;
  late String _selectedVenue;
  bool _saving = false;

  final List<String> _venueOptions = [
    'Commercial Gym',
    'Personal Gym / Home',
    'Outdoor Park / Society',
    "Trainer's Private Studio",
  ];

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.currentCityId.isNotEmpty
        ? widget.currentCityId
        : LocationService.instance.currentCityId;
    _selectedVenue = widget.currentVenue ?? LocationService.instance.currentVenue;
  }

  Future<void> _handleSave() async {
    final locService = LocationService.instance;
    if (!locService.isCityActive(_selectedCityId)) {
      final inactiveCity = locService.getCityOrDefault(_selectedCityId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${inactiveCity.name} is scheduled for future platform expansion. Service is not yet available in this city.',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E1E24),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await locService.setCity(
        _selectedCityId,
        venue: _selectedVenue,
        clientId: widget.clientId,
      );

      if (!success) {
        throw Exception('Unable to activate the selected city.');
      }

      widget.onCityChanged?.call(_selectedCityId);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location updated to ${locService.currentFormattedLocation}! Showing trainers in your area.',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update location: $e'),
          backgroundColor: const Color(0xFF1E1E24),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final h = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.85),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.location, color: kLime, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Service Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (18.0 * sf).clamp(16.0, 22.0),
                            fontWeight: FontWeight.w800,
                            color: kDark,
                          ),
                        ),
                        Text(
                          'Select city & venue to filter local approved trainers.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

              const SizedBox(height: 22),

              Text(
                'PLATFORM LOCATIONS',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(10.0, 12.5),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // City List from LocationService
              ...LocationService.instance.allCities.map((city) {
                final isSelected = _selectedCityId == city.id;
                final isActive = city.isActive;

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (!isActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${city.name} will be available in upcoming expansion. Training services will launch here soon.',
                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: const Color(0xFF1E1E24),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    setState(() => _selectedCityId = city.id);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF9FAFB)
                          : (isActive ? Colors.white : const Color(0xFFFAFAFA)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? kDark
                            : (isActive ? const Color(0xFFEEEEEE) : const Color(0xFFE5E7EB)),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : (isActive ? Icons.radio_button_off : Icons.lock_outline),
                          color: isSelected
                              ? kDark
                              : (isActive ? const Color(0xFFB0B0B0) : const Color(0xFFD1D5DB)),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    city.name,
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (13.5 * sf).clamp(12.5, 15.0),
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? kDark : const Color(0xFF888888),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: const Text(
                                        'Coming Soon',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                isActive
                                    ? '${city.state} • Active Launch City'
                                    : '${city.state} • Expansion Phase',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (10.5 * sf).clamp(9.5, 12.0),
                                  color: isActive ? kGrey : const Color(0xFFAAAAAA),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kLime,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 18),

              Text(
                'PREFERRED WORKOUT VENUE',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (11.0 * sf).clamp(10.0, 12.5),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Venue options
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _venueOptions.map((venue) {
                  final isSelected = _selectedVenue == venue;
                  return ChoiceChip(
                    label: Text(venue),
                    selected: isSelected,
                    selectedColor: kDark,
                    backgroundColor: const Color(0xFFF7F7F7),
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(10.5, 13.0),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : kDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? kLime : const Color(0xFFEEEEEE),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedVenue = venue);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              AppPrimaryButton(
                label: 'Save Location Preference',
                loading: _saving,
                onTap: _handleSave,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

