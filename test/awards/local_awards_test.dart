import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/awards/local_awards.dart';
import 'package:football_match_app/bd/local_database.dart';
import 'package:football_match_app/bd/match_local_store.dart';
import 'package:football_match_app/views/home/placeholder_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late MatchLocalStore store;
  late DateTime now;

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime.utc(2026, 11, 9, 12);
    store = MatchLocalStore(db, clock: () => now, random: math.Random(3));
  });

  tearDown(() => db.close());

  Future<LocalMatch> make(String host, String stadium, {bool public = false}) =>
      store.create(
        hostUid: host,
        stadium: stadium,
        scheduledAt: now.add(const Duration(hours: 24)),
        capacity: 6,
        isPublic: public,
      );

  test('past matches and award numbers come from the phone', () async {
    final a = await make('me', 'Arena A', public: true);
    await make('me', 'Arena B');
    final c = await make('other', 'Arena C');
    await store.join(c.code, 'me', name: 'Me');

    var past = await store.pastFor('me');
    expect(past, isEmpty);

    now = now.add(const Duration(days: 2));
    past = await store.pastFor('me');
    expect(past, hasLength(3));
    expect(past.map((m) => m.code), contains(a.code));

    final stats = await store.awardStatsFor('me');
    expect(stats.played, 3);
    expect(stats.hosted, 2);
    expect(stats.hostedPublic, 1);
    expect(stats.finished, 3);
    expect(stats.stadiums, 3);
  });

  test('awards unlock from the numbers and list unlocked first', () {
    final none = localAwards(const AwardStats());
    expect(none.where((a) => a.unlocked), isEmpty);

    final some = localAwards(
      const AwardStats(played: 5, hosted: 1, finished: 1, hostedPublic: 1),
    );
    final ids = some.where((a) => a.unlocked).map((a) => a.id).toSet();
    expect(
      ids,
      {'first_kickoff', 'final_whistle', 'organiser', 'open_doors', 'regular'},
    );
    expect(some.first.unlocked, isTrue);
    expect(some.last.unlocked, isFalse);
    expect(
      some.firstWhere((a) => a.id == 'captain').fraction,
      closeTo(0.2, 0.001),
    );
  });

  testWidgets('awards screen works without the server', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AwardsScreen(
          profile: null,
          localAwards: localAwards(const AwardStats(played: 1, hosted: 1)),
        ),
      ),
    );
    expect(find.text('First kickoff'), findsOneWidget);
    expect(find.text('Awards unavailable'), findsNothing);
    expect(find.byKey(const ValueKey('awards_count')), findsOneWidget);
  });
}
