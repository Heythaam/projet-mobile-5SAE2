import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/match_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher throwsMatch(LocalMatchError error) => throwsA(
  isA<LocalMatchException>().having((e) => e.error, 'error', error),
);

void main() {
  sqfliteFfiInit();

  late Database db;
  late MatchLocalStore store;
  late DateTime now;

  DateTime inHours(int hours) => now.add(Duration(hours: hours));

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime.utc(2026, 11, 9, 12);
    store = MatchLocalStore(db, clock: () => now, random: math.Random(7));
  });

  tearDown(() => db.close());

  Future<LocalMatch> seed({
    String host = 'host',
    int capacity = 4,
    bool isPublic = false,
    int hours = 24,
    String stadium = 'Green Arena',
  }) => store.create(
    hostUid: host,
    stadium: stadium,
    scheduledAt: inHours(hours),
    capacity: capacity,
    isPublic: isPublic,
  );

  group('create', () {
    test('saves the match with the host in slot 0', () async {
      final match = await store.create(
        hostUid: 'host',
        stadium: '  Green Arena ',
        scheduledAt: inHours(24),
        capacity: 10,
        isPublic: true,
      );
      expect(match.code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{5}$')));
      expect(match.stadium, 'Green Arena');
      expect(match.capacity, 10);
      expect(match.isPublic, isTrue);
      expect(match.slots, hasLength(10));
      expect(match.slots.first, 'host');
      expect(match.players, 1);
      expect(match.isFull, isFalse);
      expect(match.scheduledAt, inHours(24));
      expect(match.createdAt, now);
      expect(match.updatedAt, now);
    });

    test('keeps player names next to their slots', () async {
      final match = await store.create(
        hostUid: 'host',
        hostName: ' Farouk ',
        stadium: 'Green Arena',
        scheduledAt: inHours(24),
        capacity: 4,
      );
      expect(match.slotNames, ['Farouk', null, null, null]);
      final joined = await store.join(match.code, 'p1', name: 'Sami');
      expect(joined.slotNames, ['Farouk', 'Sami', null, null]);
    });

    test('saves the place of the match when given', () async {
      final withPlace = await store.create(
        hostUid: 'h',
        stadium: 'Arena',
        scheduledAt: inHours(5),
        capacity: 8,
        latitude: 36.8065,
        longitude: 10.1815,
      );
      expect(withPlace.hasLocation, isTrue);
      expect(withPlace.latitude, 36.8065);
      expect(withPlace.longitude, 10.1815);
      final without = await seed(host: 'x');
      expect(without.hasLocation, isFalse);
      expect(without.latitude, isNull);
    });

    test('rejects a half or out of range location', () async {
      for (final place in [(36.0, null), (null, 10.0), (95.0, 10.0), (36.0, 200.0)]) {
        await expectLater(
          store.create(
            hostUid: 'h',
            stadium: 'Arena',
            scheduledAt: inHours(5),
            capacity: 8,
            latitude: place.$1,
            longitude: place.$2,
          ),
          throwsMatch(LocalMatchError.invalidLocation),
        );
      }
    });

    test('rejects invalid input', () async {
      await expectLater(
        store.create(
          hostUid: ' ',
          stadium: 'Arena',
          scheduledAt: inHours(1),
          capacity: 8,
        ),
        throwsMatch(LocalMatchError.invalidHost),
      );
      await expectLater(
        store.create(
          hostUid: 'h',
          stadium: '  ',
          scheduledAt: inHours(1),
          capacity: 8,
        ),
        throwsMatch(LocalMatchError.invalidStadium),
      );
      for (final capacity in [1, 31]) {
        await expectLater(
          store.create(
            hostUid: 'h',
            stadium: 'Arena',
            scheduledAt: inHours(1),
            capacity: capacity,
          ),
          throwsMatch(LocalMatchError.invalidCapacity),
        );
      }
      for (final hours in [0, -3]) {
        await expectLater(
          store.create(
            hostUid: 'h',
            stadium: 'Arena',
            scheduledAt: inHours(hours),
            capacity: 8,
          ),
          throwsMatch(LocalMatchError.invalidTime),
        );
      }
      expect(await db.query('matches'), isEmpty);
    });

    test('gives every match its own code', () async {
      final codes = <String>{};
      for (var i = 0; i < 40; i++) {
        codes.add((await seed(host: 'h$i')).code);
      }
      expect(codes, hasLength(40));
    });
  });

  group('read', () {
    test('finds a match by code, ignoring case and spaces', () async {
      final match = await seed();
      expect((await store.getByCode(match.code.toLowerCase()))?.code, match.code);
      expect((await store.getByCode(' ${match.code} '))?.code, match.code);
    });

    test('returns null for unknown or malformed codes', () async {
      await seed();
      expect(await store.getByCode('ZZZZZ'), isNull);
      expect(await store.getByCode('abc'), isNull);
      expect(await store.getByCode(''), isNull);
    });

    test('lists public upcoming matches, soonest first', () async {
      final later = await seed(host: 'a', isPublic: true, hours: 48);
      final soon = await seed(host: 'b', isPublic: true, hours: 2);
      await seed(host: 'c', isPublic: false, hours: 1);
      final listed = await store.publicUpcoming();
      expect(listed.map((m) => m.code), [soon.code, later.code]);

      now = inHours(3);
      expect((await store.publicUpcoming()).map((m) => m.code), [later.code]);
    });

    test('lists every upcoming match, public or not', () async {
      final priv = await seed(host: 'a', hours: 5);
      final pub = await seed(host: 'b', isPublic: true, hours: 2);
      expect((await store.allUpcoming()).map((m) => m.code), [pub.code, priv.code]);
      now = inHours(3);
      expect((await store.allUpcoming()).map((m) => m.code), [priv.code]);
    });

    test('finds the next match a player is in', () async {
      expect(await store.upcomingFor('me'), isNull);
      final far = await seed(host: 'me', hours: 72);
      final near = await seed(host: 'other', hours: 5);
      await store.join(near.code, 'me');
      expect((await store.upcomingFor('me'))?.code, near.code);

      now = inHours(6);
      expect((await store.upcomingFor('me'))?.code, far.code);
      expect(await store.upcomingFor('nobody'), isNull);
    });
  });

  group('join and leave', () {
    test('join takes the lowest free slot and bumps updated_at', () async {
      final match = await seed();
      now = now.add(const Duration(minutes: 5));
      final one = await store.join(match.code, 'p1');
      final two = await store.join(match.code.toLowerCase(), 'p2');
      expect(one.slots.take(2), ['host', 'p1']);
      expect(two.slots.take(3), ['host', 'p1', 'p2']);
      expect(two.players, 3);
      expect(two.updatedAt.isAfter(match.updatedAt), isTrue);
    });

    test('join rejects a duplicate, a full match and an unknown code', () async {
      final match = await seed(capacity: 2);
      await expectLater(
        store.join(match.code, 'host'),
        throwsMatch(LocalMatchError.alreadyJoined),
      );
      final full = await store.join(match.code, 'p1');
      expect(full.isFull, isTrue);
      await expectLater(
        store.join(match.code, 'p2'),
        throwsMatch(LocalMatchError.full),
      );
      await expectLater(
        store.join('ZZZZZ', 'p2'),
        throwsMatch(LocalMatchError.notFound),
      );
    });

    test('join and leave are refused once the match has started', () async {
      final match = await seed(hours: 2);
      await store.join(match.code, 'p1');
      now = inHours(2);
      await expectLater(
        store.join(match.code, 'p2'),
        throwsMatch(LocalMatchError.started),
      );
      await expectLater(
        store.leave(match.code, 'p1'),
        throwsMatch(LocalMatchError.started),
      );
    });

    test('leave frees the slot and the next join reuses it', () async {
      final match = await seed();
      await store.join(match.code, 'p1');
      await store.join(match.code, 'p2');
      final left = await store.leave(match.code, 'p1');
      expect(left.slots.take(3), ['host', null, 'p2']);
      final again = await store.join(match.code, 'p3');
      expect(again.slots.take(3), ['host', 'p3', 'p2']);
    });

    test('the host cannot leave and strangers cannot leave', () async {
      final match = await seed();
      await expectLater(
        store.leave(match.code, 'host'),
        throwsMatch(LocalMatchError.hostCannotLeave),
      );
      await expectLater(
        store.leave(match.code, 'stranger'),
        throwsMatch(LocalMatchError.notPlayer),
      );
    });
  });

  group('cancel', () {
    test('only the host can cancel, and players go with the match', () async {
      final match = await seed();
      await store.join(match.code, 'p1');
      await expectLater(
        store.cancel(match.code, 'p1'),
        throwsMatch(LocalMatchError.notHost),
      );
      await store.cancel(match.code, 'host');
      expect(await store.getByCode(match.code), isNull);
      expect(await db.query('match_players'), isEmpty);
      await expectLater(
        store.cancel(match.code, 'host'),
        throwsMatch(LocalMatchError.notFound),
      );
    });
  });
}
