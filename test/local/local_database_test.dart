import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/bd/local_database.dart';
import 'package:football_match_app/bd/user_local_store.dart';
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
      'docs',
      'match_players',
      'matches',
      'session',
      'users',
    ]);
    expect((await UserLocalStore(v2).getByUid('uid-1'))?.username, 'farouk');
    final version = await v2.rawQuery('PRAGMA user_version');
    expect(version.first['user_version'], LocalDatabase.version);
  });

  test('upgrading from version 2 adds booking_id and keeps matches', () async {
    final dir = await Directory.systemTemp.createTemp('kickoff_local_db_');
    final path = '${dir.path}/upgrade2.db';
    addTearDown(() => dir.delete(recursive: true));

    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: LocalDatabase.onConfigure,
        onCreate: (db, version) => LocalDatabase.onUpgrade(db, 0, version),
      ),
    );
    await v2.insert('matches', {
      'code': 'ABCDE',
      'host_uid': 'host',
      'stadium': 'Green Arena',
      'scheduled_at': 1,
      'capacity': 10,
      'is_public': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    await v2.close();

    final v3 = await LocalDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(v3.close);
    final rows = await v3.query('matches');
    expect(rows.single['code'], 'ABCDE');
    expect(rows.single['booking_id'], isNull);
  });

  test('upgrading from version 3 adds country and photo to users', () async {
    final dir = await Directory.systemTemp.createTemp('kickoff_local_db_');
    final path = '${dir.path}/upgrade3.db';
    addTearDown(() => dir.delete(recursive: true));

    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: LocalDatabase.onConfigure,
        onCreate: (db, version) => LocalDatabase.onUpgrade(db, 0, version),
      ),
    );
    await UserLocalStore(v3).create(
      uid: 'uid-1',
      username: 'farouk',
      email: 'farouk@example.com',
    );
    await v3.close();

    final v4 = await LocalDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(v4.close);
    final user = await UserLocalStore(v4).getByUid('uid-1');
    expect(user?.username, 'farouk');
    expect(user?.country, isNull);
    expect(user?.photoPath, isNull);
  });
}
