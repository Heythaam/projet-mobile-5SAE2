import 'dart:io';

import 'package:backend/database.dart';

/// Inserts the test tournaments into the database used by the API.
///
/// Run from `backend/`: `dart run tool/seed_tournaments.dart`.
/// `DB_PATH` overrides the default database, as in `bin/server.dart`.
/// Tournaments that already exist (same name) are skipped, so the script can
/// be run more than once.
const _createdBy = 1;

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
];

void main() {
  final path =
      Platform.environment['DB_PATH'] ?? 'data/football_matches.sqlite';
  final database = AppDatabase(path);
  final db = database.db;
  // The running API holds its own connection; wait for its writes to finish.
  db.execute('PRAGMA busy_timeout = 5000');
  try {
    final creator = db.select('SELECT id FROM users WHERE id = ?', [
      _createdBy,
    ]);
    if (creator.isEmpty) {
      stderr.writeln('User $_createdBy does not exist in $path.');
      exitCode = 1;
      return;
    }

    db.execute('BEGIN IMMEDIATE');
    try {
      for (final tournament in _tournaments) {
        final existing = db.select(
          'SELECT id FROM tournaments WHERE name = ?',
          [tournament.name],
        );
        if (existing.isNotEmpty) {
          print(
            'Skipped "${tournament.name}" (already id ${existing.first['id']}).',
          );
          continue;
        }
        db.execute(
          '''
          INSERT INTO tournaments (
            name, description, format, status, start_date, end_date,
            max_teams, location, created_by
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            _createdBy,
          ],
        );
        print('Inserted "${tournament.name}" as id ${db.lastInsertRowId}.');
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    database.close();
  }
}
