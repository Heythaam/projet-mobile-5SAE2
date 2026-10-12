import 'dart:io';

import 'package:backend/database.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:sqlite3/sqlite3.dart';

/// Restores the test data from scratch: seed accounts, the four test
/// tournaments, and the Champions League teams and bracket.
///
/// Run from `backend/`: `dart run bin/seed.dart`.
/// `DB_PATH` overrides the default database, as in `bin/server.dart`.
/// Every run first deletes the seed accounts (by their `@kickoff.test`
/// emails) and the seed tournaments (by name), whose teams, matches and
/// requests cascade, then inserts everything again. Other accounts are kept.
const _password = 'Test1234!';

/// Accounts from the old `tool/` seed scripts, removed along with ours.
const _legacyEmailDomain = '@seed.kickoff.invalid';

const _users = [
  'alice',
  'bob',
  'carlos',
  'diana',
  'cl_psg',
  'cl_liv',
  'cl_juve',
  'cl_milan',
];

String _email(String username) => '$username@kickoff.test';

const _tournaments = [
  (
    name: 'Champions Cup',
    description: 'Annual knockout championship',
    format: 'knockout',
    status: 'active',
    startDate: '2026-10-01',
    endDate: '2026-11-30',
    maxTeams: 8,
    location: 'Tunis',
  ),
  (
    name: 'City League',
    description: 'City-wide league tournament',
    format: 'league',
    status: 'upcoming',
    startDate: '2026-11-01',
    endDate: '2026-12-31',
    maxTeams: 6,
    location: 'Sfax',
  ),
  (
    name: 'Summer Cup',
    description: 'Summer round robin cup',
    format: 'round_robin',
    status: 'finished',
    startDate: '2026-07-01',
    endDate: '2026-08-30',
    maxTeams: 4,
    location: 'Sousse',
  ),
  (
    name: 'Champions League',
    description: 'UEFA Champions League style knockout cup',
    format: 'knockout',
    status: 'active',
    startDate: '2026-10-01',
    endDate: '2026-12-15',
    maxTeams: 8,
    location: 'Tunis',
  ),
];

const _bracketTournament = 'Champions League';

