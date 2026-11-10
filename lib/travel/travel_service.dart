import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../location/player_location.dart';
import '../screens/kickoff_style.dart';

/// How long it takes to reach a place from where the player is.
class TravelEstimate {
  const TravelEstimate({
    required this.driveMinutes,
    required this.walkMinutes,
    required this.kilometres,
  });

  final int driveMinutes;
  final int walkMinutes;

  /// Road distance by car.
  final double kilometres;

  static String format(int minutes) => minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Either an estimate or a message ready to show the player.
class TravelResult {
  const TravelResult.ok(TravelEstimate this.estimate) : message = null;
  const TravelResult.failed(String this.message) : estimate = null;

  final TravelEstimate? estimate;
  final String? message;
}

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
           geocoder ?? Uri.parse('https://nominatim.openstreetmap.org/search'),
       _carRouter =
           carRouter ??
           Uri.parse('https://router.project-osrm.org/route/v1/driving'),
       _footRouter =
           footRouter ??
           Uri.parse('https://routing.openstreetmap.de/routed-foot/route/v1/foot');

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

/// "How long to get there?" The trip is timed only when the player taps, so
/// no location permission is asked just by looking at a challenge.
class TravelRow extends StatefulWidget {
  const TravelRow({required this.service, required this.place, super.key});

  final TravelService service;
  final String place;

  @override
  State<TravelRow> createState() => _TravelRowState();
}

class _TravelRowState extends State<TravelRow> {
  bool _loading = false;
  TravelResult? _result;

  Future<void> _go() async {
    setState(() => _loading = true);
    final result = await widget.service.estimate(widget.place);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _result?.estimate;
    final text = _loading
        ? 'Timing the trip…'
        : estimate != null
        ? 'Car ${TravelEstimate.format(estimate.driveMinutes)}'
              ' · Walk ${TravelEstimate.format(estimate.walkMinutes)}'
              ' · ${estimate.kilometres.toStringAsFixed(1)} km'
        : _result?.message ?? 'How long to get there?';
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        key: const ValueKey('travel_row'),
        onTap: _loading ? null : _go,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                estimate == null
                    ? Icons.directions_rounded
                    : Icons.directions_car_rounded,
                color: KickoffColors.yellow,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: estimate == null
                        ? KickoffColors.muted
                        : Colors.white,
                    fontSize: 13,
                    decoration: estimate == null
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
