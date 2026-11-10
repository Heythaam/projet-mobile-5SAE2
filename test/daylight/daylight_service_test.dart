import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/challenge/daylight_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String body() => jsonEncode({
    'status': 'OK',
    'results': {
      'sunrise': '2026-11-14T05:40:00+00:00',
      'sunset': '2026-11-14T16:30:00+00:00',
    },
  });

  test('reads sunrise and sunset', () async {
    final service = DaylightService(
      client: MockClient((_) async => http.Response(body(), 200)),
    );
    final daylight = await service.forDay(
      latitude: 36.8,
      longitude: 10.1,
      day: DateTime(2026, 11, 14),
    );
    expect(daylight, isNotNull);
    expect(daylight!.sunset.isAfter(daylight.sunrise), isTrue);
  });

  test('gives null on errors and odd answers', () async {
    final down = DaylightService(
      client: MockClient((_) async => throw Exception('offline')),
    );
    expect(
      await down.forDay(latitude: 1, longitude: 1, day: DateTime(2026, 11, 14)),
      isNull,
    );
    expect(DaylightService.parse({'status': 'INVALID_REQUEST'}), isNull);
    expect(DaylightService.parse('x'), isNull);
  });

  test('judges a game against the daylight', () {
    final daylight = Daylight(
      sunrise: DateTime(2026, 11, 14, 6),
      sunset: DateTime(2026, 11, 14, 17, 30),
    );
    expect(
      daylight.verdict(DateTime(2026, 11, 14, 15), 60),
      DaylightVerdict.daylight,
    );
    expect(
      daylight.verdict(DateTime(2026, 11, 14, 17), 90),
      DaylightVerdict.partlyDark,
    );
    expect(
      daylight.verdict(DateTime(2026, 11, 14, 20), 60),
      DaylightVerdict.dark,
    );
  });
}
