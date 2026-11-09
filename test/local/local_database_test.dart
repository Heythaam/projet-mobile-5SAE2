import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/user_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('upgrading from version 1 adds the match tables and keeps users', () async {
    final dir = await Directory.systemTemp.createTemp('kickoff_local_db_');
    final path = '${dir.path}/upgrade.db';
    addTearDown(() => dir.delete(recursive: true));

    // A phone that still has the version 1 database.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: LocalDatabase.onConfigure,
        onCreate: (db, version) => LocalDatabase.onUpgrade(db, 0, version),
      ),
    );
    final before = await v1.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    expect(before.map((t) => t['name']), ['session', 'users']);
    await UserLocalStore(v1).create(
      uid: 'uid-1',
      username: 'farouk',
      email: 'farouk@example.com',
    );
    await v1.close();

    final v2 = await LocalDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(v2.close);
    final after = await v2.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    expect(after.map((t) => t['name']), [
      'match_players',
      'matches',
      'session',
      'users',
    ]);
    expect((await UserLocalStore(v2).getByUid('uid-1'))?.username, 'farouk');
    final version = await v2.rawQuery('PRAGMA user_version');
    expect(version.first['user_version'], LocalDatabase.version);
  });
}
