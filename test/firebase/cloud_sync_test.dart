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

  @override
  Future<void> pushMatch(LocalMatch match) async => pushed.add(match);

  @override
  Future<void> deleteMatch(String code) async => deleted.add(code);

  @override
  Future<void> pushProfile(LocalUser user) async => profiles.add(user);

  @override
  Future<Map<String, dynamic>?> pullProfile() async => remoteProfile;
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
}
