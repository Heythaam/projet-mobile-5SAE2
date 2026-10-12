import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase(String path) {
    File(path).parent.createSync(recursive: true);
    db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        xp INTEGER NOT NULL DEFAULT 0,
        current_streak INTEGER NOT NULL DEFAULT 0,
        best_streak INTEGER NOT NULL DEFAULT 0,
        last_active_on TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    final userColumns = db.select('PRAGMA table_info(users)');
    final columnNames = userColumns.map((row) => row['name']).toSet();
    if (!columnNames.contains('xp')) {
      db.execute('ALTER TABLE users ADD COLUMN xp INTEGER NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('current_streak')) {
      db.execute(
        'ALTER TABLE users ADD COLUMN current_streak INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columnNames.contains('best_streak')) {
      db.execute(
        'ALTER TABLE users ADD COLUMN best_streak INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columnNames.contains('last_active_on')) {
      db.execute('ALTER TABLE users ADD COLUMN last_active_on TEXT');
    }
    db.execute('''
      CREATE TABLE IF NOT EXISTS friendships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        requester_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        addressee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (requester_id != addressee_id),
        UNIQUE (requester_id, addressee_id)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        sent_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (sender_id != recipient_id)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS user_achievements (
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        code TEXT NOT NULL,
        unlocked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, code)
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS messages_conversation_idx
      ON messages(sender_id, recipient_id, id)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS tournaments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        format TEXT NOT NULL CHECK (
          format IN ('knockout', 'league', 'groups_knockout', 'round_robin')
        ),
        status TEXT NOT NULL DEFAULT 'upcoming' CHECK (
          status IN ('upcoming', 'active', 'finished', 'cancelled')
        ),
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        max_teams INTEGER NOT NULL CHECK (max_teams >= 2),
        location TEXT NOT NULL DEFAULT '',
        prize TEXT,
        created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CHECK (end_date >= start_date)
      )
    ''');
    db.execute(_tournamentTeamsTable('tournament_teams'));
    // Knockout rows may leave a team open (TBD) or give a bye; group rows
    // always name both teams.
    db.execute(_tournamentMatchesTable('tournament_matches'));
    _rebuildIfMissing(
      table: 'tournament_matches',
      marker: "'bye'",
      createSql: _tournamentMatchesTable('tournament_matches_new'),
      copiedColumns:
          'id, tournament_id, home_team_id, away_team_id, round, '
          'home_score, away_score, scheduled_at, status',
    );
    db.execute('''
      CREATE INDEX IF NOT EXISTS tournament_matches_tournament_idx
      ON tournament_matches(tournament_id, status)
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS tournament_matches_slot_idx
      ON tournament_matches(tournament_id, stage, round, bracket_position)
      WHERE bracket_position IS NOT NULL
    ''');
    final teamColumns = db
        .select('PRAGMA table_info(tournament_teams)')
        .map((row) => row['name'])
        .toSet();
    if (!teamColumns.contains('group_label')) {
      // Group of a groups + knockout tournament ("A", "B", ...).
      db.execute('ALTER TABLE tournament_teams ADD COLUMN group_label TEXT');
    }
    // Teams that leave keep their row with a status and `left_at`, so the
    // older inline UNIQUE (tournament_id, captain_id) gives way to partial
    // indexes over active teams.
    _rebuildIfMissing(
      table: 'tournament_teams',
      marker: "'disbanded'",
      createSql: _tournamentTeamsTable('tournament_teams_new'),
      copiedColumns:
          'id, tournament_id, captain_id, name, joined_at, group_label',
    );
    db.execute('DROP INDEX IF EXISTS tournament_teams_name_idx');
    // Active teams have distinct names and one captain team per user.
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS tournament_teams_active_name_idx
      ON tournament_teams(tournament_id, name COLLATE NOCASE)
      WHERE status = 'active'
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS tournament_teams_active_captain_idx
      ON tournament_teams(tournament_id, captain_id)
      WHERE status = 'active'
    ''');
    // Players per team, captain included.
    final tournamentColumns = db
        .select('PRAGMA table_info(tournaments)')
        .map((row) => row['name'])
        .toSet();
    if (!tournamentColumns.contains('team_size')) {
      db.execute(
        'ALTER TABLE tournaments ADD COLUMN team_size INTEGER NOT NULL '
        'DEFAULT 5 CHECK (team_size >= 1)',
      );
    }
    // An accepted request makes the requester a player of that team; a
    // captain removing them marks it `removed`, a player leaving `left`, a
    // player made captain `promoted`, and disbanding the team `disbanded`
    // (with `notice_seen_at` once the player has seen that news).
    db.execute(_joinRequestsTable('join_requests'));
    _rebuildIfMissing(
      table: 'join_requests',
      marker: "'disbanded'",
      createSql: _joinRequestsTable('join_requests_new'),
      copiedColumns:
          'id, tournament_id, team_id, requester_id, status, created_at, '
          'responded_at',
    );
    // One live request or team membership per user and tournament.
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS join_requests_active_idx
      ON join_requests(tournament_id, requester_id)
      WHERE status IN ('pending', 'accepted')
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS join_requests_team_idx
      ON join_requests(team_id, status)
    ''');
  }

  late final Database db;

  void close() => db.close();

  /// SQLite cannot change NOT NULL, CHECK or inline UNIQUE constraints, so a
  /// table whose schema lacks [marker] is copied into one created by
  /// [createSql]. Foreign keys are off meanwhile, so dropping a referenced
  /// table does not cascade into its children; they are checked before the
  /// commit. Indexes are recreated afterwards.
  void _rebuildIfMissing({
    required String table,
    required String marker,
    required String createSql,
    required String copiedColumns,
  }) {
    final sql =
        db.select('SELECT sql FROM sqlite_master WHERE name = ?', [
              table,
            ]).first['sql']
            as String;
    if (sql.contains(marker)) return;
    db.execute('PRAGMA foreign_keys = OFF');
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(createSql);
      db.execute('''
        INSERT INTO ${table}_new ($copiedColumns)
        SELECT $copiedColumns FROM $table
      ''');
      db.execute('DROP TABLE $table');
      db.execute('ALTER TABLE ${table}_new RENAME TO $table');
      if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw StateError('Rebuilding $table broke a foreign key.');
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      db.execute('PRAGMA foreign_keys = ON');
    }
  }

  /// A team that leaves is kept with status `left` (or `disbanded` when it
  /// had players) and the time it left.
  static String _tournamentTeamsTable(String name) =>
      '''
    CREATE TABLE IF NOT EXISTS $name (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tournament_id INTEGER NOT NULL
        REFERENCES tournaments(id) ON DELETE CASCADE,
      captain_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      group_label TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK (
        status IN ('active', 'left', 'disbanded')
      ),
      left_at TEXT,
      CHECK ((status = 'active') = (left_at IS NULL))
    )
  ''';

  static String _tournamentMatchesTable(String name) =>
      '''
    CREATE TABLE IF NOT EXISTS $name (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tournament_id INTEGER NOT NULL
        REFERENCES tournaments(id) ON DELETE CASCADE,
      home_team_id INTEGER REFERENCES tournament_teams(id) ON DELETE CASCADE,
      away_team_id INTEGER REFERENCES tournament_teams(id) ON DELETE CASCADE,
      stage TEXT NOT NULL DEFAULT 'group' CHECK (stage IN ('group', 'knockout')),
      round INTEGER NOT NULL DEFAULT 1 CHECK (round >= 1),
      bracket_position INTEGER CHECK (bracket_position >= 1),
      home_score INTEGER CHECK (home_score >= 0),
      away_score INTEGER CHECK (away_score >= 0),
      winner_team_id INTEGER
        REFERENCES tournament_teams(id) ON DELETE SET NULL,
      scheduled_at TEXT,
      status TEXT NOT NULL DEFAULT 'scheduled' CHECK (
        status IN ('scheduled', 'played', 'cancelled', 'bye')
      ),
      CHECK (home_team_id IS NULL OR away_team_id IS NULL
        OR home_team_id != away_team_id),
      CHECK (stage = 'knockout'
        OR (home_team_id IS NOT NULL AND away_team_id IS NOT NULL)),
      CHECK (status != 'played' OR (home_team_id IS NOT NULL
        AND away_team_id IS NOT NULL AND home_score IS NOT NULL
        AND away_score IS NOT NULL)),
      CHECK (status != 'bye' OR (stage = 'knockout'
        AND home_team_id IS NOT NULL AND away_team_id IS NULL)),
      CHECK (winner_team_id IS NULL
        OR winner_team_id IN (home_team_id, away_team_id))
    )
  ''';

  static String _joinRequestsTable(String name) =>
      '''
    CREATE TABLE IF NOT EXISTS $name (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tournament_id INTEGER NOT NULL
        REFERENCES tournaments(id) ON DELETE CASCADE,
      team_id INTEGER NOT NULL
        REFERENCES tournament_teams(id) ON DELETE CASCADE,
      requester_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'accepted', 'declined', 'cancelled', 'removed',
          'left', 'promoted', 'disbanded')
      ),
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      responded_at TEXT,
      notice_seen_at TEXT
    )
  ''';
}
