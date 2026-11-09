import 'dart:io';

import 'package:backend/app.dart';
import 'package:backend/database.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'server_test.dart' show decode, register, sendRequest;

const _secret = 'test-secret-with-at-least-32-characters-long';

void main() {
  late AppDatabase database;
  late Handler app;

  setUp(() {
    database = AppDatabase(':memory:');
    app = createApp(database: database, jwtSecret: _secret);
  });

  tearDown(() => database.close());

  int seedTournament({String name = 'Sunday Cup'}) {
    database.db.execute(
      '''
        INSERT INTO tournaments
          (name, format, status, start_date, end_date, max_teams, team_size)
        VALUES (?, 'league', 'upcoming', '2026-11-01T10:00:00Z',
          '2026-11-30T18:00:00Z', 8, 5)
      ''',
      [name],
    );
    return database.db.lastInsertRowId;
  }

  /// Registers [username] and returns its token and user id.
  Future<(String, int)> user(String username) async {
    final session = await register(app, username);
    return (
      session['token'] as String,
      (session['user'] as Map<String, dynamic>)['id'] as int,
    );
  }

  Future<int> createTeam(String token, int id, String name) async {
    final response = await sendRequest(
      app,
      'POST',
      '/tournaments/$id/join',
      token: token,
      body: {'name': name},
    );
    expect(response.statusCode, 200);
    final tournament = (await decode(response))['tournament'];
    return tournament['myTeamId'] as int;
  }

  Future<Response> ask(String token, int id, int team) => sendRequest(
    app,
    'POST',
    '/tournaments/$id/teams/$team/request',
    token: token,
  );

  /// Sends a request from [player] and has [captain] accept it.
  Future<void> addPlayer(
    String captain,
    String player,
    int id,
    int team,
  ) async {
    expect((await ask(player, id, team)).statusCode, 201);
    final requests = await decode(
      await sendRequest(
        app,
        'GET',
        '/tournaments/$id/requests',
        token: captain,
      ),
    );
    final requestId = (requests['requests'] as List).last['id'];
    final answer = await sendRequest(
      app,
      'PUT',
      '/tournaments/$id/requests/$requestId',
      token: captain,
      body: {'status': 'accepted'},
    );
    expect(answer.statusCode, 200);
  }

  Future<Map<String, dynamic>> detail(String token, int id) async =>
      (await decode(
            await sendRequest(app, 'GET', '/tournaments/$id', token: token),
          ))['tournament']
          as Map<String, dynamic>;

  Future<Response> transfer(String token, int id, Object? newCaptainId) =>
      sendRequest(
        app,
        'POST',
        '/tournaments/$id/transfer-captaincy',
        token: token,
        body: {'newCaptainId': newCaptainId},
      );

  Future<Response> leave(String token, int id, {bool disband = false}) =>
      sendRequest(
        app,
        'DELETE',
        '/tournaments/$id/join${disband ? '?disband=true' : ''}',
        token: token,
      );

  test('transfer requires a session', () async {
    final response = await sendRequest(
      app,
      'POST',
      '/tournaments/1/transfer-captaincy',
      body: {'newCaptainId': 2},
    );
    expect(response.statusCode, 401);
  });

  test('a captain hands the team to a player and stays on it', () async {
    final (alice, aliceId) = await user('alice');
    final (bob, bobId) = await user('bob');
    final (carol, carolId) = await user('carol');
    final (dave, _) = await user('dave');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    await addPlayer(alice, bob, id, team);
    expect((await ask(carol, id, team)).statusCode, 201);

    final before = await detail(alice, id);
    expect(before['canLeave'], isFalse);
    expect(before['canTransfer'], isTrue);
    expect(before['canDisband'], isTrue);

    expect((await transfer(alice, id, 'bob')).statusCode, 400);
    expect((await transfer(alice, id, aliceId)).statusCode, 400);
    // Only accepted players can take over, not requesters or strangers.
    expect((await transfer(alice, id, carolId)).statusCode, 404);
    expect((await transfer(alice, id, 9999)).statusCode, 404);
    expect((await transfer(bob, id, aliceId)).statusCode, 403);
    expect((await transfer(dave, id, aliceId)).statusCode, 403);

    final moved = await transfer(alice, id, bobId);
    expect(moved.statusCode, 200);
    final mine = (await decode(moved))['tournament'];
    expect(mine['joined'], isFalse);
    expect(mine['myTeamId'], team);
    expect(mine['canLeave'], isTrue);
    expect(mine['canTransfer'], isFalse);
    expect(mine['teams'].single['players'], 2);

    final bobs = await detail(bob, id);
    expect(bobs['joined'], isTrue);
    expect(bobs['canTransfer'], isTrue);
    // Requests to the team follow it to the new captain.
    expect(bobs['pendingRequests'], 1);

    final roster = await decode(
      await sendRequest(
        app,
        'GET',
        '/tournaments/$id/teams/$team',
        token: alice,
      ),
    );
    expect(roster['team']['captainId'], bobId);
    expect(
      [
        for (final player in roster['team']['players'] as List)
          (player['username'], player['isCaptain']),
      ],
      [('bob', true), ('alice', false)],
    );

    // The new captain can hand it back.
    expect((await transfer(bob, id, aliceId)).statusCode, 200);
    expect((await detail(alice, id))['joined'], isTrue);
    expect((await detail(bob, id))['myTeamId'], team);
  });

  test('captaincy moves only before kickoff', () async {
    final (alice, _) = await user('alice');
    final (bob, bobId) = await user('bob');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    await addPlayer(alice, bob, id, team);
    database.db.execute("UPDATE tournaments SET status = 'active'");

    expect((await detail(alice, id))['canTransfer'], isFalse);
    final closed = await transfer(alice, id, bobId);
    expect(closed.statusCode, 409);
    final reason = await decode(closed);
    expect(reason['error'], contains('before'));
    expect(reason['code'], 'transfer_closed');
    expect((await detail(alice, id))['joined'], isTrue);
  });

  test('a transfer after the team is gone says why', () async {
    final (alice, _) = await user('alice');
    final (bob, bobId) = await user('bob');
    final (carol, carolId) = await user('carol');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    await addPlayer(alice, bob, id, team);
    await addPlayer(alice, carol, id, team);

    // A second request from the old captain after a handover.
    expect((await transfer(alice, id, bobId)).statusCode, 200);
    final handedOff = await transfer(alice, id, carolId);
    expect(handedOff.statusCode, 403);
    expect((await decode(handedOff))['code'], 'not_captain');

    // A transfer arriving after the team was disbanded, even once the
    // tournament has also started, reports the withdrawn team.
    expect((await leave(bob, id, disband: true)).statusCode, 200);
    database.db.execute("UPDATE tournaments SET status = 'active'");
    final withdrawn = await transfer(bob, id, carolId);
    expect(withdrawn.statusCode, 409);
    final body = await decode(withdrawn);
    expect(body['code'], 'team_withdrawn');
    expect(body['error'], contains('no longer in this tournament'));

    final (dave, _) = await user('dave');
    final stranger = await transfer(dave, id, carolId);
    expect(stranger.statusCode, 403);
    expect((await decode(stranger))['code'], 'not_captain');
  });

  test('former players are told once that their team was disbanded', () async {
    final (alice, _) = await user('alice');
    final (bob, _) = await user('bob');
    final (carol, _) = await user('carol');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    await addPlayer(alice, bob, id, team);
    expect((await ask(carol, id, team)).statusCode, 201);
    expect((await detail(bob, id))['teamDisbanded'], isFalse);

    expect((await leave(alice, id, disband: true)).statusCode, 200);
    expect((await detail(bob, id))['teamDisbanded'], isTrue);
    // The captain disbanded it, and Carol was never on the team.
    expect((await detail(alice, id))['teamDisbanded'], isFalse);
    expect((await detail(carol, id))['teamDisbanded'], isFalse);

    Future<Response> dismiss(String token, int tournamentId) => sendRequest(
      app,
      'DELETE',
      '/tournaments/$tournamentId/disband-notice',
      token: token,
    );
    expect((await dismiss(bob, id)).statusCode, 204);
    expect((await detail(bob, id))['teamDisbanded'], isFalse);
    // Dismissing again, or with nothing to dismiss, is harmless.
    expect((await dismiss(bob, id)).statusCode, 204);
    expect((await dismiss(carol, id)).statusCode, 204);
    expect((await dismiss(bob, 999)).statusCode, 404);
    expect(
      (await sendRequest(
        app,
        'DELETE',
        '/tournaments/$id/disband-notice',
      )).statusCode,
      401,
    );
  });

  test('a captain with players disbands only when asked to', () async {
    final (alice, _) = await user('alice');
    final (bob, _) = await user('bob');
    final (carol, _) = await user('carol');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    await addPlayer(alice, bob, id, team);
    expect((await ask(carol, id, team)).statusCode, 201);

    final refused = await leave(alice, id);
    expect(refused.statusCode, 409);
    expect((await decode(refused))['error'], contains('players'));

    final disbanded = await leave(alice, id, disband: true);
    expect(disbanded.statusCode, 200);
    final tournament = (await decode(disbanded))['tournament'];
    expect(tournament['joined'], isFalse);
    expect(tournament['myTeamId'], isNull);
    expect(tournament['currentTeams'], 0);
    expect(tournament['teams'], isEmpty);

    final row = database.db.select(
      'SELECT status, left_at FROM tournament_teams WHERE id = ?',
      [team],
    ).single;
    expect(row['status'], 'disbanded');
    expect(row['left_at'], isNotNull);
    expect(
      database.db
          .select('SELECT status FROM join_requests ORDER BY id')
          .map((request) => request['status']),
      // Bob played for the team; Carol had only asked to join it.
      ['disbanded', 'cancelled'],
    );

    // Its players are free, and the name can be used again.
    expect((await detail(bob, id))['myTeamId'], isNull);
    expect((await detail(carol, id))['myRequests'], isEmpty);
    await createTeam(bob, id, 'Red Lions');
    await createTeam(alice, id, 'Blue Hawks');
  });

  test('disbanding needs open registration and no fixtures', () async {
    final (alice, _) = await user('alice');
    final (bob, _) = await user('bob');
    final (carol, _) = await user('carol');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    final rival = await createTeam(carol, id, 'Blue Hawks');
    await addPlayer(alice, bob, id, team);
    database.db.execute(
      '''
        INSERT INTO tournament_matches
          (tournament_id, home_team_id, away_team_id, status)
        VALUES (?, ?, ?, 'scheduled')
      ''',
      [id, team, rival],
    );

    final actions = await detail(alice, id);
    expect(actions['canDisband'], isFalse);
    // Fixtures do not stop a handover.
    expect(actions['canTransfer'], isTrue);
    final withMatches = await leave(alice, id, disband: true);
    expect(withMatches.statusCode, 409);
    expect((await decode(withMatches))['error'], contains('matches'));

    database.db.execute("UPDATE tournaments SET status = 'active'");
    final closed = await leave(alice, id, disband: true);
    expect(closed.statusCode, 409);
    expect((await decode(closed))['error'], contains('before'));
  });

  test('players leave their team before kickoff and may ask again', () async {
    final (alice, _) = await user('alice');
    final (bob, _) = await user('bob');
    final id = seedTournament();
    final team = await createTeam(alice, id, 'Red Lions');
    await addPlayer(alice, bob, id, team);

    final left = await leave(bob, id);
    expect(left.statusCode, 200);
    final tournament = (await decode(left))['tournament'];
    expect(tournament['myTeamId'], isNull);
    expect(tournament['myRequests'], isEmpty);
    expect(tournament['teams'].single['players'], 1);
    expect(
      database.db.select('SELECT status FROM join_requests').single['status'],
      'left',
    );
    // The captain may now leave alone.
    expect((await detail(alice, id))['canLeave'], isTrue);
    expect((await ask(bob, id, team)).statusCode, 201);
  });

  test('older databases keep teams, matches and requests', () {
    final directory = Directory.systemTemp.createTempSync('kickoff_db_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/old.sqlite';
    AppDatabase(path).close();
    // Recreate the previous schema: an inline captain constraint and no
    // status, with a match and a request pointing at the teams.
    final old = sqlite3.open(path);
    old.execute('''
      PRAGMA foreign_keys = OFF;
      DROP TABLE tournament_teams;
      CREATE TABLE tournament_teams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tournament_id INTEGER NOT NULL
          REFERENCES tournaments(id) ON DELETE CASCADE,
        captain_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        group_label TEXT,
        UNIQUE (tournament_id, captain_id)
      );
      CREATE UNIQUE INDEX tournament_teams_name_idx
      ON tournament_teams(tournament_id, name COLLATE NOCASE);
      PRAGMA foreign_keys = ON;
      INSERT INTO users (username, email, password_hash)
      VALUES ('captain', 'c@example.com', 'x'), ('rival', 'r@example.com', 'x'),
        ('player', 'p@example.com', 'x');
      INSERT INTO tournaments
        (name, format, start_date, end_date, max_teams)
      VALUES ('Cup', 'league', '2026-11-01', '2026-11-30', 4);
      INSERT INTO tournament_teams (tournament_id, captain_id, name, group_label)
      VALUES (1, 1, 'Red Lions', 'A'), (1, 2, 'Blue Hawks', 'A');
      INSERT INTO tournament_matches
        (tournament_id, home_team_id, away_team_id, status)
      VALUES (1, 1, 2, 'scheduled');
      INSERT INTO join_requests (tournament_id, team_id, requester_id, status)
      VALUES (1, 1, 3, 'accepted');
    ''');
    old.close();

    final migrated = AppDatabase(path);
    addTearDown(migrated.close);
    final db = migrated.db;
    expect(
      db
          .select('SELECT name, group_label, status FROM tournament_teams')
          .map((row) => (row['name'], row['group_label'], row['status'])),
      [('Red Lions', 'A', 'active'), ('Blue Hawks', 'A', 'active')],
    );
    expect(db.select('SELECT * FROM tournament_matches'), hasLength(1));
    expect(db.select('SELECT * FROM join_requests'), hasLength(1));
    expect(db.select('PRAGMA foreign_keys').single.values.single, 1);

    // A team that left no longer blocks its captain or its name.
    db.execute(
      "UPDATE tournament_teams SET status = 'left', "
      'left_at = CURRENT_TIMESTAMP WHERE id = 2',
    );
    db.execute(
      "INSERT INTO tournament_teams (tournament_id, captain_id, name) "
      "VALUES (1, 2, 'blue hawks')",
    );
    expect(
      () => db.execute(
        "INSERT INTO tournament_teams (tournament_id, captain_id, name) "
        "VALUES (1, 2, 'Green Owls')",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "UPDATE join_requests SET status = 'disbanded', "
        'notice_seen_at = CURRENT_TIMESTAMP WHERE id = 1',
      ),
      returnsNormally,
    );
  });
}
