import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/firebase/cloud_sync.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/match_local_store.dart';
import 'package:football_match_app/local/user_local_store.dart';
import 'package:football_match_app/matches/match_controller.dart';
import 'package:football_match_app/screens/match/match_mock_data.dart';
import 'package:football_match_app/users/user_profile_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeCloud extends NoopCloudSync {
  final pushed = <LocalMatch>[];
  final deleted = <String>[];
  final profiles = <LocalUser>[];
  Map<String, dynamic>? remoteProfile;

  /// What other phones saved: matches, and codes that were cancelled.
  final remoteMatches = <LocalMatch>[];
  final remoteCancelled = <String>{};
  bool offline = false;

  @override
  Future<void> pushMatch(LocalMatch match) async => pushed.add(match);

  @override
  Future<void> deleteMatch(String code) async => deleted.add(code);

  @override
  Future<void> pushProfile(LocalUser user) async => profiles.add(user);

  @override
  Future<Map<String, dynamic>?> pullProfile() async => remoteProfile;

  @override
  Future<CloudMatches?> pullMatches(String uid) async => offline
      ? null
      : CloudMatches(
          [
            for (final m in remoteMatches)
              if (m.isPublic || m.hasPlayer(uid)) m,
          ],
          {...remoteCancelled},
        );

  @override
  Future<({LocalMatch? match, bool cancelled})> fetchMatch(String code) async {
    if (offline) return (match: null, cancelled: false);
    if (remoteCancelled.contains(code)) return (match: null, cancelled: true);
    final found = remoteMatches.where((m) => m.code == code);
    return (match: found.isEmpty ? null : found.first, cancelled: false);
  }
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late _FakeCloud cloud;

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    cloud = _FakeCloud();
  });

  tearDown(() => db.close());

  MatchController matches(String uid) => MatchController(
    uid: uid,
    username: 'P$uid',
    openStore: () async => MatchLocalStore(db),
    cloud: cloud,
  );

  CreateMatchDraft draft() => CreateMatchDraft(
    stadium: matchStadiums.first,
    startsAt: DateTime.now().add(const Duration(hours: 24)),
    visibility: 'Public',
  );

  test('matches are copied to the cloud and removed on cancel', () async {
    final host = matches('1');
    await host.load();
    final created = await host.createMatch(draft());
    expect(cloud.pushed.map((m) => m.code), [created.code]);

    expect(await host.setPublic(created.code, isPublic: false), isTrue);
    expect(cloud.pushed.last.isPublic, isFalse);

    final guest = matches('2');
    await guest.load();
    await guest.joinByCode(created.code);
    expect(cloud.pushed.last.players, 2);

    await guest.leaveMatch(created.code);
    expect(cloud.pushed.last.players, 1);

    expect(await host.cancelMatch(created.code), isTrue);
    expect(cloud.deleted, [created.code]);
  });

  test('saving the profile copies it to the cloud', () async {
    final controller = UserProfileController(
      uid: '7',
      accountUsername: 'farouk',
      email: 'f@example.com',
      openStore: () async => UserLocalStore(db),
      cloud: cloud,
    );
    await controller.load();
    expect(await controller.save(bio: 'Striker'), isTrue);
    expect(cloud.profiles.single.bio, 'Striker');
  });

  test('a new phone restores the profile from the cloud copy', () async {
    cloud.remoteProfile = {
      'bio': 'Left foot only',
      'position': 'MID',
      'avatarId': 3,
      'country': 'TN',
    };
    final controller = UserProfileController(
      uid: 'firebase-uid',
      accountUsername: 'farouk',
      email: 'f@example.com',
      openStore: () async => UserLocalStore(db),
      cloud: cloud,
    );
    await controller.load();

    expect(controller.profile?.bio, 'Left foot only');
    expect(controller.profile?.position, 'MID');
    expect(controller.profile?.avatarId, 3);
    expect(controller.profile?.country, 'TN');
  });

  test('without a cloud copy the profile starts from the account', () async {
    final controller = UserProfileController(
      uid: 'firebase-uid',
      accountUsername: 'farouk',
      email: 'f@example.com',
      openStore: () async => UserLocalStore(db),
      cloud: cloud,
    );
    await controller.load();

    expect(controller.profile?.username, 'farouk');
    expect(controller.profile?.bio, '');
  });

  LocalMatch cloudMatch(
    String code, {
    String host = 'other',
    List<String?>? slots,
    bool isPublic = true,
    int hoursAhead = 24,
  }) {
    final at = DateTime.now().toUtc().add(Duration(hours: hoursAhead));
    final list = slots ?? [host, null, null, null];
    return LocalMatch(
      code: code,
      hostUid: host,
      stadium: 'Camp Nou',
      scheduledAt: at,
      capacity: list.length,
      isPublic: isPublic,
      slots: list,
      slotNames: [for (final s in list) s == null ? null : 'Name $s'],
      createdAt: at,
      updatedAt: at,
    );
  }

  test('public matches made on another phone show up after load', () async {
    cloud.remoteMatches.add(cloudMatch('ABCDE'));
    final controller = matches('me');
    await controller.load();

    expect(controller.publicMatches.map((m) => m.match.code), ['ABCDE']);
    expect(controller.publicMatches.single.match.stadium, 'Camp Nou');
  });

  test('a match made offline is sent to the cloud on the next load', () async {
    cloud.offline = true;
    final host = matches('me');
    await host.load();
    final created = await host.createMatch(draft());
    cloud.pushed.clear();

    cloud.offline = false;
    final again = matches('me');
    await again.load();
    await Future<void>.delayed(Duration.zero);

    expect(cloud.pushed.map((m) => m.code), [created.code]);
  });

  test('joining a match that only exists in the cloud works', () async {
    cloud.remoteMatches.add(cloudMatch('JOIN2', isPublic: false));
    final controller = matches('me');
    await controller.load();
    expect(controller.findMatchByCode('JOIN2'), isNull);

    final joined = await controller.joinByCode('JOIN2');

    expect(joined?.code, 'JOIN2');
    expect(controller.hasJoined(joined!), isTrue);
    expect(cloud.pushed.single.slots.contains('me'), isTrue);
  });

  test('a match the host cancelled elsewhere disappears and cannot be joined',
      () async {
    final mine = cloudMatch('GONE2', slots: ['other', 'me', null, null]);
    cloud.remoteMatches.add(mine);
    final controller = matches('me');
    await controller.load();
    expect(controller.upcomingMatch?.code, 'GONE2');

    cloud.remoteMatches.clear();
    cloud.remoteCancelled.add('GONE2');
    final later = matches('me');
    await later.load();
    expect(later.upcomingMatch, isNull);

    expect(await later.joinByCode('GONE2'), isNull);
    expect(later.lastError, 'That match was cancelled.');
  });

  test('cloud matches replace the phone copy but keep a stadium booking',
      () async {
    final store = MatchLocalStore(db);
    await store.upsertFromCloud(cloudMatch('KEEP2'));
    await store.upsertFromCloud(
      cloudMatch('KEEP2', slots: ['other', 'me', null, null]),
    );

    final saved = await store.getByCode('KEEP2');
    expect(saved?.slots, ['other', 'me', null, null]);
    expect(saved?.slotNames[1], 'Name me');

    await store.removeLocal('keep2');
    expect(await store.getByCode('KEEP2'), isNull);
  });
}
