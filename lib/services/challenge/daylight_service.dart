import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../entities/challenge/daylight.dart';

/// Reads sunrise and sunset from sunrise-sunset.org (free, no key). Returns
/// null instead of throwing, so a missing connection never blocks a screen.
class DaylightService {
  DaylightService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://api.sunrise-sunset.org/json');

  final http.Client _client;
  final Uri _baseUri;

  Future<Daylight?> forDay({
    required double latitude,
    required double longitude,
    required DateTime day,
  }) async {
    try {
      final uri = _baseUri.replace(
        queryParameters: {
          'lat': '$latitude',
          'lng': '$longitude',
          'date':
              '${day.year}-${day.month.toString().padLeft(2, '0')}-'
              '${day.day.toString().padLeft(2, '0')}',
          'formatted': '0',
        },
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parse(jsonDecode(response.body));
    } catch (_) {
      return null;
    }
  }

  /// Reads the answer of sunrise-sunset.org; null when it has another shape.
  static Daylight? parse(Object? json) {
    if (json is! Map<String, dynamic> || json['status'] != 'OK') return null;
    final results = json['results'];
    if (results is! Map<String, dynamic>) return null;
    final sunrise = results['sunrise'];
    final sunset = results['sunset'];
    if (sunrise is! String || sunset is! String) return null;
    final rise = DateTime.tryParse(sunrise)?.toLocal();
    final set = DateTime.tryParse(sunset)?.toLocal();
    if (rise == null || set == null) return null;
    return Daylight(sunrise: rise, sunset: set);
  }
}
