import 'dart:io';

/// The database the API and the seed script use: `DB_PATH` when set,
/// otherwise `backend/data/football_matches.sqlite`, found from the running
/// script's own location so the working directory does not matter.
///
/// A compiled executable (`dart build cli`) has no script beside the backend
/// folder to start from, so it needs `DB_PATH`; null means it is missing.
String? databasePath() {
  final override = Platform.environment['DB_PATH'];
  if (override != null && override.isNotEmpty) return override;
  if (!Platform.script.path.endsWith('.dart')) return null;
  return Platform.script
      .resolve('../data/football_matches.sqlite')
      .toFilePath();
}

/// Shown when [databasePath] returns null.
const databasePathMissing =
    'Set DB_PATH to the database file when running a compiled executable.';
