import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/bd/challenge_database.dart';
import 'package:football_match_app/entities/challenge/challenge_model.dart';
import 'package:football_match_app/services/challenge/challenge_cloud.dart';
import 'package:football_match_app/services/challenge/challenge_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeCloud implements ChallengeCloud {
  final Map<String, CloudChallenge> stored = {};
  final Set<String> cancelledCodes = {};

  @override
  Future<void> push(Challenge challenge, List<int> participants) async {
    stored[challenge.joinCode] = CloudChallenge(challenge, participants);
  }

  @override
  Future<void> cancel(String joinCode) async {
    stored.remove(joinCode);
    cancelledCodes.add(joinCode);
  }

  @override
  Future<CloudChallenges?> pull(int userId) async => CloudChallenges(
    stored.values.toList(),
    cancelledCodes,
  );

  @override
  Future<({CloudChallenge? challenge, bool cancelled})> fetch(
    String joinCode,
  ) async => (
    challenge: stored[joinCode],
    cancelled: cancelledCodes.contains(joinCode),
  );
}

Future<ChallengeDatabase> _freshDb(String name) async {
  await databaseFactoryFfi.deleteDatabase(name);
  final raw = await databaseFactoryFfi.openDatabase(name);
  await raw.execute(
    'CREATE TABLE teams (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color TEXT NOT NULL, icon TEXT NOT NULL)',
  );
  await raw.execute('''
    CREATE TABLE challenges (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      team_id INTEGER,
      description TEXT NOT NULL,
      difficulty INTEGER NOT NULL,
      location_name TEXT NOT NULL,
      date_time TEXT NOT NULL,
      max_players INTEGER NOT NULL,
      current_players INTEGER NOT NULL DEFAULT 1,
      join_code TEXT UNIQUE NOT NULL,
      created_by_user_id INTEGER NOT NULL,
      challenge_status TEXT NOT NULL DEFAULT 'active',
      game_format TEXT DEFAULT '5v5',
      pitch_type TEXT DEFAULT 'Turf',
      skill_level TEXT DEFAULT 'All Levels',
      duration_minutes INTEGER DEFAULT 60,
      rules_notes TEXT
    )
  ''');
  await raw.execute(
    'CREATE TABLE challenge_participants (challenge_id INTEGER NOT NULL, user_id INTEGER NOT NULL, joined_at TEXT NOT NULL, PRIMARY KEY (challenge_id, user_id))',
  );
  return ChallengeDatabase(raw);
}

Challenge _make(int creator, String code) => Challenge(
  type: ChallengeType.open,
  description: 'Friendly',
  difficulty: 3,
  locationName: 'Arena',
  dateTime: DateTime.now().add(const Duration(days: 2)),
  maxPlayers: 10,
  currentPlayers: 1,
  joinCode: code,
  createdByUserId: creator,
);

/// Pushes to the cloud run in the background; give them time to finish.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 300));

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('a challenge made on one phone shows on another', () async {
    final cloud = _FakeCloud();
    final a = SqliteChallengeRepository(await _freshDb('cc_a.db'), cloud);
    final b = SqliteChallengeRepository(await _freshDb('cc_b.db'), cloud);

    await a.createChallenge(_make(1, 'ABC123'));
    await _settle();
    expect(cloud.stored.keys, contains('ABC123'));

    final seen = await b.getBrowseChallenges(2);
    expect(seen.map((c) => c.joinCode), contains('ABC123'));
  });

  test('joining on one phone updates the cloud players', () async {
    final cloud = _FakeCloud();
    final a = SqliteChallengeRepository(await _freshDb('cc_c.db'), cloud);
    final b = SqliteChallengeRepository(await _freshDb('cc_d.db'), cloud);

    await a.createChallenge(_make(1, 'JOIN01'));
    await _settle();
    final seen = (await b.getBrowseChallenges(2)).firstWhere(
      (c) => c.joinCode == 'JOIN01',
    );
    expect(await b.joinChallenge(seen.id!, 2), isTrue);
    await _settle();
    expect(cloud.stored['JOIN01']!.participants, containsAll([1, 2]));
  });

  test('a cancelled challenge cannot be joined and disappears', () async {
    final cloud = _FakeCloud();
    final a = SqliteChallengeRepository(await _freshDb('cc_e.db'), cloud);
    final b = SqliteChallengeRepository(await _freshDb('cc_f.db'), cloud);

    final made = await a.createChallenge(_make(1, 'GONE01'));
    await _settle();
    final seen = (await b.getBrowseChallenges(2)).firstWhere(
      (c) => c.joinCode == 'GONE01',
    );
    expect(await a.deleteChallenge(made.id!, 1), isTrue);
    await _settle();

    expect(await b.joinChallenge(seen.id!, 2), isFalse);
    expect(await b.findByJoinCode('GONE01', 2), isNull);
  });

  test('demo challenges are never sent to the cloud', () async {
    final cloud = _FakeCloud();
    final a = SqliteChallengeRepository(await _freshDb('cc_g.db'), cloud);
    await a.createChallenge(_make(999, 'DEMO01'));
    await _settle();
    expect(cloud.stored, isEmpty);
  });
}
