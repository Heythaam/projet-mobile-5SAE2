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
    final teams = (await decode(response))['tournament']['teams'] as List;
    return (teams.last as Map<String, dynamic>)['id'] as int;
  }

  /// Sends a request from [player] and has [captain] accept it.
  Future<void> addPlayer(
    String captain,
    String player,
    int id,
    int team,
  ) async {
    await sendRequest(
      app,
      'POST',
      '/tournaments/$id/teams/$team/request',
      token: player,
    );
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

  Future<Response> get(String token, String path) =>
      sendRequest(app, 'GET', path, token: token);

  Future<Response> remove(String token, int id, int team, int member) =>
      sendRequest(
        app,
        'DELETE',
        '/tournaments/$id/teams/$team/members/$member',
        token: token,
      );

  test('new routes require a session', () async {
    for (final (method, path) in [
      ('GET', '/me/tournament-requests'),
      ('GET', '/users/1/profile'),
      ('GET', '/tournaments/1/teams/1'),
      ('DELETE', '/tournaments/1/teams/1/members/2'),
    ]) {
      final response = await sendRequest(app, method, path);
      expect(response.statusCode, 401, reason: '$method $path');
    }
  });

  test('team details list the captain first with players and stats', () async {
    final (captain, captainId) = await user('captain');
    final (player, playerId) = await user('player');
    final (rival, _) = await user('rival');
    final id = seedTournament();
    final team = await createTeam(captain, id, 'Red Lions');
    final rivalTeam = await createTeam(rival, id, 'Blue Hawks');
    await addPlayer(captain, player, id, team);
    database.db.execute('UPDATE users SET xp = 650 WHERE id = ?', [playerId]);
    database.db.execute(
      '''
        INSERT INTO tournament_matches
          (tournament_id, home_team_id, away_team_id, home_score, away_score,
           status)
        VALUES (?1, ?2, ?3, 3, 1, 'played'), (?1, ?3, ?2, 2, 2, 'played'),
          (?1, ?2, ?3, NULL, NULL, 'scheduled')
      ''',
      [id, team, rivalTeam],
    );

    final response = await get(rival, '/tournaments/$id/teams/$team');
    expect(response.statusCode, 200);
    final details = (await decode(response))['team'] as Map<String, dynamic>;
    expect(details['name'], 'Red Lions');
    expect(details['captainName'], 'captain');
    expect(details['canManage'], isFalse);
    final players = (details['players'] as List).cast<Map<String, dynamic>>();
    expect(players.map((p) => p['id']), [captainId, playerId]);
    expect(players.first['isCaptain'], isTrue);
    expect(players.last['level'], 3);
    expect(players.first.containsKey('email'), isFalse);
    expect(details['stats'], {
      'players': 2,
      'totalXp': 50 + 650,
      'averageLevel': 2,
      'played': 2,
      'wins': 1,
      'draws': 1,
      'losses': 0,
      'goalsFor': 5,
      'goalsAgainst': 3,
      'points': 4,
    });

    final own = await decode(
      await get(captain, '/tournaments/$id/teams/$team'),
    );
    expect(own['team']['canManage'], isTrue);
    expect((await get(captain, '/tournaments/$id/teams/999')).statusCode, 404);
    final other = seedTournament(name: 'Other Cup');
    expect(
      (await get(captain, '/tournaments/$other/teams/$team')).statusCode,
      404,
    );
  });

  test('captains remove players before kickoff only', () async {
    final (captain, captainId) = await user('captain');
    final (player, playerId) = await user('player');
    final (rival, _) = await user('rival');
    final id = seedTournament();
    final team = await createTeam(captain, id, 'Red Lions');
    final rivalTeam = await createTeam(rival, id, 'Blue Hawks');
    await addPlayer(captain, player, id, team);

    expect((await remove(rival, id, team, playerId)).statusCode, 404);
    expect((await remove(player, id, team, playerId)).statusCode, 404);
    final self = await remove(captain, id, team, captainId);
    expect(self.statusCode, 400);
    expect((await remove(captain, id, team, 999)).statusCode, 404);

    final removed = await remove(captain, id, team, playerId);
    expect(removed.statusCode, 200);
    expect((await decode(removed))['team']['players'], hasLength(1));
    final again = await remove(captain, id, team, playerId);
    expect(again.statusCode, 404);

    final playerView = await decode(await get(player, '/tournaments/$id'));
    expect(playerView['tournament']['myTeamId'], isNull);
    expect(playerView['tournament']['myRequests'], [
      {'teamId': team, 'status': 'removed'},
    ]);
    final sameTeam = await sendRequest(
      app,
      'POST',
      '/tournaments/$id/teams/$team/request',
      token: player,
    );
    expect(sameTeam.statusCode, 409);
    expect((await decode(sameTeam))['error'], contains('removed'));
    final otherTeam = await sendRequest(
      app,
      'POST',
      '/tournaments/$id/teams/$rivalTeam/request',
      token: player,
    );
    expect(otherTeam.statusCode, 201);

    // With no players left, the captain may leave again.
    final captainView = await decode(await get(captain, '/tournaments/$id'));
    expect(captainView['tournament']['canLeave'], isTrue);

    await addPlayer(rival, player, id, rivalTeam);
    database.db.execute(
      "UPDATE tournaments SET status = 'active' WHERE id = ?",
      [id],
    );
    final locked = await remove(rival, id, rivalTeam, playerId);
    expect(locked.statusCode, 409);
    expect((await decode(locked))['error'], contains('before'));
  });

  test('captains see their pending request total', () async {
    final (captain, _) = await user('captain');
    final (first, _) = await user('first');
    final (second, _) = await user('second');
    final cup = seedTournament();
    final league = seedTournament(name: 'League');
    final closed = seedTournament(name: 'Closed');
    final cupTeam = await createTeam(captain, cup, 'Red Lions');
    final leagueTeam = await createTeam(captain, league, 'Red Lions');
    final closedTeam = await createTeam(captain, closed, 'Red Lions');
    for (final (tournament, team) in [
      (cup, cupTeam),
      (league, leagueTeam),
      (closed, closedTeam),
    ]) {
      await sendRequest(
        app,
        'POST',
        '/tournaments/$tournament/teams/$team/request',
        token: first,
      );
    }
    await sendRequest(
      app,
      'POST',
      '/tournaments/$cup/teams/$cupTeam/request',
      token: second,
    );
    database.db.execute(
      "UPDATE tournaments SET status = 'active' WHERE id = ?",
      [closed],
    );

    final summary = await decode(await get(captain, '/me/tournament-requests'));
    expect(summary['pendingRequests'], 3);
    final none = await decode(await get(first, '/me/tournament-requests'));
    expect(none['pendingRequests'], 0);
  });

  test('profiles are visible only to related players', () async {
    final (captain, _) = await user('captain');
    final (player, playerId) = await user('player');
    final (stranger, _) = await user('stranger');
    final (rival, _) = await user('rival');
    final id = seedTournament();
    final team = await createTeam(captain, id, 'Red Lions');
    final rivalTeam = await createTeam(rival, id, 'Blue Hawks');
    await sendRequest(
      app,
      'POST',
      '/tournaments/$id/teams/$team/request',
      token: player,
    );

    // A pending requester shares the tournament with the captain.
    final viewed = await get(captain, '/users/$playerId/profile');
    expect(viewed.statusCode, 200);
    final profile = (await decode(viewed))['profile'] as Map<String, dynamic>;
    expect(profile['username'], 'player');
    expect(profile['xp'], 50);
    expect(profile['level'], 1);
    expect(profile['rank'], 'ROOKIE');
    expect(profile['currentStreak'], 1);
    expect(profile['bestStreak'], 1);
    expect(profile['achievements'], [
      {
        'code': 'first_kickoff',
        'title': 'FIRST KICKOFF',
        'icon': 'whistle',
        'unlockedAt': isA<String>(),
      },
    ]);
    expect(profile['recentMatches'], isEmpty);
    for (final hidden in ['email', 'passwordHash', 'sentMessages']) {
      expect(profile.containsKey(hidden), isFalse, reason: hidden);
    }

    expect((await get(stranger, '/users/$playerId/profile')).statusCode, 404);
    expect((await get(player, '/users/$playerId/profile')).statusCode, 200);
    expect((await get(captain, '/users/999/profile')).statusCode, 404);
    expect((await get(captain, '/users/abc/profile')).statusCode, 400);

    // Played matches of the player's team appear once they are accepted.
    final requestId = (await decode(
      await get(captain, '/tournaments/$id/requests'),
    ))['requests'][0]['id'];
    await sendRequest(
      app,
      'PUT',
      '/tournaments/$id/requests/$requestId',
      token: captain,
      body: {'status': 'accepted'},
    );
    database.db.execute(
      '''
        INSERT INTO tournament_matches
          (tournament_id, home_team_id, away_team_id, home_score, away_score,
           status, scheduled_at)
        VALUES (?1, ?3, ?2, 2, 1, 'played', '2026-11-02T10:00:00Z')
      ''',
      [id, team, rivalTeam],
    );
    final withMatches = await decode(
      await get(rival, '/users/$playerId/profile'),
    );
    expect(withMatches['profile']['recentMatches'], [
      {
        'tournamentName': 'Sunday Cup',
        'teamName': 'Red Lions',
        'opponentName': 'Blue Hawks',
        'goalsFor': 1,
        'goalsAgainst': 2,
        'result': 'loss',
        'playedAt': '2026-11-02T10:00:00Z',
      },
    ]);
  });

  test('friends can view each other profiles', () async {
    final alice = await register(app, 'alice');
    final bob = await register(app, 'bob');
    await sendRequest(
      app,
      'POST',
      '/friend-requests',
      token: alice['token'] as String,
      body: {'username': 'bob'},
    );
    final aliceId = (alice['user'] as Map<String, dynamic>)['id'];
    final bobToken = bob['token'] as String;
    expect((await get(bobToken, '/users/$aliceId/profile')).statusCode, 404);
    final incoming = await decode(await get(bobToken, '/friend-requests'));
    final friendRequestId = (incoming['requests'] as List).single['id'];
    final accepted = await sendRequest(
      app,
      'POST',
      '/friend-requests/$friendRequestId/accept',
      token: bobToken,
    );
    expect(accepted.statusCode, 200);
    expect((await get(bobToken, '/users/$aliceId/profile')).statusCode, 200);
  });

  test('older databases gain the removed request status', () {
    final directory = Directory.systemTemp.createTempSync('kickoff_db_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/old.sqlite';
    AppDatabase(path).close();
    // Recreate the previous schema without 'removed', with one request.
    final old = sqlite3.open(path);
    old.execute('''
      INSERT INTO users (username, email, password_hash)
      VALUES ('captain', 'c@example.com', 'x'), ('player', 'p@example.com', 'x');
      INSERT INTO tournaments
        (name, format, start_date, end_date, max_teams)
      VALUES ('Cup', 'league', '2026-11-01', '2026-11-30', 4);
      INSERT INTO tournament_teams (tournament_id, captain_id, name)
      VALUES (1, 1, 'Red Lions');
      DROP TABLE join_requests;
      CREATE TABLE join_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tournament_id INTEGER NOT NULL
          REFERENCES tournaments(id) ON DELETE CASCADE,
        team_id INTEGER NOT NULL
          REFERENCES tournament_teams(id) ON DELETE CASCADE,
        requester_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (
          status IN ('pending', 'accepted', 'declined', 'cancelled')
        ),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        responded_at TEXT
      );
      INSERT INTO join_requests (tournament_id, team_id, requester_id, status)
      VALUES (1, 1, 2, 'accepted');
    ''');
    old.close();

    final migrated = AppDatabase(path);
    addTearDown(migrated.close);
    migrated.db.execute(
      "UPDATE join_requests SET status = 'removed' WHERE id = 1",
    );
    expect(
      migrated.db.select('SELECT status FROM join_requests').single['status'],
      'removed',
    );
    expect(
      migrated.db.select(
        "SELECT name FROM sqlite_master WHERE tbl_name = 'join_requests' "
        "AND type = 'index'",
      ),
      hasLength(2),
    );
  });
}
