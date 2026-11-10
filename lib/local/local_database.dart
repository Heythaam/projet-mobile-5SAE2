import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the phone-side SQFlite database.
///
/// It holds the signed-in user's profile and a single session row. Credentials
/// live in Firebase Auth and are never stored here. XP, level and streak are
/// not stored here either: rewards must come from persisted server events.
class LocalDatabase {
  const LocalDatabase._();

  static const fileName = 'kickoff_local.db';

  /// Bump this and add an `if (oldVersion < N)` step in [onUpgrade] whenever
  /// the schema changes.
  static const version = 5;

  /// [factory] and [path] exist so tests can open an in-memory database.
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: onConfigure,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      ),
    );
  }

  static Future<void> onConfigure(Database db) =>
      db.execute('PRAGMA foreign_keys = ON');

  static Future<void> onCreate(Database db, int version) =>
      onUpgrade(db, 0, version);

  /// Runs each missing migration step in order, so a new install and an
  /// upgrade end with the same schema.
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1 && newVersion >= 1) {
      await db.execute('''
        CREATE TABLE users(
          uid        TEXT PRIMARY KEY,
          username   TEXT NOT NULL UNIQUE COLLATE NOCASE,
          email      TEXT NOT NULL COLLATE NOCASE,
          bio        TEXT NOT NULL DEFAULT '',
          position   TEXT CHECK (position IN ('GK', 'DEF', 'MID', 'FWD')),
          avatar_id  INTEGER NOT NULL DEFAULT 0 CHECK (avatar_id >= 0),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE session(
          id           INTEGER PRIMARY KEY CHECK (id = 1),
          uid          TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
          signed_in_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute('''
        CREATE TABLE matches(
          code         TEXT PRIMARY KEY COLLATE NOCASE,
          host_uid     TEXT NOT NULL,
          stadium      TEXT NOT NULL,
          scheduled_at INTEGER NOT NULL,
          capacity     INTEGER NOT NULL CHECK (capacity BETWEEN 2 AND 30),
          is_public    INTEGER NOT NULL DEFAULT 0 CHECK (is_public IN (0, 1)),
          latitude     REAL CHECK (latitude BETWEEN -90 AND 90),
          longitude    REAL CHECK (longitude BETWEEN -180 AND 180),
          created_at   INTEGER NOT NULL,
          updated_at   INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE match_players(
          match_code TEXT NOT NULL REFERENCES matches(code) ON DELETE CASCADE,
          uid        TEXT NOT NULL,
          slot       INTEGER NOT NULL CHECK (slot >= 0),
          display_name TEXT NOT NULL DEFAULT '',
          joined_at  INTEGER NOT NULL,
          PRIMARY KEY (match_code, uid),
          UNIQUE (match_code, slot)
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_matches_public_time ON matches(is_public, scheduled_at)',
      );
    }
    if (oldVersion < 3 && newVersion >= 3) {
      // The Stadium module's booking for this match, when the match was made
      // in a real stadium. Lets the host release the slot on cancel.
      await db.execute('ALTER TABLE matches ADD COLUMN booking_id INTEGER');
    }
    if (oldVersion < 4 && newVersion >= 4) {
      // Two-letter country code (ISO 3166) and the path of a profile photo
      // kept in the app's own folder.
      await db.execute('ALTER TABLE users ADD COLUMN country TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN photo_path TEXT');
    }
    if (oldVersion < 5 && newVersion >= 5) {
      // Phone copy of what modules read from Firestore (friends, chats,
      // challenges, tournaments...), as JSON documents in collections.
      await db.execute('''
        CREATE TABLE docs(
          collection TEXT NOT NULL,
          id         TEXT NOT NULL,
          json       TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (collection, id)
        )
      ''');
    }
  }
}
