import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/services/location_service.dart';
import 'package:trainuspro/services/firestore_service.dart';
import 'package:trainuspro/services/seed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.instance.resetForTesting();
  });

  group('Requirement 1 & 3: Pune Default Active Launch City Invariants', () {
    test('Default launch city constants specify Pune, Maharashtra, India', () {
      expect(LocationService.defaultCityId, 'city_pune');
      expect(LocationService.defaultCityName, 'Pune');
      expect(LocationService.defaultStateName, 'Maharashtra');
      expect(LocationService.defaultCountryName, 'India');

      expect(AppConstants.defaultCityId, 'city_pune');
      expect(AppConstants.defaultCityName, 'Pune');
    });

    test('Pune is the ONLY active launch city in initial platform configuration', () {
      final cities = LocationService.instance.allCities;
      expect(cities.isNotEmpty, true);

      // Verify Pune is present and active
      final pune = cities.firstWhere((c) => c.id == 'city_pune');
      expect(pune.name, 'Pune');
      expect(pune.state, 'Maharashtra');
      expect(pune.isActive, isTrue);

      // Verify expansion cities exist for future scalability but are currently INACTIVE
      final expansionCities = ['city_mumbai', 'city_delhi_ncr', 'city_bengaluru', 'city_hyderabad'];
      for (final id in expansionCities) {
        final city = cities.firstWhere((c) => c.id == id);
        expect(city.isActive, isFalse, reason: '${city.name} must be inactive during Pune launch');
      }

      // Verify activeCities list has exactly 1 city: Pune
      final activeCities = LocationService.instance.activeCities;
      expect(activeCities.length, 1);
      expect(activeCities.first.id, 'city_pune');
    });

    test('Fresh installation defaults immediately to Pune with no prior preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await LocationService.instance.initialize(prefs: prefs);

      expect(LocationService.instance.currentCityId, 'city_pune');
      expect(LocationService.instance.currentCityName, 'Pune');
      expect(LocationService.instance.currentCityState, 'Maharashtra');
      expect(LocationService.instance.currentFormattedLocation, 'Pune, Maharashtra');
      expect(prefs.getString(LocationService.prefSelectedCityKey), 'city_pune');
    });
  });

  group('Requirement 2: Central Reactive Location System & State Propagation', () {
    test('LocationService notifies listeners when city or venue changes', () async {
      int notifyCount = 0;
      void listener() => notifyCount++;

      LocationService.instance.addListener(listener);

      await LocationService.instance.setVenue('Home / Society Gym');
      expect(notifyCount, 1);
      expect(LocationService.instance.currentVenue, 'Home / Society Gym');

      // Reset to Pune triggers notification
      LocationService.instance.resetForTesting();
      expect(notifyCount, 2);

      LocationService.instance.removeListener(listener);
    });

    test('LocationService exposes immutable getters for all and active cities', () {
      final all = LocationService.instance.allCities;
      final active = LocationService.instance.activeCities;

      expect(all.length, greaterThanOrEqualTo(5));
      expect(active.length, 1);

      // Ensure lists cannot be mutated directly
      expect(() => (all as dynamic).add(LocationService.puneDefault), throwsUnsupportedError);
    });

    test('Lookup and formatting helpers resolve correct details', () {
      expect(LocationService.instance.getCityName('city_pune'), 'Pune');
      expect(LocationService.instance.getCityName('city_mumbai'), 'Mumbai');
      expect(LocationService.instance.getCityName('unknown_city'), 'Pune'); // Fallback

      final puneModel = LocationService.instance.getCityOrDefault('city_pune');
      expect(puneModel.id, 'city_pune');
      expect(puneModel.latitude, 18.5204);
      expect(puneModel.longitude, 73.8567);

      final fallbackModel = LocationService.instance.getCityOrDefault(null);
      expect(fallbackModel.id, 'city_pune');
    });
  });

  group('Requirement 4 & 6: Inactive City Protection & Multi-City Architecture', () {
    test('isCityActive accurately reflects platform activation status', () {
      expect(LocationService.instance.isCityActive('city_pune'), isTrue);
      expect(LocationService.instance.isCityActive('city_mumbai'), isFalse);
      expect(LocationService.instance.isCityActive('city_delhi_ncr'), isFalse);
      expect(LocationService.instance.isCityActive('city_bengaluru'), isFalse);
      expect(LocationService.instance.isCityActive('city_hyderabad'), isFalse);
      expect(LocationService.instance.isCityActive(null), isFalse);
      expect(LocationService.instance.isCityActive(''), isFalse);
      expect(LocationService.instance.isCityActive('non_existent'), isFalse);
    });

    test('Selecting an inactive city with enforceActive=true is rejected', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await LocationService.instance.initialize(prefs: prefs);

      expect(LocationService.instance.currentCityId, 'city_pune');

      // Attempt to switch to Mumbai while it is inactive
      final success = await LocationService.instance.setCity('city_mumbai', enforceActive: true);

      expect(success, isFalse);
      // City must remain Pune
      expect(LocationService.instance.currentCityId, 'city_pune');
      expect(LocationService.instance.currentCityName, 'Pune');
    });

    test('Selecting an unknown city is rejected', () async {
      final success = await LocationService.instance.setCity('invalid_city_id');
      expect(success, isFalse);
      expect(LocationService.instance.currentCityId, 'city_pune');
    });
  });

  group('Requirement 5: Legacy Data Migration (Fixing Old Mumbai Defaults)', () {
    test('Migrates legacy cached "city_mumbai" in local storage to "city_pune"', () async {
      // Simulate an app update where the device previously had 'city_mumbai' stored
      SharedPreferences.setMockInitialValues({
        LocationService.prefSelectedCityKey: 'city_mumbai',
        LocationService.prefSelectedVenueKey: 'Commercial Gym',
      });
      final prefs = await SharedPreferences.getInstance();

      // Run initialize
      await LocationService.instance.initialize(prefs: prefs);

      // The service should have recognized that city_mumbai is inactive and migrated to city_pune
      expect(LocationService.instance.currentCityId, 'city_pune');
      expect(LocationService.instance.currentCityName, 'Pune');
      // SharedPreferences should have been updated to city_pune
      expect(prefs.getString(LocationService.prefSelectedCityKey), 'city_pune');
    });

    test('Preserves preferred venue during location initialization', () async {
      SharedPreferences.setMockInitialValues({
        LocationService.prefSelectedCityKey: 'city_pune',
        LocationService.prefSelectedVenueKey: 'Client Residence',
      });
      final prefs = await SharedPreferences.getInstance();

      await LocationService.instance.initialize(prefs: prefs);

      expect(LocationService.instance.currentCityId, 'city_pune');
      expect(LocationService.instance.currentVenue, 'Client Residence');
    });
  });

  group('Requirement 4 & Seed Data: Pune Trainer Service Areas & Booking Address Validation', () {
    test('Approved trainers seed data is located in Pune with authentic service areas', () {
      final seededTrainers = SeedService.initialTrainers;
      expect(seededTrainers.length, 4);

      for (final trainer in seededTrainers) {
        expect(
          trainer['cityId'],
          'city_pune',
          reason: 'Trainer ${trainer['uid']} must be in city_pune',
        );
        expect(
          trainer['status'],
          'ACTIVE',
          reason: 'Trainer ${trainer['uid']} must be ACTIVE',
        );
        expect(
          (trainer['serviceArea'] as String).isNotEmpty,
          isTrue,
          reason: 'Trainer ${trainer['uid']} must have a serviceArea in Pune',
        );
      }

      // Check specific Pune service areas are represented
      final combinedAreas = seededTrainers.map((t) => t['serviceArea'] as String).join(' ');
      expect(combinedAreas.contains('Koregaon Park'), isTrue);
      expect(combinedAreas.contains('Kalyani Nagar'), isTrue);
      expect(combinedAreas.contains('Viman Nagar'), isTrue);
      expect(combinedAreas.contains('Baner'), isTrue);
      expect(combinedAreas.contains('Kothrud'), isTrue);
    });

    test('Address in trainer service area accepts Pune addresses and specific areas', () {
      const trainerCity = 'city_pune';
      const trainerServiceArea = 'Koregaon Park & Kalyani Nagar, Pune';

      // Matches city name "Pune"
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: 'Flat 402, Marvel Basilo, Pune',
          trainerServiceArea: trainerServiceArea,
          trainerCity: trainerCity,
        ),
        isTrue,
      );

      // Matches specific service area "Koregaon Park"
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: 'Lane 7, Koregaon Park, North Main Road',
          trainerServiceArea: trainerServiceArea,
          trainerCity: trainerCity,
        ),
        isTrue,
      );

      // Matches specific service area "Kalyani Nagar"
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: 'Near Jogger Park, Kalyani Nagar',
          trainerServiceArea: trainerServiceArea,
          trainerCity: trainerCity,
        ),
        isTrue,
      );

      // Rejects address in an unserviced city like Mumbai
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: 'Bandra West, Mumbai, Maharashtra',
          trainerServiceArea: 'Koregaon Park & Kalyani Nagar',
          trainerCity: 'city_pune',
        ),
        isFalse,
      );
    });
  });
}
