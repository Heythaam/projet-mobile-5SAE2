// One story through the app's own code, with an in-memory SQFlite database and
// a fake Stadium API: sign in, set up the profile, load real stadiums, pick a
// free slot, create the match, let a friend join and leave, then cancel and
// see the slot released.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/bd/local_database.dart';
import 'package:football_match_app/bd/match_local_store.dart';
import 'package:football_match_app/bd/session_store.dart';
import 'package:football_match_app/bd/user_local_store.dart';
import 'package:football_match_app/services/match/match_controller.dart';
import 'package:football_match_app/entities/stadium/real_stadium.dart';
import 'package:football_match_app/services/stadium/stadium_directory.dart';
import 'package:football_match_app/entities/match/match_mock_data.dart';
import 'package:football_match_app/services/user/user_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _five = RealPitch(id: 1, name: 'A', size: '5v5');
const _seven = RealPitch(id: 2, name: 'B', size: '7v7');

/// A stadium server with one stadium and two pitches, with real hold and
/// release behaviour: a held slot is no longer free.
class _Stadiums implements StadiumDirectory {
  final held = <int, ({int pitchId, int start, String matchCode})>{};
  int _next = 1;

  @override
  Future<List<RealStadium>> stadiums() async => const [
    RealStadium(
      id: 5,
      name: 'Arena Nord',
      address: 'Rue du Stade, Tunis',
      pricePerHour: 60,
      pitches: [_five, _seven],
    ),
  ];

  @override
  Future<List<FreeSlot>> freeSlots(int stadiumId, DateTime day) async => [
    for (final pitch in const [_five, _seven])
      for (final hour in const [18, 19, 20])
        if (!held.values.any(
          (b) => b.pitchId == pitch.id && b.start == hour * 60,
        ))
          FreeSlot(
            pitch: pitch,
            start: hour * 60,
            end: (hour + 1) * 60,
            price: 60,
          ),
  ];

  @override
  Future<int> hold({
    required int stadiumId,
    required int pitchId,
    required DateTime day,
    required int start,
    required String matchCode,
  }) async {
    if (held.values.any((b) => b.pitchId == pitchId && b.start == start)) {
      throw const StadiumDirectoryException(
        'Someone already holds that slot.',
        statusCode: 409,
      );
    }
    final id = _next++;
    held[id] = (pitchId: pitchId, start: start, matchCode: matchCode);
    return id;
  }

  @override
  Future<void> release(int bookingId) async {
    if (held.remove(bookingId) == null) {
      throw const StadiumDirectoryException('Booking not found.', statusCode: 404);
    }
  }
}

void main() {
  sqfliteFfiInit();

  test('sign in, profile, real stadium, match, friend joins, cancel', () async {
    final db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final server = _Stadiums();
    SharedPreferences.setMockInitialValues({});
    final session = SessionStore(await SharedPreferences.getInstance());

    // Sign in: the session is remembered, the profile is created from the
    // account and then edited.
    await session.save(uid: '1', username: 'farouk', email: 'f@example.com');
    expect(session.read()?.username, 'farouk');
    final profile = UserProfileController(
      uid: '1',
      accountUsername: 'farouk',
      email: 'f@example.com',
      openStore: () async => UserLocalStore(db),
    );
    await profile.load();
    expect(profile.profile?.username, 'farouk');
    expect(
      await profile.save(
        username: 'captain_f',
        bio: 'Left foot only',
        position: 'MID',
        country: 'tn',
        avatarId: 3,
      ),
      isTrue,
    );
    expect(profile.profile?.country, 'TN');

    MatchController player(String uid, String name) => MatchController(
      uid: uid,
      username: name,
      openStore: () async => MatchLocalStore(db),
      stadiumDirectory: server,
    );

    // The host picks the real stadium, a free 7v7 slot, and creates the match.
    final host = player('1', 'captain_f');
    await host.load();
    await host.loadStadiums();
    expect(host.usingSampleStadiums, isFalse);
    final stadium = host.stadiums.single;
    expect(stadium.stadiumId, 5);

    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    final slots = await host.freeSlots(stadium, tomorrow);
    expect(slots, hasLength(6));
    final slot = slots.firstWhere(
      (s) => s.pitch.size == '7v7' && s.startLabel == '19:00',
    );
    final match = await host.createMatch(
      CreateMatchDraft(
        stadium: stadium,
        startsAt: tomorrow.add(const Duration(hours: 19)),
        visibility: 'Public',
        slot: slot,
      ),
    );
    expect(match.capacity, 14);
    expect(match.players, 1);
    expect(server.held.values.single.matchCode, match.code);

    // That slot is no longer offered, and a second hold is refused.
    final after = await host.freeSlots(stadium, tomorrow);
    expect(after, hasLength(5));
    await expectLater(
      host.createMatch(
        CreateMatchDraft(
          stadium: stadium,
          startsAt: tomorrow.add(const Duration(hours: 19)),
          visibility: 'Public',
          slot: slot,
        ),
      ),
      throwsA(isA<MatchBookingException>()),
    );
    // The refused match left nothing behind.
    expect((await MatchLocalStore(db).allUpcoming()), hasLength(1));

    // A friend finds the public match, joins, then leaves.
    final friend = player('2', 'sami');
    await friend.load();
    expect(friend.publicMatches.map((l) => l.match.code), [match.code]);
    final joined = await friend.joinPublicMatch(friend.publicMatches.single.match);
    expect(joined?.players, 2);
    expect(friend.stats, (played: 1, hosted: 0));
    expect(await friend.leaveMatch(match.code), isTrue);
    expect(friend.stats, (played: 0, hosted: 0));

    // The host's profile counts the match; cancelling releases the slot.
    expect(host.stats, (played: 1, hosted: 1));
    expect(await host.cancelMatch(match.code), isTrue);
    expect(server.held, isEmpty);
    expect(host.stats, (played: 0, hosted: 0));
    expect(await host.freeSlots(stadium, tomorrow), hasLength(6));

    // Sign out clears the remembered session.
    await session.clear();
    expect(session.read(), isNull);
  });
}
