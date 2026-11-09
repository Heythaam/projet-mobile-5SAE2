import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/weather/match_weather_row.dart';
import 'package:football_match_app/weather/weather_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final now = DateTime(2026, 11, 9, 12);
  final saturday = DateTime(2026, 11, 14, 18);

  WeatherService serviceReturning(http.Response Function() respond) =>
      WeatherService(
        client: MockClient((_) async => respond()),
        clock: () => now,
      );

  Future<void> pumpRow(WidgetTester tester, WeatherService service) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchWeatherRow(service: service, when: saturday),
          ),
        ),
      );

  testWidgets('shows the temperature, sky and verdict', (tester) async {
    final service = serviceReturning(
      () => http.Response(
        jsonEncode({
          'hourly': {
            'time': ['2026-11-14T18:00'],
            'temperature_2m': [19.4],
            'weather_code': [2],
            'wind_speed_10m': [12.0],
            'precipitation_probability': [10],
          },
        }),
        200,
      ),
    );
    await pumpRow(tester, service);
    await tester.pump();
    expect(find.text('19° Partly cloudy · Good to play'), findsOneWidget);
  });

  testWidgets('warns when rain is likely', (tester) async {
    final service = serviceReturning(
      () => http.Response(
        jsonEncode({
          'hourly': {
            'time': ['2026-11-14T18:00'],
            'temperature_2m': [14.0],
            'weather_code': [63],
            'wind_speed_10m': [20.0],
            'precipitation_probability': [90],
          },
        }),
        200,
      ),
    );
    await pumpRow(tester, service);
    await tester.pump();
    expect(find.textContaining('Rain likely'), findsOneWidget);
  });

  testWidgets('shows nothing when the forecast cannot be loaded', (tester) async {
    final service = serviceReturning(() => http.Response('down', 503));
    await pumpRow(tester, service);
    await tester.pump();
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}
