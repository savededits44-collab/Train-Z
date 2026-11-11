/// Core business constants and configuration presets for TRAIN Z.
class AppConstants {
  AppConstants._();

  static const String appName = 'TrainZ';
  static const String appTagline = 'Transform Your Body.';
  static const String supportEmail = 'support@trainz.app';

  /// Standard session duration in minutes
  static const int sessionDurationMinutes = 60;

  /// Cancellation policy window in hours
  /// >= 12h: Return credit to client
  /// < 12h: Forfeit credit (late cancellation penalty)
  static const int cancellationWindowHours = 12;

  /// Currency code & symbol
  static const String currencyCode = 'INR';
  static const String currencySymbol = '₹';

  /// Fixed Training Plans matching Section 7 of the specification
  static const List<Map<String, dynamic>> fixedTrainingPlans = [
    {
      'id': 'plan_1_day',
      'title': '1 Day',
      'price': 500,
      'sessions': 1,
      'validityDays': 1,
      'sessionDurationMinutes': 60,
      'description': 'Single 60-min personal training session to jumpstart your fitness journey.',
      'popular': false,
    },
    {
      'id': 'plan_3_days',
      'title': '3 Days',
      'price': 1399,
      'sessions': 3,
      'validityDays': 3,
      'sessionDurationMinutes': 60,
      'description': '3 dedicated 1-on-1 sessions for form correction and target routines.',
      'popular': false,
    },
    {
      'id': 'plan_1_week',
      'title': '1 Week',
      'price': 2799,
      'sessions': 6,
      'validityDays': 7,
      'sessionDurationMinutes': 60,
      'description': '6 intensive sessions across 7 days for rapid momentum and consistency.',
      'popular': false,
    },
    {
      'id': 'plan_1_month',
      'title': '1 Month',
      'price': 10799,
      'sessions': 26,
      'validityDays': 30,
      'sessionDurationMinutes': 60,
      'description': '26 sessions designed for comprehensive monthly body recomp and habit mastery.',
      'popular': true,
    },
    {
      'id': 'plan_3_months',
      'title': '3 Months',
      'price': 29999,
      'sessions': 78,
      'validityDays': 90,
      'sessionDurationMinutes': 60,
      'description': '78 sessions over a full quarter for substantial muscle gain and fat loss.',
      'popular': false,
    },
    {
      'id': 'plan_6_months',
      'title': '6-Month Transformation',
      'price': 52999,
      'sessions': 150,
      'validityDays': 180,
      'sessionDurationMinutes': 60,
      'description': '150 sessions for complete physical and lifestyle transformation with elite trainers.',
      'popular': false,
    },
  ];

  /// TRAIN Z Exclusive Operating Location (Pune-Only)
  static const String operatingCity = 'Pune';
  static const String operatingState = 'Maharashtra';
  static const String operatingCountry = 'India';
  static const String operatingLocationDisplay = 'Pune, Maharashtra';

  /// Standard Pune Neighborhood Service Areas
  static const List<String> puneServiceAreas = [
    'Koregaon Park',
    'Baner',
    'Kothrud',
    'Kalyani Nagar',
    'Viman Nagar',
    'Aundh',
    'Shivaji Nagar',
    'Wakad',
    'Hinjawadi',
    'Magarpatta',
    'Senapati Bapat Road',
    'Bavdhan',
  ];

  // Default Platform Launch Location
  static const String defaultCityId = 'city_pune';
  static const String defaultCityName = 'Pune';
  static const String defaultStateName = 'Maharashtra';
  static const String defaultCountryName = 'India';

  /// Initial launch cities in India.
  /// Pune is ACTIVE for initial launch.
  /// Mumbai, Delhi NCR, Bengaluru, and Hyderabad are registered for future expansion (INACTIVE).
  static const List<Map<String, dynamic>> initialLaunchCities = [
    {
      'id': 'city_pune',
      'name': 'Pune',
      'state': 'Maharashtra',
      'country': 'India',
      'isActive': true,
      'lat': 18.5204,
      'lng': 73.8567,
    },
    {
      'id': 'city_mumbai',
      'name': 'Mumbai',
      'state': 'Maharashtra',
      'country': 'India',
      'isActive': false,
      'lat': 19.0760,
      'lng': 72.8777,
    },
    {
      'id': 'city_delhi_ncr',
      'name': 'Delhi NCR',
      'state': 'Delhi',
      'country': 'India',
      'isActive': false,
      'lat': 28.6139,
      'lng': 77.2090,
    },
    {
      'id': 'city_bengaluru',
      'name': 'Bengaluru',
      'state': 'Karnataka',
      'country': 'India',
      'isActive': false,
      'lat': 12.9716,
      'lng': 77.5946,
    },
    {
      'id': 'city_hyderabad',
      'name': 'Hyderabad',
      'state': 'Telangana',
      'country': 'India',
      'isActive': false,
      'lat': 17.3850,
      'lng': 78.4867,
    },
  ];
}

