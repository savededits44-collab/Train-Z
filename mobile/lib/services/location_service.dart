import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/city_model.dart';

/// Centralized, app-wide Location & City Management Service for TRAIN Z.
///
/// Ensures a single source of truth for:
/// 1. Currently selected city across all screens and flows.
/// 2. Active vs. inactive city registration (Pune active; Mumbai, Delhi, Bengaluru, Hyderabad inactive).
/// 3. Persistence across app restarts (via SharedPreferences + Firestore client profile sync).
/// 4. Careful migration of legacy default records (e.g. old 'city_mumbai' -> 'city_pune').
class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  static LocationService get instance => _instance;
  LocationService._internal();

  // Storage Keys
  static const String prefSelectedCityKey = 'trainz_selected_city_id';
  static const String prefSelectedVenueKey = 'trainz_selected_venue';

  // Default Launch City (Pune, Maharashtra, India)
  static const String defaultCityId = 'city_pune';
  static const String defaultCityName = 'Pune';
  static const String defaultStateName = 'Maharashtra';
  static const String defaultCountryName = 'India';

  static const CityModel puneDefault = CityModel(
    id: defaultCityId,
    name: defaultCityName,
    state: defaultStateName,
    country: defaultCountryName,
    isActive: true,
    latitude: 18.5204,
    longitude: 73.8567,
  );

  // In-memory state
  CityModel _currentCity = puneDefault;
  String _currentVenue = 'Commercial Gym';
  List<CityModel> _availableCities = _buildInitialCityList();
  bool _isInitialized = false;

  StreamSubscription<QuerySnapshot>? _citiesSubscription;
  StreamSubscription<User?>? _authSubscription;

  // ── Getters ──
  CityModel get currentCity => _currentCity;
  String get currentCityId => _currentCity.id;
  String get currentCityName => _currentCity.name;
  String get currentCityState => _currentCity.state;
  String get currentFormattedLocation => '${_currentCity.name}, ${_currentCity.state}';
  String get currentVenue => _currentVenue;
  bool get isInitialized => _isInitialized;

  List<CityModel> get allCities => List.unmodifiable(_availableCities);
  List<CityModel> get activeCities => List.unmodifiable(_availableCities.where((c) => c.isActive).toList());

  static List<CityModel> _buildInitialCityList() {
    return AppConstants.initialLaunchCities.map((c) {
      return CityModel(
        id: c['id'] as String,
        name: c['name'] as String,
        state: c['state'] as String,
        country: c['country'] as String? ?? 'India',
        isActive: c['isActive'] as bool? ?? false,
        latitude: (c['lat'] as num?)?.toDouble(),
        longitude: (c['lng'] as num?)?.toDouble(),
      );
    }).toList();
  }

  /// Check whether a given city is officially active on the platform.
  bool isCityActive(String? cityId) {
    if (cityId == null || cityId.isEmpty) return false;
    final match = _availableCities.firstWhere(
      (c) => c.id == cityId,
      orElse: () => const CityModel(id: '', name: '', state: '', isActive: false),
    );
    return match.isActive;
  }

  /// Get CityModel by ID, or fallback to Pune if not found.
  CityModel getCityOrDefault(String? cityId) {
    if (cityId == null || cityId.isEmpty) return puneDefault;
    return _availableCities.firstWhere(
      (c) => c.id == cityId,
      orElse: () => puneDefault,
    );
  }

  /// Resolves the human-readable city name by ID.
  String getCityName(String? cityId) {
    return getCityOrDefault(cityId).name;
  }

  // ── Initialization & Persistence ──

  /// Initializes the location system on application startup.
  Future<void> initialize({
    SharedPreferences? prefs,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    
    FirebaseFirestore? db = firestore;
    FirebaseAuth? authInstance = auth;
    try {
      db ??= FirebaseFirestore.instance;
    } catch (_) {
      db = null;
    }
    try {
      authInstance ??= FirebaseAuth.instance;
    } catch (_) {
      authInstance = null;
    }

    // 1. Read locally cached city selection
    final cachedCityId = sharedPrefs.getString(prefSelectedCityKey);
    final cachedVenue = sharedPrefs.getString(prefSelectedVenueKey);

    if (cachedVenue != null && cachedVenue.isNotEmpty) {
      _currentVenue = cachedVenue;
    }

    // Migration rule: If cached city is missing, empty, or an old inactive city (e.g. 'city_mumbai'),
    // default/migrate immediately to Pune (the active launch city).
    if (cachedCityId == null || cachedCityId.isEmpty || !isCityActive(cachedCityId)) {
      _currentCity = puneDefault;
      await sharedPrefs.setString(prefSelectedCityKey, defaultCityId);
    } else {
      _currentCity = getCityOrDefault(cachedCityId);
    }

    // 2. Stream cities collection from Firestore (if available) to sync activation status
    if (db != null) {
      try {
        _citiesSubscription?.cancel();
        _citiesSubscription = db.collection(FirestoreCollections.cities).snapshots().listen(
          (snap) {
            if (snap.docs.isNotEmpty) {
              final remoteCities = snap.docs.map((d) => CityModel.fromDocument(d)).toList();
              if (remoteCities.isNotEmpty) {
                _availableCities = remoteCities;
                // If current city became inactive remotely, reset to Pune
                if (!isCityActive(_currentCity.id)) {
                  _currentCity = puneDefault;
                  sharedPrefs.setString(prefSelectedCityKey, defaultCityId);
                }
                notifyListeners();
              }
            }
          },
          onError: (err) {
            debugPrint('LocationService: Remote cities sync notice: $err');
          },
        );
      } catch (e) {
        debugPrint('LocationService: Firestore listener notice: $e');
      }
    }

    // 3. Listen to Auth state & migrate legacy client profile records
    if (authInstance != null && db != null) {
      try {
        _authSubscription?.cancel();
        _authSubscription = authInstance.authStateChanges().listen((user) async {
          if (user != null) {
            await _syncAndMigrateUserProfile(user.uid, db!, sharedPrefs);
          }
        });
      } catch (e) {
        debugPrint('LocationService: Auth listener notice: $e');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Synchronizes user profile location and migrates outdated legacy 'city_mumbai' records.
  Future<void> _syncAndMigrateUserProfile(
    String uid,
    FirebaseFirestore db,
    SharedPreferences sharedPrefs,
  ) async {
    try {
      final docRef = db.collection(FirestoreCollections.clientProfiles).doc(uid);
      final snap = await docRef.get();

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final userCityId = data['preferredCityId'] as String?;
        final userVenue = data['preferredTrainingLocation'] as String?;

        if (userVenue != null && userVenue.isNotEmpty) {
          _currentVenue = userVenue;
          await sharedPrefs.setString(prefSelectedVenueKey, userVenue);
        }

        // If the user's stored profile has an old/inactive city (like city_mumbai) or is null,
        // migrate it to Pune in Firestore so their profile data remains valid.
        if (userCityId == null || userCityId.isEmpty || userCityId == 'city_mumbai' || !isCityActive(userCityId)) {
          _currentCity = puneDefault;
          await sharedPrefs.setString(prefSelectedCityKey, defaultCityId);
          await docRef.set({
            'preferredCityId': defaultCityId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          _currentCity = getCityOrDefault(userCityId);
          await sharedPrefs.setString(prefSelectedCityKey, userCityId);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('LocationService: User profile location sync notice: $e');
    }
  }

  /// Updates the application-wide selected city and training venue.
  ///
  /// Rejects selection of inactive cities for trainer discovery and bookings.
  /// Persists choice locally to [SharedPreferences] and syncs to Firestore client profile.
  Future<bool> setCity(
    String cityId, {
    String? venue,
    String? clientId,
    bool enforceActive = true,
  }) async {
    // Validate city existence
    final targetCity = _availableCities.firstWhere(
      (c) => c.id == cityId,
      orElse: () => const CityModel(id: '', name: '', state: '', isActive: false),
    );

    if (targetCity.id.isEmpty) {
      debugPrint('LocationService: Unknown city id "$cityId"');
      return false;
    }

    // Enforce active launch city requirement
    if (enforceActive && !targetCity.isActive) {
      debugPrint('LocationService: City "${targetCity.name}" is not currently active for bookings.');
      return false;
    }

    _currentCity = targetCity;
    if (venue != null && venue.isNotEmpty) {
      _currentVenue = venue;
    }

    // Persist to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefSelectedCityKey, targetCity.id);
      if (venue != null && venue.isNotEmpty) {
        await prefs.setString(prefSelectedVenueKey, venue);
      }
    } catch (e) {
      debugPrint('LocationService: Local persistence notice: $e');
    }

    // Sync to Firestore client profile if user is logged in
    String? effectiveUid = clientId;
    if (effectiveUid == null) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      try {
        final updates = <String, dynamic>{
          'preferredCityId': targetCity.id,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (venue != null && venue.isNotEmpty) {
          updates['preferredTrainingLocation'] = venue;
        }
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.clientProfiles)
            .doc(effectiveUid)
            .set(updates, SetOptions(merge: true));
      } catch (e) {
        debugPrint('LocationService: Remote Firestore profile update notice: $e');
      }
    }

    notifyListeners();
    return true;
  }

  /// Sets the preferred venue independently.
  Future<void> setVenue(String venue, {String? clientId}) async {
    if (venue.trim().isEmpty) return;
    _currentVenue = venue;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefSelectedVenueKey, venue);
    } catch (_) {}

    String? effectiveUid = clientId;
    if (effectiveUid == null) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.clientProfiles)
            .doc(effectiveUid)
            .set({
          'preferredTrainingLocation': venue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Deterministic reset helper for automated unit and widget tests.
  @visibleForTesting
  void resetForTesting({
    CityModel? city,
    String? venue,
    List<CityModel>? availableCities,
  }) {
    _currentCity = city ?? puneDefault;
    _currentVenue = venue ?? 'Commercial Gym';
    if (availableCities != null) {
      _availableCities = availableCities;
    } else {
      _availableCities = _buildInitialCityList();
    }
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _citiesSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
