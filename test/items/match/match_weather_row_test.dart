import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/items/match/match_weather_row.dart';
import 'package:football_match_app/services/match/weather_service.dart';
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

  testWidgets('tapping the row opens the forecast of the whole day', (
    tester,
  ) async {
    final service = serviceReturning(
      () => http.Response(
        jsonEncode({
          'hourly': {
            'time': [
              '2026-11-14T17:00',
              '2026-11-14T18:00',
              '2026-11-15T18:00',
            ],
            'temperature_2m': [17.0, 19.4, 8.0],
            'weather_code': [3, 2, 61],
            'wind_speed_10m': [10.0, 12.0, 30.0],
            'precipitation_probability': [5, 10, 80],
          },
        }),
        200,
      ),
    );
    await pumpRow(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weather_row')));
    await tester.pumpAndSettle();
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    // Another day's hour is not listed.
    expect(find.text('8°'), findsNothing);
  });
}