/// Team name and captain username.
const _teams = [
  ('Real Madrid', 'alice'),
  ('Barcelona', 'bob'),
  ('Manchester City', 'carlos'),
  ('Bayern Munich', 'diana'),
  ('PSG', 'cl_psg'),
  ('Liverpool', 'cl_liv'),
  ('Juventus', 'cl_juve'),
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
    // A real account holding a seed username must not be deleted or clash.
    for (final username in _users) {
      final taken = db.select(
        'SELECT email FROM users '
        'WHERE username = ? AND email != ? AND email NOT LIKE ?',
        [username, _email(username), '%$_legacyEmailDomain'],
      );
      if (taken.isNotEmpty) {
        stderr.writeln(
          'Username "$username" belongs to ${taken.first['email']}; '
          'nothing was changed.',
        );
        exitCode = 1;
        return;
      }
    }

    // Hash outside the transaction so the API is not blocked meanwhile.
    final hashes = {
      for (final username in _users)
        username: BCrypt.hashpw(_password, BCrypt.gensalt()),
    };

    db.execute('BEGIN IMMEDIATE');
    try {
      _clear(db);
      final userIds = {
        for (final username in _users)
          username: _insertUser(db, username, hashes[username]!),
      };
      print('Users (password $_password):');
      userIds.forEach((name, id) => print('  $name <${_email(name)}> id $id'));

      final tournamentIds = <String, int>{};
      print('Tournaments:');
      for (final tournament in _tournaments) {
        db.execute(
          '''
            INSERT INTO tournaments (name, description, format, status,
              start_date, end_date, max_teams, location, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            tournament.name,
            tournament.description,
            tournament.format,
            tournament.status,
            tournament.startDate,
            tournament.endDate,
            tournament.maxTeams,
            tournament.location,
            userIds['alice'],
          ],
        );
        tournamentIds[tournament.name] = db.lastInsertRowId;
        print(
          '  ${tournament.name} (${tournament.format}, ${tournament.status}) '
          'id ${db.lastInsertRowId}',
        );
      }

      final tournamentId = tournamentIds[_bracketTournament]!;
      final teamIds = <String, int>{};
      print('$_bracketTournament teams:');
      for (final (name, captain) in _teams) {
        db.execute(
          '''
            INSERT INTO tournament_teams (tournament_id, captain_id, name)
            VALUES (?, ?, ?)
          ''',
          [tournamentId, userIds[captain], name],
        );
        teamIds[name] = db.lastInsertRowId;
        print('  $name (captain $captain) id ${db.lastInsertRowId}');
      }

      print('$_bracketTournament bracket:');
      for (final (round, position, home, away, homeScore, awayScore, winner)
          in _matches) {
        final played = homeScore != null;
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
            played ? 'played' : 'scheduled',
          ],
        );
        final result = played ? '$homeScore-$awayScore' : 'vs';
        final penalties = winner == null ? '' : ' ($winner on penalties)';
        print('  Round $round: $home $result $away$penalties');
      }

      _verify(db, tournamentId);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    print(
      'Seeded ${_users.length} users, ${_tournaments.length} tournaments, '
      '${_teams.length} teams and ${_matches.length} matches into $path.',
    );
  } finally {
    database.close();
  }
}

/// Deletes previous seed data; teams, matches, requests, friendships,
/// messages and achievements cascade.
void _clear(Database db) {
  final names = _tournaments.map((tournament) => tournament.name).toList();
  db.execute(
    'DELETE FROM tournaments '
    'WHERE name IN (${List.filled(names.length, '?').join(', ')})',
    names,
  );
  final tournaments = db.updatedRows;
  final emails = _users.map(_email).toList();
  db.execute(
    'DELETE FROM users '
    'WHERE email IN (${List.filled(emails.length, '?').join(', ')}) '
    'OR email LIKE ?',
    [...emails, '%$_legacyEmailDomain'],
  );
  print(
    'Removed $tournaments seed tournaments and ${db.updatedRows} seed users.',
  );
}

int _insertUser(Database db, String username, String hash) {
  db.execute(
    'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)',
    [username, _email(username), hash],
  );
  return db.lastInsertRowId;
}

/// Rereads the inserted rows and throws, rolling everything back, when a
/// count is off.
void _verify(Database db, int tournamentId) {
  int count(String sql, [List<Object?> parameters = const []]) =>
      db.select(sql, parameters).first['n'] as int;

  final emails = _users.map(_email).toList();
  final names = _tournaments.map((tournament) => tournament.name).toList();
  final checks = {
    'users': (
      count(
        'SELECT COUNT(*) AS n FROM users '
        'WHERE email IN (${List.filled(emails.length, '?').join(', ')})',
        emails,
      ),
      _users.length,
    ),
    'tournaments': (
      count(
        'SELECT COUNT(*) AS n FROM tournaments '
        'WHERE name IN (${List.filled(names.length, '?').join(', ')})',
        names,
      ),
      _tournaments.length,
    ),
    'teams': (
      count(
        'SELECT COUNT(*) AS n FROM tournament_teams WHERE tournament_id = ?',
        [tournamentId],
      ),
      _teams.length,
    ),
    'played matches': (
      count(
        "SELECT COUNT(*) AS n FROM tournament_matches "
        "WHERE tournament_id = ? AND status = 'played'",
        [tournamentId],
      ),
      _matches.where((match) => match.$5 != null).length,
    ),
    'scheduled matches': (
      count(
        "SELECT COUNT(*) AS n FROM tournament_matches "
        "WHERE tournament_id = ? AND status = 'scheduled'",
        [tournamentId],
      ),
      _matches.where((match) => match.$5 == null).length,
    ),
  };
  print('Verified:');
  checks.forEach((label, value) {
    final (actual, expected) = value;
    if (actual != expected) {
      throw StateError('Expected $expected $label, found $actual.');
    }
    print('  $label: $actual');
  });
}
