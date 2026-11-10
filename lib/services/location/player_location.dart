import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Where the player is. Kept in memory only: it is never saved or sent.
class PlayerLocation {
  const PlayerLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

enum LocationStatus {
  /// A position was read.
  granted,

  /// The player said no this time. We can ask again later.
  denied,

  /// The player said no for good. Only the phone's settings can change it.
  deniedForever,

  /// Location is switched off on the phone.
  serviceOff,

  /// Something else went wrong, for example no signal.
  unavailable,
}

class LocationResult {
  const LocationResult(this.status, [this.location]);

  final LocationStatus status;
  final PlayerLocation? location;
}

/// Reads the phone's position. A seam, so tests do not need a real phone.
abstract class LocationSource {
  /// Asks for permission when needed, then reads one position.
  Future<LocationResult> current();
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }
      // Low accuracy is enough to sort matches by distance and saves battery.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult(
        LocationStatus.granted,
        PlayerLocation(position.latitude, position.longitude),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable);
    }
  }
}

/// Great-circle distance in kilometres between two points.
double distanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusKm = 6371.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}
