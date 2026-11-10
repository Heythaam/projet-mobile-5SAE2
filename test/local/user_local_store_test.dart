import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/user_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher throwsLocal(LocalUserError error) => throwsA(
  isA<LocalUserException>().having((e) => e.error, 'error', error),
);

void main() {
  sqfliteFfiInit();

  late Database db;
  late UserLocalStore store;
  late DateTime now;

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime.utc(2026, 11, 9, 12);
    store = UserLocalStore(db, clock: () => now);
  });

  tearDown(() => db.close());

  Future<LocalUser> seed({
    String uid = 'uid-1',
    String username = 'farouk',
    String email = 'farouk@example.com',
  }) => store.create(uid: uid, username: username, email: email);

  group('schema', () {
    test('onCreate builds the current version with foreign keys on', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      expect(tables.map((t) => t['name']), [
        'docs',
        'match_players',
        'matches',
        'session',
        'users',
      ]);

      final version = await db.rawQuery('PRAGMA user_version');
      expect(version.first['user_version'], LocalDatabase.version);

      final fk = await db.rawQuery('PRAGMA foreign_keys');
      expect(fk.first['foreign_keys'], 1);
    });
  });

  group('create and read', () {
    test('stores a normalized profile', () async {
      final user = await store.create(
        uid: 'uid-1',
        username: '  Farouk_10 ',
        email: ' Farouk@Example.COM ',
        bio: '  Striker  ',
        position: 'FWD',
        avatarId: 3,
      );
      expect(user.username, 'farouk_10');
      expect(user.email, 'farouk@example.com');
      expect(user.bio, 'Striker');
      expect(user.position, 'FWD');
      expect(user.avatarId, 3);
      expect(user.createdAt, now);
      expect(user.updatedAt, now);
    });

    test('reads by uid and by username, ignoring case', () async {
      await seed();
      expect((await store.getByUid('uid-1'))?.username, 'farouk');
      expect((await store.getByUsername('FAROUK'))?.uid, 'uid-1');
      expect(await store.getByUid('missing'), isNull);
      expect(await store.getByUsername('nobody'), isNull);
    });

    test('rejects invalid input', () async {
      await expectLater(
        store.create(uid: '', username: 'farouk', email: 'a@b.co'),
        throwsLocal(LocalUserError.invalidUid),
      );
      for (final name in ['ab', 'has space', 'a' * 21, 'bad-char']) {
        await expectLater(
          store.create(uid: 'u', username: name, email: 'a@b.co'),
          throwsLocal(LocalUserError.invalidUsername),
        );
      }
      await expectLater(
        store.create(uid: 'u', username: 'farouk', email: 'not-an-email'),
        throwsLocal(LocalUserError.invalidEmail),
      );
      await expectLater(
        store.create(
          uid: 'u',
          username: 'farouk',
          email: 'a@b.co',
          position: 'STRIKER',
        ),
        throwsLocal(LocalUserError.invalidPosition),
      );
      await expectLater(
        store.create(
          uid: 'u',
          username: 'farouk',
          email: 'a@b.co',
          bio: 'x' * 161,
        ),
        throwsLocal(LocalUserError.invalidBio),
      );
      await expectLater(
        store.create(
          uid: 'u',
          username: 'farouk',
          email: 'a@b.co',
          avatarId: -1,
        ),
        throwsLocal(LocalUserError.invalidAvatar),
      );
    });

    test('rejects a duplicate username (any case) and a duplicate uid', () async {
      await seed();
      await expectLater(
        store.create(uid: 'uid-2', username: 'FAROUK', email: 'b@b.co'),
        throwsLocal(LocalUserError.usernameTaken),
      );
      await expectLater(
        store.create(uid: 'uid-1', username: 'other', email: 'b@b.co'),
        throwsLocal(LocalUserError.uidTaken),
      );
    });
  });

  group('update', () {
    test('changes only the given fields and bumps updated_at', () async {
      await seed();
      now = now.add(const Duration(minutes: 5));
      final user = await store.updateProfile(
        'uid-1',
        bio: 'Left winger',
        position: 'MID',
        avatarId: 2,
      );
      expect(user.username, 'farouk');
      expect(user.bio, 'Left winger');
      expect(user.position, 'MID');
      expect(user.avatarId, 2);
      expect(user.createdAt, DateTime.utc(2026, 11, 9, 12));
      expect(user.updatedAt, now);
    });

    test('updated_at always moves forward, even if the clock does not', () async {
      final created = await seed();
      final first = await store.updateProfile('uid-1', bio: 'one');
      final second = await store.updateProfile('uid-1', bio: 'two');
      expect(first.updatedAt.isAfter(created.updatedAt), isTrue);
      expect(second.updatedAt.isAfter(first.updatedAt), isTrue);
    });

    test('a change that changes nothing does not bump updated_at', () async {
      final created = await seed();
      final same = await store.updateProfile('uid-1', username: 'farouk');
      expect(same.updatedAt, created.updatedAt);
    });

    test('clearPosition removes the position', () async {
      await seed();
      await store.updateProfile('uid-1', position: 'GK');
      final cleared = await store.updateProfile('uid-1', clearPosition: true);
      expect(cleared.position, isNull);
    });

    test('renaming checks uniqueness against other users only', () async {
      await seed();
      await seed(uid: 'uid-2', username: 'zed', email: 'z@z.co');
      await expectLater(
        store.updateProfile('uid-2', username: 'Farouk'),
        throwsLocal(LocalUserError.usernameTaken),
      );
      final renamed = await store.updateProfile('uid-2', username: 'zed_2');
      expect(renamed.username, 'zed_2');
    });

    test('unknown user fails', () async {
      await expectLater(
        store.updateProfile('missing', bio: 'x'),
        throwsLocal(LocalUserError.notFound),
      );
    });
  });

  group('search', () {
    Future<void> add(String uid, String name, {String bio = ''}) async {
      await store.create(
        uid: uid,
        username: name,
        email: '$name@example.com',
        bio: bio,
      );
    }

    test('lists everyone A to Z and counts them', () async {
      await add('3', 'sami');
      await add('1', 'Amine');
      await add('2', 'farouk');
      expect((await store.search('')).map((u) => u.username), [
        'amine',
        'farouk',
        'sami',
      ]);
      expect(await store.count(), 3);
    });

    test('matches part of the username or bio, ignoring case', () async {
      await add('1', 'farouk', bio: 'Left winger');
      await add('2', 'sami', bio: 'Goalkeeper');
      await add('3', 'amine');
      expect((await store.search('FAR')).map((u) => u.username), ['farouk']);
      expect((await store.search('keeper')).map((u) => u.username), ['sami']);
      expect((await store.search(' mi ')).map((u) => u.username), [
        'amine',
        'sami',
      ]);
      expect(await store.search('zzz'), isEmpty);
    });

    test('treats % and _ as plain characters', () async {
      await add('1', 'a_b');
      await add('2', 'axb');
      expect((await store.search('a_b')).map((u) => u.username), ['a_b']);
      expect(await store.search('%'), isEmpty);
    });

    test('respects the limit', () async {
      for (var i = 0; i < 5; i++) {
        await add('$i', 'user$i');
      }
      expect(await store.search('', limit: 3), hasLength(3));
    });
  });

  group('country and photo', () {
    test('saves, changes and clears the country', () async {
      await seed();
      var user = await store.updateProfile('uid-1', country: 'tn');
      expect(user.country, 'TN');
      user = await store.updateProfile('uid-1', country: 'FR');
      expect(user.country, 'FR');
      user = await store.updateProfile('uid-1', bio: 'hi');
      expect(user.country, 'FR');
      user = await store.updateProfile('uid-1', clearCountry: true);
      expect(user.country, isNull);
    });

    test('rejects a country that is not two letters', () async {
      await seed();
      for (final bad in ['T', 'TUN', 'T1', '']) {
        await expectLater(
          store.updateProfile('uid-1', country: bad),
          throwsA(
            isA<LocalUserException>().having(
              (e) => e.error,
              'error',
              LocalUserError.invalidCountry,
            ),
          ),
        );
      }
    });

    test('saves and clears the photo path', () async {
      await seed();
      var user = await store.updateProfile('uid-1', photoPath: '/app/p.jpg');
      expect(user.photoPath, '/app/p.jpg');
      user = await store.updateProfile('uid-1', clearPhoto: true);
      expect(user.photoPath, isNull);
      await expectLater(
        store.updateProfile('uid-1', photoPath: '  '),
        throwsA(
          isA<LocalUserException>().having(
            (e) => e.error,
            'error',
            LocalUserError.invalidPhoto,
          ),
        ),
      );
    });
  });

  group('delete and session', () {
    test('session tracks the signed-in user', () async {
      await seed();
      expect(await store.currentUser(), isNull);
      await store.startSession('uid-1');
      expect((await store.currentUser())?.uid, 'uid-1');
      await store.endSession();
      expect(await store.currentUser(), isNull);
    });

    test('starting a session replaces the previous one', () async {
      await seed();
      await seed(uid: 'uid-2', username: 'zed', email: 'z@z.co');
      await store.startSession('uid-1');
      await store.startSession('uid-2');
      expect((await store.currentUser())?.uid, 'uid-2');
      expect(await db.query('session'), hasLength(1));
    });

    test('session needs a stored user', () async {
      await expectLater(
        store.startSession('missing'),
        throwsLocal(LocalUserError.notFound),
      );
    });

    test('delete removes the user and clears the session', () async {
      await seed();
      await store.startSession('uid-1');
      expect(await store.delete('uid-1'), isTrue);
      expect(await store.getByUid('uid-1'), isNull);
      expect(await store.currentUser(), isNull);
      expect(await db.query('session'), isEmpty);
      expect(await store.delete('uid-1'), isFalse);
    });
  });
}
