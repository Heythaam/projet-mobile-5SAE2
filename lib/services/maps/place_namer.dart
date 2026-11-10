import 'dart:convert';

import 'package:http/http.dart' as http;

/// Names a point on the map, in French, using OpenStreetMap's free Nominatim
/// service.
/// Never throws: a missing connection gives the coordinates instead.
class PlaceNamer {
  PlaceNamer({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> nameOf(double latitude, double longitude) async {
    final fallback =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
        'zoom': '18',
        'accept-language': 'fr',
      });
      final response = await _client
          .get(uri, headers: {
            'User-Agent': 'kickoff-football-app',
            'Accept-Language': 'fr',
          })
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return fallback;
      final json = jsonDecode(response.body);
      final name = json is Map<String, dynamic> ? json['display_name'] : null;
      if (name is! String || name.trim().isEmpty) return fallback;
      return name.split(',').take(3).map((part) => part.trim()).join(', ');
    } catch (_) {
      return fallback;
    }
  }
}
