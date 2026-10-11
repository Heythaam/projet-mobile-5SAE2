import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:backend/database.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:sqlite3/sqlite3.dart';

/// Inserts the "Champions League" knockout test tournament with its teams,
/// quarter-final results and semi-final fixtures.
///
/// Run from `backend/`: `dart run tool/seed_champions_league.dart`.
/// `DB_PATH` overrides the default database, as in `bin/server.dart`.
/// Each team needs its own captain, so PSG, Liverpool, Juventus and AC Milan
/// are captained by seed accounts with random passwords nobody knows. If the
/// tournament already exists nothing is changed, so the script can be rerun.
const _tournamentName = 'Champions League';
const _createdBy = 1;

/// Team name and captain: an existing user id, or a seed username.
const _teams = <(String, Object)>[
  ('Real Madrid', 1),
  ('Barcelona', 2),
  ('Manchester City', 3),
  ('Bayern Munich', 4),
  ('PSG', 'cl_psg'),
  ('Liverpool', 'cl_liverpool'),
  ('Juventus', 'cl_juventus'),
  ('AC Milan', 'cl_milan'),
];

/// Round, position, home, away, home score, away score, penalties winner.
const _matches = <(int, int, String, String, int?, int?, String?)>[
  (1, 1, 'Real Madrid', 'Barcelona', 2, 1, null),
  (1, 2, 'Manchester City', 'Bayern Munich', 3, 0, null),
  (1, 3, 'PSG', 'Liverpool', 1, 1, 'PSG'),
  (1, 4, 'Juventus', 'AC Milan', 0, 2, null),
  (2, 1, 'Real Madrid', 'Manchester City', null, null, null),
  (2, 2, 'AC Milan', 'PSG', null, null, null),
];

void main() {
  final path =
      Platform.environment['DB_PATH'] ?? 'data/football_matches.sqlite';
  final database = AppDatabase(path);
  final db = database.db;
  // The running API holds its own connection; wait for its writes to finish.
  db.execute('PRAGMA busy_timeout = 5000');
  try {
    final existing = db.select('SELECT id FROM tournaments WHERE name = ?', [
      _tournamentName,
    ]);
    if (existing.isNotEmpty) {
      print(
        'Skipped: "$_tournamentName" already exists '
        '(id ${existing.first['id']}).',
      );
      return;
    }
    for (final (_, captain) in _teams) {
      if (captain is int &&
          db.select('SELECT 1 FROM users WHERE id = ?', [captain]).isEmpty) {
        stderr.writeln('User $captain does not exist in $path.');
        exitCode = 1;
        return;
      }
    }

    db.execute('BEGIN IMMEDIATE');
    try {
      final tournamentId = _insertTournament(db);
      final teamIds = <String, int>{};
      for (final (name, captain) in _teams) {
        final captainId = captain is int ? captain : _seedUser(db, '$captain');
        db.execute(
          '''
            INSERT INTO tournament_teams (tournament_id, captain_id, name)
            VALUES (?, ?, ?)
          ''',
          [tournamentId, captainId, name],
        );
        teamIds[name] = db.lastInsertRowId;
      }
      for (final (round, position, home, away, homeScore, awayScore, winner)
          in _matches) {
        db.execute(
          '''
            INSERT INTO tournament_matches (tournament_id, stage, round,
              bracket_position, home_team_id, away_team_id, home_score,
              away_score, winner_team_id, status)
            VALUES (?, 'knockout', ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            tournamentId,
            round,
            position,
            teamIds[home],
            teamIds[away],
            homeScore,
            awayScore,
            winner == null ? null : teamIds[winner],
            homeScore == null ? 'scheduled' : 'played',
          ],
        );
      }
      db.execute('COMMIT');
      print(
        'Inserted "$_tournamentName" as id $tournamentId with '
        '${teamIds.length} teams and ${_matches.length} matches.',
      );
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    database.close();
  }
}

int _insertTournament(Database db) {
  db.execute(
    '''
      INSERT INTO tournaments (name, description, format, status, start_date,
        end_date, max_teams, team_size, location, created_by)
      VALUES (?, ?, 'knockout', 'active', '2026-10-01', '2026-12-15', 8, 5,
        'Tunis', ?)
    ''',
    [_tournamentName, 'UEFA Champions League style knockout cup', _createdBy],
  );
  return db.lastInsertRowId;
}

/// Returns the seed account [username], creating it with an unknowable
/// password if needed.
int _seedUser(Database db, String username) {
  final existing = db.select('SELECT id FROM users WHERE username = ?', [
    username,
  ]);
  if (existing.isNotEmpty) return existing.first['id'] as int;
  final random = Random.secure();
  final password = base64Url.encode([
    for (var i = 0; i < 32; i++) random.nextInt(256),
  ]);
  db.execute(
    '''
      INSERT INTO users (username, email, password_hash)
      VALUES (?, ?, ?)
    ''',
    [
      username,
      '$username@seed.kickoff.invalid',
      BCrypt.hashpw(password, BCrypt.gensalt()),
    ],
  );
  return db.lastInsertRowId;
}
