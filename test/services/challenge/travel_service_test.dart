import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/location/player_location.dart';
import 'package:football_match_app/entities/challenge/travel.dart';
import 'package:football_match_app/services/challenge/travel_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Here implements LocationSource {
  const _Here(this.result);
  final LocationResult result;
  @override
  Future<LocationResult> current() async => result;
}

const _granted = LocationResult(
  LocationStatus.granted,
  PlayerLocation(36.8, 10.18),
);

void main() {
  test('reads the first place Nominatim found', () {
    final spot = TravelService.parseGeocode([
      {'lat': '36.81', 'lon': '10.17'},
    ]);
    expect(spot?.latitude, 36.81);
    expect(spot?.longitude, 10.17);
    expect(TravelService.parseGeocode(<Object?>[]), isNull);
    expect(TravelService.parseGeocode({'error': 'x'}), isNull);
  });

  test('reads a route from OSRM', () {
    final route = TravelService.parseRoute({
      'code': 'Ok',
      'routes': [
        {'duration': 600.0, 'distance': 5400.0},
      ],
    });
    expect(route?.seconds, 600);
    expect(route?.metres, 5400);
    expect(TravelService.parseRoute({'code': 'NoRoute'}), isNull);
  });

  test('times the trip by car and on foot', () async {
    final client = MockClient((request) async {
      if (request.url.host.contains('nominatim')) {
        return http.Response(
          jsonEncode([
            {'lat': '36.85', 'lon': '10.2'},
          ]),
          200,
        );
      }
      final foot = request.url.host.contains('openstreetmap.de');
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {'duration': foot ? 3900.0 : 600.0, 'distance': 5400.0},
          ],
        }),
        200,
      );
    });
    final service = TravelService(
      client: client,
      location: const _Here(_granted),
    );
    final result = await service.estimate('Central Arena');
    expect(result.estimate?.driveMinutes, 10);
    expect(result.estimate?.walkMinutes, 65);
    expect(result.estimate?.kilometres, closeTo(5.4, 0.01));
    expect(TravelEstimate.format(65), '1 h 05');
  });

  test('says so when the place or the location is missing', () async {
    final notFound = TravelService(
      client: MockClient((_) async => http.Response('[]', 200)),
      location: const _Here(_granted),
    );
    expect((await notFound.estimate('Nowhere')).message, contains('find'));

    final noLocation = TravelService(
      client: MockClient((_) async => http.Response('[]', 200)),
      location: const _Here(LocationResult(LocationStatus.denied)),
    );
    expect((await noLocation.estimate('Arena')).message, contains('location'));
  });
}
