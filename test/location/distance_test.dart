import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/location/player_location.dart';

void main() {
  test('distance between the same point is zero', () {
    expect(distanceKm(36.8, 10.18, 36.8, 10.18), 0);
  });

  test('Tunis to Sousse is about 125 km', () {
    final km = distanceKm(36.8065, 10.1815, 35.8256, 10.6084);
    expect(km, inInclusiveRange(115, 135));
  });

  test('one degree of latitude is about 111 km', () {
    expect(distanceKm(0, 0, 1, 0), closeTo(111.2, 0.5));
  });

  test('distance is the same in both directions', () {
    final a = distanceKm(36.8065, 10.1815, 36.7480, 10.2100);
    final b = distanceKm(36.7480, 10.2100, 36.8065, 10.1815);
    expect(a, closeTo(b, 1e-9));
  });
}
