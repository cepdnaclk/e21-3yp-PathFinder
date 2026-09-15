import 'dart:math';

double distanceInMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadius = 6371000.0;

  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);

  return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

bool isInsideSafeZone({
  required double currentLat,
  required double currentLng,
  required double zoneLat,
  required double zoneLng,
  required double radius,
}) {
  if (currentLat < -90 || currentLat > 90) {
    throw ArgumentError('Invalid current latitude');
  }

  if (currentLng < -180 || currentLng > 180) {
    throw ArgumentError('Invalid current longitude');
  }

  if (zoneLat < -90 || zoneLat > 90) {
    throw ArgumentError('Invalid safe-zone latitude');
  }

  if (zoneLng < -180 || zoneLng > 180) {
    throw ArgumentError('Invalid safe-zone longitude');
  }

  if (radius <= 0) {
    throw ArgumentError('Radius must be greater than zero');
  }

  final distance = distanceInMeters(
    currentLat,
    currentLng,
    zoneLat,
    zoneLng,
  );

  return distance <= radius;
}