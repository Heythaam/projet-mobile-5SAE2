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
  static const version = 1;

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
    if (oldVersion < 1) {
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
  }
}
