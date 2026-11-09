import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/match_local_store.dart';
import 'package:football_match_app/location/player_location.dart';
import 'package:football_match_app/sample_data/sample_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final json = File('assets/sample_data.json').readAsStringSync();
  final data = jsonDecode(json) as Map<String, dynamic>;

  test('the sample file has users, tournaments, matches and challenges', () {
    expect((data['users'] as List).length, greaterThanOrEqualTo(10));
    expect((data['tournaments'] as List), isNotEmpty);
    expect((data['matches'] as List).length, greaterThanOrEqualTo(10));
    expect((data['challenges'] as List), isNotEmpty);
  });

  test('every sample match has a real place inside Tunisia', () {
    for (final raw in data['matches'] as List) {
      final m = raw as Map<String, dynamic>;
      expect((m['stadium'] as String).length, lessThanOrEqualTo(60));
      expect(distanceKm(36.8065, 10.1815, m['latitude'], m['longitude']),
          lessThan(400));
    }
  });

  test('sample matches load once into the local store', () async {
    final db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = MatchLocalStore(db);
    final added = await loadSampleMatches(store, json: json);
    expect(added, (data['matches'] as List).length);
    expect(await loadSampleMatches(store, json: json), 0);
    final upcoming = await store.publicUpcoming();
    expect(upcoming.length, added);
    expect(upcoming.every((m) => m.hasLocation), isTrue);
    await db.close();
  });
}
