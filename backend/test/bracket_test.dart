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
  late String token;

  setUp(() async {
    database = AppDatabase(':memory:');
    app = createApp(database: database, jwtSecret: _secret);
    token = (await register(app, 'viewer'))['token'] as String;
  });

  tearDown(() => database.close());

  int seedTournament({String format = 'knockout'}) {
    database.db.execute(
      '''
        INSERT INTO tournaments (name, format, status, start_date, end_date,
          max_teams)
        VALUES ('Cup', ?, 'active', '2026-11-01', '2026-11-30', 16)
      ''',
      [format],
    );
    return database.db.lastInsertRowId;
  }

  /// Creates teams named after [names] (captained by new users) and returns
  /// their ids in order.
  List<int> seedTeams(int tournamentId, List<String> names, {String? group}) {
    return [
      for (final name in names)
        () {
          database.db.execute(
            '''
              INSERT INTO users (username, email, password_hash)
              VALUES (?, ?, 'x')
            ''',
            ['u_${name.toLowerCase().replaceAll(' ', '_')}', '$name@x.com'],
          );
          database.db.execute(
            '''
              INSERT INTO tournament_teams
                (tournament_id, captain_id, name, group_label)
              VALUES (?, ?, ?, ?)
            ''',
            [tournamentId, database.db.lastInsertRowId, name, group],
          );
          return database.db.lastInsertRowId;
        }(),
    ];
  }

  void match(
    int tournamentId, {
    required int round,
    int? position,
    int? home,
    int? away,
    int? homeScore,
    int? awayScore,
    int? winner,
    String status = 'scheduled',
    String stage = 'knockout',
  }) => database.db.execute(
    '''
      INSERT INTO tournament_matches (tournament_id, stage, round,
        bracket_position, home_team_id, away_team_id, home_score, away_score,
        winner_team_id, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      tournamentId,
      stage,
      round,
      position,
      home,
      away,
      homeScore,
      awayScore,
      winner,
      status,
    ],
  );

  Future<List<Map<String, dynamic>>> bracket(int tournamentId) async {
    final response = await sendRequest(
      app,
      'GET',
      '/tournaments/$tournamentId/bracket',
      token: token,
    );
    expect(response.statusCode, 200);
    return ((await decode(response))['bracket']['rounds'] as List)
        .cast<Map<String, dynamic>>();
  }

  String? teamName(Object? side) =>
      side == null ? null : (side as Map<String, dynamic>)['name'] as String;

  test('the bracket requires a session and an existing tournament', () async {
    final id = seedTournament();
    final anonymous = await sendRequest(app, 'GET', '/tournaments/$id/bracket');
    expect(anonymous.statusCode, 401);
    final missing = await sendRequest(
      app,
      'GET',
      '/tournaments/999/bracket',
      token: token,
    );
    expect(missing.statusCode, 404);
    expect(await bracket(id), isEmpty);
  });

  test('winners, including on penalties, fill the next round', () async {
    final id = seedTournament();
    final [lions, hawks, owls, bears] = seedTeams(id, [
      'Lions',
      'Hawks',
      'Owls',
      'Bears',
    ]);
    match(
      id,
      round: 1,
      position: 1,
      home: lions,
      away: hawks,
      homeScore: 2,
      awayScore: 1,
      status: 'played',
    );
    match(
      id,
      round: 1,
      position: 2,
      home: owls,
      away: bears,
      homeScore: 1,
      awayScore: 1,
      winner: bears,
      status: 'played',
    );

    final rounds = await bracket(id);
    expect(rounds.map((round) => round['roundsFromEnd']), [1, 0]);
    final semis = (rounds.first['matches'] as List)
        .cast<Map<String, dynamic>>();
    expect(semis.map((m) => m['winnerId']), [lions, bears]);
    expect(semis.last['homeScore'], 1);
    final finalMatch = (rounds.last['matches'] as List).single;
    expect(finalMatch['id'], isNull);
    expect(finalMatch['status'], 'pending');
    expect(teamName(finalMatch['home']), 'Lions');
    expect(teamName(finalMatch['away']), 'Bears');
  });

  test('draws without a recorded winner leave the next slot open', () async {
    final id = seedTournament();
    final [lions, hawks] = seedTeams(id, ['Lions', 'Hawks']);
    match(
      id,
      round: 1,
      home: lions,
      away: hawks,
      homeScore: 0,
      awayScore: 0,
      status: 'played',
    );

    final rounds = await bracket(id);
    expect(rounds, hasLength(1));
    expect((rounds.single['matches'] as List).single['winnerId'], isNull);
  });

  test('byes send a team straight to the next round', () async {
    final id = seedTournament();
    final [lions, hawks, owls] = seedTeams(id, ['Lions', 'Hawks', 'Owls']);
    match(id, round: 1, position: 1, home: lions, away: hawks);
    match(id, round: 1, position: 2, home: owls, status: 'bye');

    final rounds = await bracket(id);
    final first = (rounds.first['matches'] as List)
        .cast<Map<String, dynamic>>();
    expect(first.last['status'], 'bye');
    expect(first.last['away'], isNull);
    expect(first.last['winnerId'], owls);
    final finalMatch = (rounds.last['matches'] as List).single;
    expect(finalMatch['home'], isNull);
    expect(teamName(finalMatch['away']), 'Owls');
  });

  test('matches keep their bracket positions and missing ones pend', () async {
    final id = seedTournament();
    final teams = seedTeams(id, ['A1', 'A2', 'C1', 'C2', 'X1', 'X2']);
    match(id, round: 1, position: 3, home: teams[2], away: teams[3]);
    match(id, round: 1, position: 1, home: teams[0], away: teams[1]);
    // Without a position, a row fills the first free slot.
    match(id, round: 1, home: teams[4], away: teams[5]);

    final rounds = await bracket(id);
    expect(rounds.map((round) => (round['matches'] as List).length), [4, 2, 1]);
    final first = (rounds.first['matches'] as List)
        .cast<Map<String, dynamic>>();
    expect(first.map((m) => m['position']), [1, 2, 3, 4]);
    expect(first.map((m) => teamName(m['home'])), ['A1', 'X1', 'C1', null]);
    expect(first.last['status'], 'pending');
  });

  test('group matches stay out of the bracket and stand per group', () async {
    final id = seedTournament(format: 'groups_knockout');
    final [a1, a2] = seedTeams(id, ['Alpha One', 'Alpha Two'], group: 'A');
    final [b1, b2] = seedTeams(id, ['Beta One', 'Beta Two'], group: 'B');
    match(
      id,
      round: 1,
      home: a1,
      away: a2,
      homeScore: 0,
      awayScore: 2,
      status: 'played',
      stage: 'group',
    );
    match(
      id,
      round: 1,
      home: b1,
      away: b2,
      homeScore: 3,
      awayScore: 0,
      status: 'played',
      stage: 'group',
    );
    // A knockout result must not change the group tables.
    match(
      id,
      round: 1,
      home: a1,
      away: b2,
      homeScore: 5,
      awayScore: 0,
      status: 'played',
    );

    final rounds = await bracket(id);
    expect(rounds.single['matches'], hasLength(1));

    final response = await sendRequest(
      app,
      'GET',
      '/tournaments/$id/standings',
      token: token,
    );
    final rows = ((await decode(response))['standings'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      rows.map((row) => (row['group'], row['position'], row['teamName'])),
      [
        ('A', 1, 'Alpha Two'),
        ('A', 2, 'Alpha One'),
        ('B', 1, 'Beta One'),
        ('B', 2, 'Beta Two'),
      ],
    );
    expect(rows[1]['goalsFor'], 0);
  });

  test('match rows must make sense', () {
    final id = seedTournament();
    final [lions, hawks] = seedTeams(id, ['Lions', 'Hawks']);
    void rejects(void Function() insert) =>
        expect(insert, throwsA(isA<SqliteException>()));

    // Group matches always name both teams.
    rejects(() => match(id, round: 1, home: lions, stage: 'group'));
    // Byes are knockout-only and have no opponent.
    rejects(() => match(id, round: 1, home: lions, away: hawks, status: 'bye'));
    rejects(
      () => match(id, round: 1, home: lions, status: 'bye', stage: 'group'),
    );
    // Played matches need both teams and scores.
    rejects(
      () => match(id, round: 1, home: lions, homeScore: 1, status: 'played'),
    );
    // The recorded winner must have played.
    final [owls] = seedTeams(id, ['Owls']);
    rejects(() => match(id, round: 1, home: lions, away: hawks, winner: owls));
    // One match per bracket slot.
    match(id, round: 1, position: 1, home: lions, away: hawks);
    rejects(() => match(id, round: 1, position: 1, home: owls));
  });

  test('older match tables are rebuilt and keep their rows', () {
    final directory = Directory.systemTemp.createTempSync('kickoff_matches_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/old.sqlite';
    AppDatabase(path).close();
    final old = sqlite3.open(path);
    old.execute('''
      INSERT INTO users (username, email, password_hash)
      VALUES ('one', 'one@x.com', 'x'), ('two', 'two@x.com', 'x');
      INSERT INTO tournaments (name, format, start_date, end_date, max_teams)
      VALUES ('Cup', 'league', '2026-11-01', '2026-11-30', 4);
      INSERT INTO tournament_teams (tournament_id, captain_id, name)
      VALUES (1, 1, 'Lions'), (1, 2, 'Hawks');
      DROP TABLE tournament_matches;
      CREATE TABLE tournament_matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tournament_id INTEGER NOT NULL
          REFERENCES tournaments(id) ON DELETE CASCADE,
        home_team_id INTEGER NOT NULL
          REFERENCES tournament_teams(id) ON DELETE CASCADE,
        away_team_id INTEGER NOT NULL
          REFERENCES tournament_teams(id) ON DELETE CASCADE,
        round INTEGER NOT NULL DEFAULT 1,
        home_score INTEGER CHECK (home_score >= 0),
        away_score INTEGER CHECK (away_score >= 0),
        scheduled_at TEXT,
        status TEXT NOT NULL DEFAULT 'scheduled' CHECK (
          status IN ('scheduled', 'played', 'cancelled')
        ),
        CHECK (home_team_id != away_team_id)
      );
      INSERT INTO tournament_matches
        (tournament_id, home_team_id, away_team_id, home_score, away_score,
         status)
      VALUES (1, 1, 2, 3, 1, 'played');
    ''');
    old.close();

    final migrated = AppDatabase(path);
    addTearDown(migrated.close);
    final rows = migrated.db.select(
      'SELECT stage, home_score, status FROM tournament_matches',
    );
    expect(rows.single['stage'], 'group');
    expect(rows.single['home_score'], 3);
    migrated.db.execute('''
      INSERT INTO tournament_matches (tournament_id, stage, home_team_id,
        status)
      VALUES (1, 'knockout', 1, 'bye')
    ''');
    final indexes = migrated.db.select(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND tbl_name = 'tournament_matches' AND sql IS NOT NULL",
    );
    expect(indexes.map((row) => row['name']), {
      'tournament_matches_tournament_idx',
      'tournament_matches_slot_idx',
    });
  });
}
