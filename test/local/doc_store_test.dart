import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/doc_store.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late DocStore store;

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = DocStore(db);
  });

  tearDown(() => db.close());

  test('puts, reads, replaces and removes documents', () async {
    await store.put('friends', 'b', {'username': 'bob'});
    await store.put('friends', 'a', {'username': 'ann'});
    expect((await store.list('friends')).map((d) => d['username']), [
      'ann',
      'bob',
    ]);
    expect((await store.get('friends', 'a'))?['username'], 'ann');

    await store.put('friends', 'a', {'username': 'anna'});
    expect((await store.get('friends', 'a'))?['username'], 'anna');

    await store.remove('friends', 'a');
    expect(await store.get('friends', 'a'), isNull);
  });

  test('replaceAll makes a collection hold exactly the new rows', () async {
    await store.put('friends', 'a', {'username': 'ann'});
    await store.put('requests', 'z', {'username': 'zed'});

    await store.replaceAll('friends', {
      'c': {'username': 'cat'},
    });

    expect((await store.list('friends')).single['username'], 'cat');
    expect(await store.list('requests'), hasLength(1));
  });
}
