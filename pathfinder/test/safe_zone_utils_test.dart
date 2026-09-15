import 'package:flutter_test/flutter_test.dart';
import 'package:pathfinder/utils/safe_zone_utils.dart';

void main() {
  group('isInsideSafeZone', () {
    test('returns true when user is at safe-zone centre', () {
      final result = isInsideSafeZone(
        currentLat: 7.2906,
        currentLng: 80.6337,
        zoneLat: 7.2906,
        zoneLng: 80.6337,
        radius: 100,
      );

      expect(result, isTrue);
    });

    test('returns true when user is inside safe zone', () {
      final result = isInsideSafeZone(
        currentLat: 7.2910,
        currentLng: 80.6337,
        zoneLat: 7.2906,
        zoneLng: 80.6337,
        radius: 100,
      );

      expect(result, isTrue);
    });

    test('returns false when user is outside safe zone', () {
      final result = isInsideSafeZone(
        currentLat: 7.2920,
        currentLng: 80.6337,
        zoneLat: 7.2906,
        zoneLng: 80.6337,
        radius: 100,
      );

      expect(result, isFalse);
    });

    test('returns true when user is exactly on the boundary', () {
      const zoneLat = 0.0;
      const zoneLng = 0.0;

      final result = isInsideSafeZone(
        currentLat: 0.0008993,
        currentLng: 0.0,
        zoneLat: zoneLat,
        zoneLng: zoneLng,
        radius: 100,
      );

      expect(result, isTrue);
    });

    test('returns true when user is just inside the boundary', () {
      final result = isInsideSafeZone(
        currentLat: 0.00089,
        currentLng: 0.0,
        zoneLat: 0.0,
        zoneLng: 0.0,
        radius: 100,
      );

      expect(result, isTrue);
    });

    test('returns false when user is just outside the boundary', () {
      final result = isInsideSafeZone(
        currentLat: 0.00091,
        currentLng: 0.0,
        zoneLat: 0.0,
        zoneLng: 0.0,
        radius: 100,
      );

      expect(result, isFalse);
    });

    test('throws ArgumentError when radius is zero', () {
      expect(
        () => isInsideSafeZone(
          currentLat: 7.2906,
          currentLng: 80.6337,
          zoneLat: 7.2906,
          zoneLng: 80.6337,
          radius: 0,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when radius is negative', () {
      expect(
        () => isInsideSafeZone(
          currentLat: 7.2906,
          currentLng: 80.6337,
          zoneLat: 7.2906,
          zoneLng: 80.6337,
          radius: -10,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid current latitude', () {
      expect(
        () => isInsideSafeZone(
          currentLat: 91,
          currentLng: 80.6337,
          zoneLat: 7.2906,
          zoneLng: 80.6337,
          radius: 100,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid current longitude', () {
      expect(
        () => isInsideSafeZone(
          currentLat: 7.2906,
          currentLng: 181,
          zoneLat: 7.2906,
          zoneLng: 80.6337,
          radius: 100,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid safe-zone latitude', () {
      expect(
        () => isInsideSafeZone(
          currentLat: 7.2906,
          currentLng: 80.6337,
          zoneLat: -91,
          zoneLng: 80.6337,
          radius: 100,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid safe-zone longitude', () {
      expect(
        () => isInsideSafeZone(
          currentLat: 7.2906,
          currentLng: 80.6337,
          zoneLat: 7.2906,
          zoneLng: -181,
          radius: 100,
        ),
        throwsArgumentError,
      );
    });
  });
}