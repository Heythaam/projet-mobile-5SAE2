import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/weather/weather_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> forecast({
  List<Object?>? times,
  List<Object?>? temps,
  List<Object?>? codes,
  List<Object?>? winds,
  List<Object?>? rain,
}) => {
  'hourly': {
    'time': times ?? ['2026-11-14T17:00', '2026-11-14T18:00', '2026-11-14T19:00'],
    'temperature_2m': temps ?? [20.5, 19.0, 17.2],
    'weather_code': codes ?? [1, 2, 61],
    'wind_speed_10m': winds ?? [10.0, 12.0, 45.0],
    'precipitation_probability': rain ?? [5, 10, 80],
  },
};

void main() {
  final now = DateTime(2026, 11, 9, 12);
  final saturday = DateTime(2026, 11, 14, 18, 20);

  group('parse', () {
    test('picks the forecast hour closest to the match time', () {
      final weather = WeatherService.parse(forecast(), saturday)!;
      expect(weather.time, DateTime(2026, 11, 14, 18));
      expect(weather.temperatureC, 19.0);
      expect(weather.weatherCode, 2);
      expect(weather.windKmh, 12.0);
      expect(weather.rainChance, 10);
      expect(weather.description, 'Partly cloudy');
    });

    test('rounds to the next hour when that is closer', () {
      final weather = WeatherService.parse(
        forecast(),
        DateTime(2026, 11, 14, 18, 45),
      )!;
      expect(weather.time, DateTime(2026, 11, 14, 19));
    });

    test('returns null for an unexpected shape', () {
      expect(WeatherService.parse(null, saturday), isNull);
      expect(WeatherService.parse({'hourly': 5}, saturday), isNull);
      expect(WeatherService.parse({'hourly': {'time': []}}, saturday), isNull);
      expect(
        WeatherService.parse(forecast(temps: ['hot', 1, 2]), saturday),
        isNull,
      );
    });

    test('returns null when no forecast hour is within two hours', () {
      expect(
        WeatherService.parse(forecast(), DateTime(2026, 11, 14, 23)),
        isNull,
      );
    });

    test('works without a rain chance', () {
      final json = forecast();
      (json['hourly'] as Map).remove('precipitation_probability');
      expect(WeatherService.parse(json, saturday)!.rainChance, isNull);
    });
  });

  group('verdict', () {
    MatchWeather make({
      double temp = 20,
      double wind = 10,
      int code = 1,
      int? rain,
    }) => MatchWeather(
      time: saturday,
      temperatureC: temp,
      windKmh: wind,
      weatherCode: code,
      rainChance: rain,
    );

    test('good weather is good to play', () {
      expect(make().verdict, 'Good to play');
      expect(make().isGoodToPlay, isTrue);
    });

    test('flags rain, storms, wind and temperature extremes', () {
      expect(make(rain: 70).verdict, 'Rain likely');
      expect(make(code: 63).verdict, 'Rain likely');
      expect(make(code: 95).verdict, 'Storm risk');
      expect(make(wind: 50).verdict, 'Very windy');
      expect(make(temp: 36).verdict, 'Very hot');
      expect(make(temp: 2).verdict, 'Very cold');
      expect(make(rain: 70).isGoodToPlay, isFalse);
    });

    test('describes common weather codes', () {
      expect(make(code: 0).description, 'Clear sky');
      expect(make(code: 3).description, 'Cloudy');
      expect(make(code: 45).description, 'Fog');
      expect(make(code: 53).description, 'Drizzle');
      expect(make(code: 81).description, 'Rain showers');
      expect(make(code: 73).description, 'Snow');
      expect(make(code: 96).description, 'Thunderstorm');
    });
  });

  group('forecastAt', () {
    test('asks Open-Meteo for the place and returns the matching hour', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(forecast()), 200);
      });
      final service = WeatherService(client: client, clock: () => now);
      final weather = await service.forecastAt(
        latitude: 36.8065,
        longitude: 10.1815,
        when: saturday,
      );
      expect(requested.host, 'api.open-meteo.com');
      expect(requested.queryParameters['latitude'], '36.8065');
      expect(requested.queryParameters['longitude'], '10.1815');
      expect(requested.queryParameters['timezone'], 'auto');
      expect(requested.queryParameters['hourly'], contains('temperature_2m'));
      expect(weather?.temperatureC, 19.0);
    });

    test('returns null on a server error or a network failure', () async {
      final failing = WeatherService(
        client: MockClient((_) async => http.Response('nope', 500)),
        clock: () => now,
      );
      expect(
        await failing.forecastAt(latitude: 1, longitude: 1, when: saturday),
        isNull,
      );
      final offline = WeatherService(
        client: MockClient((_) async => throw http.ClientException('offline')),
        clock: () => now,
      );
      expect(
        await offline.forecastAt(latitude: 1, longitude: 1, when: saturday),
        isNull,
      );
    });

    test('does not call the API for a match in the past or too far ahead', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(forecast()), 200);
        }),
        clock: () => now,
      );
      expect(
        await service.forecastAt(
          latitude: 1,
          longitude: 1,
          when: now.subtract(const Duration(days: 2)),
        ),
        isNull,
      );
      expect(
        await service.forecastAt(
          latitude: 1,
          longitude: 1,
          when: now.add(const Duration(days: 30)),
        ),
        isNull,
      );
      expect(calls, 0);
    });
  });
}
