import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Forecast for one hour at one place, from Open-Meteo (free, no key).
class MatchWeather {
  const MatchWeather({
    required this.time,
    required this.temperatureC,
    required this.windKmh,
    required this.weatherCode,
    this.rainChance,
  });

  /// The forecast hour, in the place's local time.
  final DateTime time;
  final double temperatureC;
  final double windKmh;

  /// WMO weather code, as Open-Meteo returns it.
  final int weatherCode;

  /// Chance of rain in percent, when the model gives one.
  final int? rainChance;

  String get description {
    final code = weatherCode;
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mostly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code == 85 || code == 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Unsettled';
  }

  IconData get icon {
    final code = weatherCode;
    if (code == 0 || code == 1) return Icons.wb_sunny_rounded;
    if (code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 71 && code <= 77 || code == 85 || code == 86) {
      return Icons.ac_unit_rounded;
    }
    if (code >= 95) return Icons.thunderstorm_rounded;
    if (code >= 51) return Icons.water_drop_rounded;
    return Icons.cloud_rounded;
  }

  /// A one-line call on whether the match is a good idea.
  String get verdict {
    if (weatherCode >= 95) return 'Storm risk';
    if ((rainChance ?? 0) >= 60 || (weatherCode >= 61 && weatherCode <= 67)) {
      return 'Rain likely';
    }
    if (windKmh >= 40) return 'Very windy';
    if (temperatureC >= 34) return 'Very hot';
    if (temperatureC <= 5) return 'Very cold';
    return 'Good to play';
  }

  bool get isGoodToPlay => verdict == 'Good to play';
}

/// Reads the hourly forecast from Open-Meteo. Returns null instead of
/// throwing, so a missing connection never blocks a screen.
class WeatherService {
  WeatherService({http.Client? client, Uri? baseUri, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://api.open-meteo.com/v1/forecast'),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final Uri _baseUri;
  final DateTime Function() _clock;

  /// Open-Meteo forecasts up to 16 days ahead.
  static const maxDaysAhead = 16;

  /// The weather around [when] at the given place, or null when [when] is in
  /// the past or too far ahead, or the forecast cannot be read.
  Future<MatchWeather?> forecastAt({
    required double latitude,
    required double longitude,
    required DateTime when,
  }) async {
    final now = _clock();
    if (when.isBefore(now.subtract(const Duration(hours: 1))) ||
        when.isAfter(now.add(const Duration(days: maxDaysAhead - 1)))) {
      return null;
    }
    try {
      final uri = _baseUri.replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'hourly': 'temperature_2m,precipitation_probability,weather_code,'
              'wind_speed_10m',
          'timezone': 'auto',
          'forecast_days': '$maxDaysAhead',
        },
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parse(jsonDecode(response.body), when);
    } catch (_) {
      return null;
    }
  }

  /// Picks the forecast hour closest to [when] from an Open-Meteo response.
  /// Returns null when the response does not have the expected shape.
  static MatchWeather? parse(Object? json, DateTime when) {
    if (json is! Map<String, dynamic>) return null;
    final hourly = json['hourly'];
    if (hourly is! Map<String, dynamic>) return null;
    final times = hourly['time'];
    final temps = hourly['temperature_2m'];
    final codes = hourly['weather_code'];
    final winds = hourly['wind_speed_10m'];
    final rain = hourly['precipitation_probability'];
    if (times is! List || temps is! List || codes is! List || winds is! List) {
      return null;
    }

    // Forecast times carry no offset: they are local to the place, so compare
    // them with [when] as a plain wall-clock time.
    final target = DateTime(
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
    );
    int? best;
    Duration? bestGap;
    for (var i = 0; i < times.length; i++) {
      if (times[i] is! String) continue;
      final time = DateTime.tryParse(times[i] as String);
      if (time == null) continue;
      final gap = time.difference(target).abs();
      if (bestGap == null || gap < bestGap) {
        best = i;
        bestGap = gap;
      }
    }
    if (best == null || bestGap! > const Duration(hours: 2)) return null;

    final temp = _number(temps, best);
    final code = _number(codes, best);
    final wind = _number(winds, best);
    if (temp == null || code == null || wind == null) return null;
    final chance = rain is List ? _number(rain, best) : null;
    return MatchWeather(
      time: DateTime.parse(times[best] as String),
      temperatureC: temp.toDouble(),
      windKmh: wind.toDouble(),
      weatherCode: code.toInt(),
      rainChance: chance?.round(),
    );
  }

  static num? _number(List<dynamic> list, int index) {
    if (index >= list.length) return null;
    final value = list[index];
    return value is num ? value : null;
  }
}
