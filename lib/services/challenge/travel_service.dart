import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../entities/challenge/travel.dart';
import '../location/player_location.dart';
import '../http_constants.dart';

/// Finds a place on OpenStreetMap (Nominatim) and times the trip to it with
/// the public OSRM routers; none of them needs a key. The player's position
/// is read only when they ask, and is never saved or sent anywhere except as
/// a coordinate pair to the router.
class TravelService {
  TravelService({
    http.Client? client,
    LocationSource? location,
    Uri? geocoder,
    Uri? carRouter,
    Uri? footRouter,
  }) : _client = client ?? http.Client(),
       _location = location ?? const GeolocatorLocationSource(),
       _geocoder =
           geocoder ?? Uri.parse(HttpEndpoints.nominatimSearch),
       _carRouter =
           carRouter ??
           Uri.parse(HttpEndpoints.osrmDriving),
       _footRouter =
           footRouter ??
           Uri.parse(HttpEndpoints.osrmFoot);

  final http.Client _client;
  final LocationSource _location;
  final Uri _geocoder;
  final Uri _carRouter;
  final Uri _footRouter;

  static const _wait = Duration(seconds: 10);

  Future<TravelResult> estimate(String place) async {
    final here = await _location.current();
    final from = here.location;
    if (here.status != LocationStatus.granted || from == null) {
      return TravelResult.failed(switch (here.status) {
        LocationStatus.denied => 'Allow location to time the trip.',
        LocationStatus.deniedForever =>
          'Location is blocked. Turn it on in the phone settings.',
        LocationStatus.serviceOff => 'Switch on location on your phone.',
        _ => 'Could not read your location.',
      });
    }
    try {
      final target = await _find(place);
      if (target == null) {
        return const TravelResult.failed(
          'Could not find this place on the map.',
        );
      }
      final car = await _route(_carRouter, from, target);
      final foot = await _route(_footRouter, from, target);
      if (car == null && foot == null) {
        return const TravelResult.failed('No route found to this place.');
      }
      final drive = car ?? foot!;
      return TravelResult.ok(
        TravelEstimate(
          driveMinutes: _minutes(car?.seconds ?? foot!.seconds / 4),
          walkMinutes: _minutes(foot?.seconds ?? car!.seconds * 4),
          kilometres: drive.metres / 1000,
        ),
      );
    } catch (_) {
      return const TravelResult.failed(
        'Could not reach the map service. Check your connection.',
      );
    }
  }

  static int _minutes(num seconds) => (seconds / 60).ceil().clamp(1, 99999);

  Future<PlayerLocation?> _find(String place) async {
    final uri = _geocoder.replace(
      queryParameters: {'q': place, 'format': 'json', 'limit': '1'},
    );
    final response = await _client
        .get(uri, headers: const {'user-agent': 'KickoffApp/1.0 (student project)'})
        .timeout(_wait);
    if (response.statusCode != 200) return null;
    return parseGeocode(jsonDecode(response.body));
  }

  Future<({double seconds, double metres})?> _route(
    Uri router,
    PlayerLocation from,
    PlayerLocation to,
  ) async {
    try {
      final uri = router.replace(
        path:
            '${router.path}/${from.longitude},${from.latitude};'
            '${to.longitude},${to.latitude}',
        queryParameters: {'overview': 'false'},
      );
      final response = await _client.get(uri).timeout(_wait);
      if (response.statusCode != 200) return null;
      return parseRoute(jsonDecode(response.body));
    } catch (_) {
      return null;
    }
  }

  /// The first place Nominatim found, or null.
  static PlayerLocation? parseGeocode(Object? json) {
    if (json is! List || json.isEmpty) return null;
    final first = json.first;
    if (first is! Map) return null;
    final lat = double.tryParse('${first['lat']}');
    final lon = double.tryParse('${first['lon']}');
    if (lat == null || lon == null) return null;
    return PlayerLocation(lat, lon);
  }

  /// Seconds and metres of the first route OSRM found, or null.
  static ({double seconds, double metres})? parseRoute(Object? json) {
    if (json is! Map || json['code'] != 'Ok') return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes.first;
    if (route is! Map) return null;
    final seconds = route['duration'];
    final metres = route['distance'];
    if (seconds is! num || metres is! num) return null;
    return (seconds: seconds.toDouble(), metres: metres.toDouble());
  }
}
