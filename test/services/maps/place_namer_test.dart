import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/maps/place_namer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('names a point with the first parts of the address', () async {
    final namer = PlaceNamer(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'display_name': 'Arena, Rue du Lac, Tunis, Tunisia'}),
          200,
        ),
      ),
    );
    expect(await namer.nameOf(36.8, 10.1), 'Arena, Rue du Lac, Tunis');
  });

  test('falls back to the coordinates when offline or on a bad answer', () async {
    final offline = PlaceNamer(
      client: MockClient((_) async => throw Exception('offline')),
    );
    expect(await offline.nameOf(36.8, 10.1), '36.80000, 10.10000');
    final bad = PlaceNamer(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(await bad.nameOf(36.8, 10.1), '36.80000, 10.10000');
  });
}
