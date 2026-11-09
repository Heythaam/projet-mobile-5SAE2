import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/match_local_store.dart';
import 'package:football_match_app/matches/match_controller.dart';
import 'package:football_match_app/screens/match/match_mock_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late MatchLocalStore store;

  MatchController controllerFor(String uid, String name) => MatchController(
    uid: uid,
    username: name,
    openStore: () async => store,
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
}
