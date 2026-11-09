import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/match_local_store.dart';
import 'package:football_match_app/location/player_location.dart';
import 'package:football_match_app/matches/football_match.dart';
import 'package:football_match_app/matches/match_controller.dart';
import 'package:football_match_app/screens/match/match_mock_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late MatchLocalStore store;

  MatchController controllerFor(
    String uid,
    String name, {
    LocationSource? location,
  }) => MatchController(
    uid: uid,
    username: name,
    openStore: () async => store,
    location: location,
  );

  CreateMatchDraft draft({String visibility = 'Public', int hours = 24}) =>
      CreateMatchDraft(
        stadium: matchStadiums.first,
        startsAt: DateTime.now().add(Duration(hours: hours)),
        visibility: visibility,
      );

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = MatchLocalStore(db);
  });

  tearDown(() => db.close());

  test('starts empty and loads without matches', () async {
    final controller = controllerFor('1', 'Farouk');
    await controller.load();
    expect(controller.loaded, isTrue);
    expect(controller.upcomingMatch, isNull);
    expect(controller.publicMatches, isEmpty);
    expect(controller.usernameInitial, 'F');
  });

  test('createMatch saves it and makes it the upcoming match', () async {
    final controller = controllerFor('1', 'Farouk');
    await controller.load();
    final created = await controller.createMatch(draft());
    expect(created.code, hasLength(5));
    expect(created.players, 1);
    expect(created.capacity, matchStadiums.first.players);
    expect(created.playerSlots.first, 'F');
    expect(controller.upcomingMatch?.code, created.code);
    expect(controller.publicMatches.map((l) => l.match.code), [created.code]);
    expect(controller.hasJoined(created), isTrue);

    // A new controller on the same database sees the saved match.
    final again = controllerFor('1', 'Farouk');
    await again.load();
    expect(again.upcomingMatch?.code, created.code);
  });

  test('calendarMatches lists the matches the player is in', () async {
    final host = controllerFor('1', 'Farouk');
    await host.load();
    expect(host.calendarMatches, isEmpty);
    final created = await host.createMatch(draft());

    final calendar = host.calendarMatches;
    expect(calendar.map((m) => m.id), [created.code]);
    expect(calendar.single.participation, MatchParticipation.created);
    expect(calendar.single.joinedSlots, 1);
    expect(calendar.single.totalSlots, matchStadiums.first.players);

    // Someone who is not in the match does not see it on their calendar.
    final other = controllerFor('2', 'Sami');
    await other.load();
    expect(other.calendarMatches, isEmpty);
  });

  test('stats follow create, join and cancel', () async {
    final host = controllerFor('1', 'Farouk');
    await host.load();
    expect(host.stats, (played: 0, hosted: 0));
    final created = await host.createMatch(draft());
    expect(host.stats, (played: 1, hosted: 1));
    final guest = controllerFor('2', 'Sami');
    await guest.load();
    await guest.joinByCode(created.code);
    expect(guest.stats, (played: 1, hosted: 0));
    await host.cancelMatch(created.code);
    expect(host.stats, (played: 0, hosted: 0));
  });

  test('only the host can switch a match between public and private', () async {
    final host = controllerFor('1', 'Farouk');
    await host.load();
    final created = await host.createMatch(draft());
    expect(created.isPublic, isTrue);
    expect(await host.setPublic(created.code, isPublic: false), isTrue);
    expect(host.findMatchByCode(created.code)!.isPublic, isFalse);
    expect(host.publicMatches, isEmpty);
    expect(await host.setPublic(created.code, isPublic: true), isTrue);
    expect(host.publicMatches, hasLength(1));

    final guest = controllerFor('2', 'Sami');
    await guest.load();
    await guest.joinByCode(created.code);
    expect(await guest.setPublic(created.code, isPublic: false), isFalse);
    expect(guest.lastError, contains('host'));
  });

  test('a match with more than 5 players cannot be cancelled', () async {
    final host = controllerFor('1', 'Farouk');
    await host.load();
    final created = await host.createMatch(draft());
    final guests = <MatchController>[];
    for (var i = 2; i <= 6; i++) {
      final guest = controllerFor('$i', 'P$i');
      await guest.load();
      await guest.joinByCode(created.code);
      guests.add(guest);
    }
    await host.load();
    expect(await host.cancelMatch(created.code), isFalse);
    expect(host.lastError, contains('more than 5'));
    expect(await store.getByCode(created.code), isNotNull);
    // Once someone leaves, 5 players remain and the host can cancel.
    await guests.first.leaveMatch(created.code);
    await host.load();
    expect(await host.cancelMatch(created.code), isTrue);
  });

  test('a private match is found by code but not listed', () async {
    final controller = controllerFor('1', 'Farouk');
    await controller.load();
    final created = await controller.createMatch(draft(visibility: 'Private'));
    expect(controller.publicMatches, isEmpty);
    expect(controller.findMatchByCode(created.code.toLowerCase())?.code, created.code);
    expect(controller.findMatchByCode('ZZZZZ'), isNull);
  });

  test('another player joins by code and shows with their initial', () async {
    final host = controllerFor('1', 'Farouk');
    await host.load();
    final created = await host.createMatch(draft());

    final guest = controllerFor('2', 'Sami');
    await guest.load();
    final joined = await guest.joinByCode(created.code);
    expect(joined?.players, 2);
    expect(joined?.playerSlots.take(2), ['F', 'S']);
    expect(guest.upcomingMatch?.code, created.code);
    expect(guest.hasJoined(joined!), isTrue);
  });

  test('joining a full match sets an error message', () async {
    final host = controllerFor('1', 'Farouk');
    await host.load();
    final created = await host.createMatch(draft());
    for (var i = 2; i <= created.capacity; i++) {
      final player = controllerFor('$i', 'P$i');
      await player.load();
      expect(await player.joinByCode(created.code), isNotNull);
    }
    final latecomer = controllerFor('99', 'Late');
    await latecomer.load();
    expect(await latecomer.joinByCode(created.code), isNull);
    expect(latecomer.lastError, 'This match is full.');
  });

  test('joining an unknown code returns null with a message', () async {
    final controller = controllerFor('1', 'Farouk');
    await controller.load();
    expect(await controller.joinByCode('ZZZZZ'), isNull);
    expect(controller.lastError, 'No match with that code.');
  });

  group('leave and cancel', () {
    test('a player leaves and the place is free again', () async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      final created = await host.createMatch(draft());
      final guest = controllerFor('2', 'Sami');
      await guest.load();
      final joined = (await guest.joinByCode(created.code))!;
      expect(guest.isHost(joined), isFalse);

      expect(await guest.leaveMatch(created.code), isTrue);
      expect(guest.hasJoined(joined), isFalse);
      expect(guest.upcomingMatch, isNull);
      expect(guest.findMatchByCode(created.code)?.players, 1);
    });

    test('the host cannot leave, and gets a message', () async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      final created = await host.createMatch(draft());
      expect(host.isHost(created), isTrue);
      expect(await host.leaveMatch(created.code), isFalse);
      expect(host.lastError, 'The host cancels the match instead of leaving.');
      expect(host.upcomingMatch?.code, created.code);
    });

    test('the host cancels and the match disappears for everyone', () async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      final created = await host.createMatch(draft());
      expect(await host.cancelMatch(created.code), isTrue);
      expect(host.upcomingMatch, isNull);
      expect(host.publicMatches, isEmpty);
      expect(host.findMatchByCode(created.code), isNull);

      final guest = controllerFor('2', 'Sami');
      await guest.load();
      expect(await guest.joinByCode(created.code), isNull);
    });

    test('a guest cannot cancel the match', () async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      final created = await host.createMatch(draft());
      final guest = controllerFor('2', 'Sami');
      await guest.load();
      await guest.joinByCode(created.code);
      expect(await guest.cancelMatch(created.code), isFalse);
      expect(guest.lastError, 'Only the host can cancel this match.');
      expect(guest.findMatchByCode(created.code), isNotNull);
    });

    test('after leaving, the next match becomes the upcoming one', () async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      final later = await host.createMatch(draft(hours: 48));
      final other = controllerFor('3', 'Yassine');
      await other.load();
      final soon = await other.createMatch(draft(hours: 5));
      final guest = controllerFor('2', 'Sami');
      await guest.load();
      await guest.joinByCode(later.code);
      await guest.joinByCode(soon.code);
      expect(guest.upcomingMatch?.code, soon.code);
      expect(await guest.leaveMatch(soon.code), isTrue);
      expect(guest.upcomingMatch?.code, later.code);
    });
  });

  group('nearby matches', () {
    // Sample stadiums: Green Arena is about 2 km from the centre of Tunis,
    // Riverside Park about 9 km.
    final green = matchStadiums.firstWhere((s) => s.name == 'Green Arena');
    final riverside = matchStadiums.firstWhere(
      (s) => s.name == 'Riverside Park',
    );
    const tunisCentre = PlayerLocation(36.8065, 10.1815);

    Future<void> twoPublicMatches() async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      // Riverside is sooner, Green Arena is nearer.
      await host.createMatch(
        CreateMatchDraft(
          stadium: riverside,
          startsAt: DateTime.now().add(const Duration(hours: 5)),
          visibility: 'Public',
        ),
      );
      await host.createMatch(
        CreateMatchDraft(
          stadium: green,
          startsAt: DateTime.now().add(const Duration(hours: 30)),
          visibility: 'Public',
        ),
      );
    }

    test('without location the list is soonest first', () async {
      await twoPublicMatches();
      final player = controllerFor('2', 'Sami');
      await player.load();
      expect(player.sortedByDistance, isFalse);
      expect(player.publicMatches.map((l) => l.match.stadium), [
        'Riverside Park',
        'Green Arena',
      ]);
      expect(player.publicMatches.every((l) => l.distanceKm == null), isTrue);
    });

    test('with location the nearest match comes first with its distance', () async {
      await twoPublicMatches();
      final source = _FakeLocation(
        const LocationResult(LocationStatus.granted, tunisCentre),
      );
      final player = controllerFor('2', 'Sami', location: source);
      await player.load();
      await player.useMyLocation();
      expect(source.calls, 1);
      expect(player.locationStatus, LocationStatus.granted);
      expect(player.sortedByDistance, isTrue);
      final listed = player.publicMatches;
      expect(listed.map((l) => l.match.stadium), [
        'Green Arena',
        'Riverside Park',
      ]);
      expect(listed.first.distanceKm, inInclusiveRange(1, 4));
      expect(listed.last.distanceKm, inInclusiveRange(6, 12));
    });

    test('a refused permission keeps the list as it was', () async {
      await twoPublicMatches();
      final player = controllerFor(
        '2',
        'Sami',
        location: _FakeLocation(const LocationResult(LocationStatus.denied)),
      );
      await player.load();
      await player.useMyLocation();
      expect(player.locationStatus, LocationStatus.denied);
      expect(player.sortedByDistance, isFalse);
      expect(player.publicMatches.first.match.stadium, 'Riverside Park');
    });

    test('full matches go after matches with free places', () async {
      final host = controllerFor('1', 'Farouk');
      await host.load();
      final tiny = MatchStadiumData(
        name: 'Tiny Pitch',
        distance: '1 km',
        coins: 10,
        players: 2,
        latitude: 36.8066,
        longitude: 10.1816,
      );
      final nearFull = await host.createMatch(
        CreateMatchDraft(
          stadium: tiny,
          startsAt: DateTime.now().add(const Duration(hours: 5)),
          visibility: 'Public',
        ),
      );
      await host.createMatch(
        CreateMatchDraft(
          stadium: riverside,
          startsAt: DateTime.now().add(const Duration(hours: 6)),
          visibility: 'Public',
        ),
      );
      final other = controllerFor('2', 'Sami');
      await other.load();
      await other.joinByCode(nearFull.code);

      final player = controllerFor(
        '3',
        'Yassine',
        location: _FakeLocation(
          const LocationResult(LocationStatus.granted, tunisCentre),
        ),
      );
      await player.load();
      await player.useMyLocation();
      expect(player.publicMatches.map((l) => l.match.stadium), [
        'Riverside Park',
        'Tiny Pitch',
      ]);
    });
  });
}

class _FakeLocation implements LocationSource {
  _FakeLocation(this.result);

  final LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}
