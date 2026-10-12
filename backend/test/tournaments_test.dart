import 'package:backend/app.dart';
import 'package:backend/database.dart';
import 'package:shelf/shelf.dart';
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

  int seedTournament({
    String name = 'Sunday Cup',
    String status = 'upcoming',
    int maxTeams = 4,
    String startDate = '2026-11-01T10:00:00Z',
  }) {
    database.db.execute(
      '''
        INSERT INTO tournaments
          (name, description, format, status, start_date, end_date,
           max_teams, location, prize)
        VALUES (?, 'Weekend cup.', 'league', ?, ?, '2026-11-30T18:00:00Z',
          ?, 'City Park', 'Trophy')
      ''',
      [name, status, startDate, maxTeams],
    );
    return database.db.lastInsertRowId;
  }

  var teamCount = 0;
  Future<Response> join(String token, int tournamentId, {String? name}) =>
      sendRequest(
        app,
        'POST',
        '/tournaments/$tournamentId/join',
        token: token,
        body: {'name': name ?? 'Team ${++teamCount}'},
      );

  test('lists tournaments with status filter and join state', () async {
    final alice = await register(app, 'alice');
    final token = alice['token'] as String;
    final cup = seedTournament();
    seedTournament(name: 'Old Cup', status: 'finished');
    seedTournament(name: 'Live Cup', status: 'active');
    expect((await join(token, cup)).statusCode, 200);

    final all = await decode(
      await sendRequest(app, 'GET', '/tournaments', token: token),
    );
    final tournaments = (all['tournaments'] as List)
        .cast<Map<String, dynamic>>();
    expect(tournaments.map((tournament) => tournament['name']), [
      'Live Cup',
      'Sunday Cup',
      'Old Cup',
    ]);
    final sunday = tournaments[1];
    expect(sunday['currentTeams'], 1);
    expect(sunday['maxTeams'], 4);
    expect(sunday['joined'], isTrue);
    expect(sunday['startDate'], '2026-11-01T10:00:00Z');
    expect(sunday.containsKey('teams'), isFalse);

    final finished = await decode(
      await sendRequest(
        app,
        'GET',
        '/tournaments?status=finished',
        token: token,
      ),
    );
    expect((finished['tournaments'] as List).single['name'], 'Old Cup');

    final invalid = await sendRequest(
      app,
      'GET',
      '/tournaments?status=nope',
      token: token,
    );
    expect(invalid.statusCode, 400);
  });

  test('tournament routes require a session', () async {
    final id = seedTournament();
    for (final (method, path) in [
      ('GET', '/tournaments'),
      ('GET', '/tournaments/$id'),
      ('POST', '/tournaments/$id/join'),
      ('DELETE', '/tournaments/$id/join'),
      ('GET', '/tournaments/$id/standings'),
    ]) {
      final response = await sendRequest(app, method, path);
      expect(response.statusCode, 401, reason: '$method $path');
    }
  });

  test('details include teams and reject unknown ids', () async {
    final alice = await register(app, 'alice');
    final bob = await register(app, 'bob');
    final id = seedTournament();
    await join(bob['token'] as String, id, name: 'Blue Hawks');

    final detail = await decode(
      await sendRequest(
        app,
        'GET',
        '/tournaments/$id',
        token: alice['token'] as String,
      ),
    );
    final tournament = detail['tournament'] as Map<String, dynamic>;
    expect(tournament['joined'], isFalse);
    expect(tournament['prize'], 'Trophy');
    expect(tournament['teams'], [
      {'id': 1, 'name': 'Blue Hawks', 'players': 1},
    ]);

    final missing = await sendRequest(
      app,
      'GET',
      '/tournaments/999',
      token: alice['token'] as String,
    );
    expect(missing.statusCode, 404);
    final malformed = await sendRequest(
      app,
      'GET',
      '/tournaments/abc',
      token: alice['token'] as String,
    );
    expect(malformed.statusCode, 400);
  });

  test('join enforces duplicates, capacity, and registration status', () async {
    final players = [
      for (final name in ['alice', 'bob', 'carol']) await register(app, name),
    ];
    final tokens = [for (final player in players) player['token'] as String];
    final id = seedTournament(maxTeams: 2);

    final joined = await join(tokens[0], id);
    expect(joined.statusCode, 200);
    final joinedJson = await decode(joined);
    expect(joinedJson['tournament']['joined'], isTrue);
    expect(joinedJson['tournament']['currentTeams'], 1);

    final duplicate = await join(tokens[0], id);
    expect(duplicate.statusCode, 409);
    expect((await decode(duplicate))['error'], contains('already joined'));

    expect((await join(tokens[1], id)).statusCode, 200);
    final full = await join(tokens[2], id);
    expect(full.statusCode, 409);
    expect((await decode(full))['error'], contains('full'));

    for (final status in ['active', 'finished', 'cancelled']) {
      final closed = await join(tokens[2], seedTournament(status: status));
      expect(closed.statusCode, 409, reason: status);
    }
    expect((await join(tokens[2], 999)).statusCode, 404);

    final count = database.db.select(
      'SELECT COUNT(*) AS teams FROM tournament_teams WHERE tournament_id = ?',
      [id],
    );
    expect(count.first['teams'], 2);
  });

  test('join requires a valid team name unique in the tournament', () async {
    final alice = (await register(app, 'alice'))['token'] as String;
    final bob = (await register(app, 'bob'))['token'] as String;
    final id = seedTournament();
    final other = seedTournament(name: 'Other Cup');

    final noBody = await sendRequest(
      app,
      'POST',
      '/tournaments/$id/join',
      token: alice,
    );
    expect(noBody.statusCode, 400);
    for (final invalid in ['', '   ', 'ab', 'x' * 31, '<b>Lions</b>', '---']) {
      final response = await join(alice, id, name: invalid);
      expect(response.statusCode, 400, reason: 'name "$invalid"');
    }

    final joined = await join(alice, id, name: '  Red   Lions  ');
    expect(joined.statusCode, 200);
    final teams = ((await decode(joined))['tournament']['teams'] as List)
        .cast<Map<String, dynamic>>();
    expect(teams.single['name'], 'Red Lions');

    final taken = await join(bob, id, name: 'red lions');
    expect(taken.statusCode, 409);
    expect((await decode(taken))['error'], contains('already taken'));
    expect((await join(bob, other, name: 'Red Lions')).statusCode, 200);
    expect((await join(bob, id, name: "Bob's F.C. 2-0_")).statusCode, 200);
    expect((await join(alice, other, name: 'Équipe Sfax')).statusCode, 200);
  });

  test('leaving frees the spot only before the tournament starts', () async {
    final alice = (await register(app, 'alice'))['token'] as String;
    final bob = (await register(app, 'bob'))['token'] as String;
    Future<Response> leave(String token, int tournamentId) => sendRequest(
      app,
      'DELETE',
      '/tournaments/$tournamentId/join',
      token: token,
    );
    final id = seedTournament(maxTeams: 2);

    final notJoined = await leave(alice, id);
    expect(notJoined.statusCode, 409);
    expect((await decode(notJoined))['error'], contains('not joined'));

    await join(alice, id, name: 'Red Lions');
    await join(bob, id, name: 'Blue Hawks');
    final left = await leave(alice, id);
    expect(left.statusCode, 200);
    final tournament = (await decode(left))['tournament'];
    expect(tournament['joined'], isFalse);
    expect(tournament['currentTeams'], 1);
    expect(tournament['teams'], [
      {'id': 2, 'name': 'Blue Hawks', 'players': 1},
    ]);
    expect(tournament['canLeave'], isFalse);
    // The spot and the name are free again.
    final rejoined = await join(alice, id, name: 'Red Lions');
    expect(rejoined.statusCode, 200);
    expect((await decode(rejoined))['tournament']['canLeave'], isTrue);

    // Scheduled fixtures keep the team, even while registration is open.
    database.db.execute(
      '''
        INSERT INTO tournament_matches
          (tournament_id, home_team_id, away_team_id, status)
        VALUES (?, 2, 3, 'scheduled')
      ''',
      [id],
    );
    final bobDetail = await decode(
      await sendRequest(app, 'GET', '/tournaments/$id', token: bob),
    );
    expect(bobDetail['tournament']['canLeave'], isFalse);
    final withMatches = await leave(bob, id);
    expect(withMatches.statusCode, 409);
    expect((await decode(withMatches))['error'], contains('matches'));

    for (final status in ['active', 'finished', 'cancelled']) {
      final other = seedTournament(name: 'Cup $status');
      await join(alice, other, name: 'Red Lions');
      database.db.execute('UPDATE tournaments SET status = ? WHERE id = ?', [
        status,
        other,
      ]);
      final closed = await leave(alice, other);
      expect(closed.statusCode, 409, reason: status);
      expect((await decode(closed))['error'], contains('before'));
    }
    expect((await leave(alice, 999)).statusCode, 404);
    expect((await leave(alice, 0)).statusCode, 404);
    // The team that left is kept as history, with when it left.
    final rows = database.db.select(
      '''
        SELECT name, status, left_at FROM tournament_teams
        WHERE tournament_id = ? ORDER BY id
      ''',
      [id],
    );
    expect(rows.map((row) => row['status']), ['left', 'active', 'active']);
    expect(rows.first['name'], 'Red Lions');
    expect(rows.first['left_at'], isNotNull);
    expect(rows.skip(1).map((row) => row['left_at']), [null, null]);
  });

  test('standings are computed from played matches only', () async {
    final players = [
      for (final name in ['alice', 'bob', 'carol']) await register(app, name),
    ];
    final id = seedTournament();
    for (final player in players) {
      await join(
        player['token'] as String,
        id,
        name: player['user']['username'] as String,
      );
    }
    // Team ids follow join order: alice=1, bob=2, carol=3.
    void match(int home, int away, int? homeScore, int? awayScore, String s) =>
        database.db.execute(
          '''
            INSERT INTO tournament_matches
              (tournament_id, home_team_id, away_team_id,
               home_score, away_score, status)
            VALUES (?, ?, ?, ?, ?, ?)
          ''',
          [id, home, away, homeScore, awayScore, s],
        );
    match(2, 1, 3, 0, 'played');
    match(1, 3, 1, 1, 'played');
    match(3, 2, 2, 2, 'played');
    match(1, 2, null, null, 'scheduled');

    final response = await sendRequest(
      app,
      'GET',
      '/tournaments/$id/standings',
      token: players[0]['token'] as String,
    );
    expect(response.statusCode, 200);
    final rows = ((await decode(response))['standings'] as List)
        .cast<Map<String, dynamic>>();

    expect(rows.map((row) => row['teamName']), ['bob', 'carol', 'alice']);
    expect(rows.map((row) => row['position']), [1, 2, 3]);
    expect(rows.first, {
      'position': 1,
      'teamId': 2,
      'teamName': 'bob',
      'played': 2,
      'wins': 1,
      'draws': 1,
      'losses': 0,
      'goalsFor': 5,
      'goalsAgainst': 2,
      'goalDifference': 3,
      'points': 4,
      'isUserTeam': false,
      'group': null,
    });
    expect(rows.last['isUserTeam'], isTrue);
    expect(rows.last['goalDifference'], -3);
    expect(rows.last['points'], 1);

    final missing = await sendRequest(
      app,
      'GET',
      '/tournaments/999/standings',
      token: players[0]['token'] as String,
    );
    expect(missing.statusCode, 404);
  });
}
