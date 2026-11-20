import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/firestore_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('TRAIN Z Commercial Gym Location Policy & Invariants', () {
    test('BookingModel displayLocation falls back cleanly to Commercial Partner Gym', () {
      final bookingWithoutLocation = BookingModel(
        id: 'bk_1',
        clientId: 'cl_1',
        trainerId: 'tr_1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 3, 20),
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        status: BookingStatus.confirmed,
        createdAt: DateTime.now(),
      );

      expect(bookingWithoutLocation.displayLocation, equals('Commercial Partner Gym'));

      final bookingWithGym = bookingWithoutLocation.copyWith(
        meetingLocation: 'Gold\'s Gym, Koregaon Park',
      );
      expect(bookingWithGym.displayLocation, equals('Gold\'s Gym, Koregaon Park'));
    });

    test('isProhibitedTrainingLocation accurately flags residential and outdoor addresses', () {
      final invalidLocations = [
        'Client Home, Flat 402, Sunshine Apts',
        'Home training',
        'Outdoor park near society',
        'Residential building gym',
        'House No. 12, Green Avenue',
        'Home Session',
        'My Apartment, Tower 3',
        'Outdoor Jogging Park',
        'Villa No 5, Palm Meadows',
        'Public park workout',
      ];

      for (final loc in invalidLocations) {
        expect(isProhibitedTrainingLocation(loc), isTrue, reason: 'Should flag: $loc');
      }

      final validLocations = [
        'Gold\'s Gym, Koregaon Park',
        'Cult Fitness, Indiranagar',
        'Talwalkars Gym, Bandra',
        'Commercial Partner Gym',
        'Anytime Fitness, Baner',
      ];

      for (final loc in validLocations) {
        expect(isProhibitedTrainingLocation(loc), isFalse, reason: 'Should allow: $loc');
      }
    });

    test('FirestoreService.reserveBookingSlot rejects non-commercial gym locations', () async {
      final invalidLocations = [
        'Client Home, Flat 402, Sunshine Apts',
        'Home training',
        'Outdoor park near society',
        'Residential building gym',
        'House No. 12, Green Avenue',
      ];

      for (final loc in invalidLocations) {
        expect(
          () => FirestoreService().reserveBookingSlot(
            clientId: 'cl_1',
            trainerId: 'tr_1',
            packageId: 'pkg_1',
            sessionDate: DateTime(2026, 4, 10),
            startTime: '09:00 AM',
            endTime: '10:00 AM',
            trainingLocation: loc,
          ),
          throwsA(isA<LocationPolicyException>()),
          reason: 'Expected LocationPolicyException for location: $loc',
        );
      }
    });

    test('BookingService.createBookingRequest enforces commercial gym location', () async {
      final prohibitedLocations = [
        'Home Session',
        'My Apartment, Tower 3',
        'Outdoor Jogging Park',
        'Villa No 5, Palm Meadows',
      ];

      for (final loc in prohibitedLocations) {
        expect(
          () => BookingService.instance.createBookingRequest(
            clientName: 'Rahul',
            clientPhone: '+919876543210',
            sessionDate: DateTime(2026, 4, 15),
            startTime: '08:00 AM',
            endTime: '09:00 AM',
            workoutType: 'Strength & Conditioning',
            meetingLocation: loc,
          ),
          throwsA(isA<LocationPolicyException>()),
          reason: 'BookingService should reject: $loc',
        );
      }
    });

    test('TrainerProfileModel completion requires Commercial Gym Training Affiliation', () {
      const profileNoGym = TrainerProfileModel(
        uid: 'tr_gym_test',
        trainsAtGym: false,
        otherTrainingLocations: [],
      );
      final completionNoGym = profileNoGym.calculateCompletion();
      expect(completionNoGym.missingFields, contains('Commercial Gym Training Affiliation'));

      const profileWithGym = TrainerProfileModel(
        uid: 'tr_gym_test_2',
        trainsAtGym: true,
      );
      final completionWithGym = profileWithGym.calculateCompletion();
      expect(completionWithGym.missingFields, isNot(contains('Commercial Gym Training Affiliation')));
    });

    test('LocationPolicyException formats informative error message', () {
      const ex = LocationPolicyException('All sessions must occur at a verified commercial gym facility.');
      expect(ex.message, contains('verified commercial gym facility'));
      expect(ex.toString(), contains('TrainZException[INVALID_LOCATION]'));
      expect(ex.toString(), contains('verified commercial gym facility'));
    });
  });
}
