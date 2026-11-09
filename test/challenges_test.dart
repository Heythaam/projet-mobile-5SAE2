import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/challenges/database/challenge_database.dart';
import 'package:football_match_app/challenges/models/challenge_model.dart';
import 'package:football_match_app/challenges/repository/challenge_repository.dart';
import 'package:football_match_app/challenges/screens/challenges_dashboard_screen.dart';
import 'package:football_match_app/challenges/widgets/challenge_card.dart';
import 'package:football_match_app/challenges/widgets/star_rating.dart';
import 'package:football_match_app/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _testUser = UserAccount(
  id: 42,
  username: 'testplayer',
  email: 'test@kickoff.local',
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Challenge Models', () {
    test('Challenge serialization and helpers', () {
      final now = DateTime.now();
      final challenge = Challenge(
        id: 1,
        type: ChallengeType.open,
        description: 'Test Challenge',
        difficulty: 4,
        locationName: 'Central Arena',
        dateTime: now,
        maxPlayers: 10,
        currentPlayers: 5,
        joinCode: 'KICK99',
        createdByUserId: 42,
      );

      expect(challenge.isFull, isFalse);
      expect(challenge.isTeamChallenge, isFalse);

      final map = challenge.toMap();
      final restored = Challenge.fromMap(map, currentUserId: 42);

      expect(restored.id, equals(1));
      expect(restored.description, equals('Test Challenge'));
      expect(restored.difficulty, equals(4));
      expect(restored.joinCode, equals('KICK99'));
      expect(restored.isCreatedByMe, isTrue);
    });
  });

  group('Challenge Database & Repository Operations', () {
    late ChallengeDatabase db;
    late SqliteChallengeRepository repository;
    int testCount = 0;

    setUp(() async {
      testCount++;
      final dbName = 'test_db_$testCount.db';
      final inMemoryDb = await databaseFactoryFfi.openDatabase(dbName);
      db = ChallengeDatabase(inMemoryDb);

      await inMemoryDb.execute('''
        CREATE TABLE teams (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          color TEXT NOT NULL,
          icon TEXT NOT NULL
        )
      ''');
      await inMemoryDb.execute('''
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
          challenge_status TEXT NOT NULL DEFAULT 'active'
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE challenge_participants (
          challenge_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          joined_at TEXT NOT NULL,
          PRIMARY KEY (challenge_id, user_id)
        )
      ''');

      await inMemoryDb.insert('teams', {
        'name': 'Thunder FC',
        'color': '#0B5FE8',
        'icon': 'flash_on',
      });

      repository = SqliteChallengeRepository(db);
    });

    test('Generates unique join codes starting with KICK', () async {
      final code1 = await repository.generateUniqueJoinCode();
      final code2 = await repository.generateUniqueJoinCode();

      expect(code1.startsWith('KICK'), isTrue);
      expect(code2.startsWith('KICK'), isTrue);
      expect(code1.length, equals(6));
    });

    test('Creates challenge and retrieves it under created challenges', () async {
      final challenge = Challenge(
        type: ChallengeType.open,
        description: 'Sunday Cup Match',
        difficulty: 3,
        locationName: 'North Pitch',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        maxPlayers: 10,
        joinCode: 'KICK88',
        createdByUserId: 42,
      );

      final created = await repository.createChallenge(challenge);
      expect(created.id, isNotNull);

      final createdList = await repository.getCreatedChallenges(42);
      expect(createdList.length, equals(1));
      expect(createdList.first.description, equals('Sunday Cup Match'));
    });

    test('User can join browse challenge by ID and Code', () async {
      final challenge = Challenge(
        type: ChallengeType.open,
        description: 'Open Challenge 1',
        difficulty: 2,
        locationName: 'Park Field',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        maxPlayers: 10,
        joinCode: 'KICK42',
        createdByUserId: 100,
      );

      final created = await repository.createChallenge(challenge);

      final found = await repository.findByJoinCode('KICK42', 42);
      expect(found, isNotNull);
      expect(found!.id, equals(created.id));

      final joined = await repository.joinChallenge(created.id!, 42);
      expect(joined, isTrue);

      final userJoinedList = await repository.getJoinedChallenges(42);
      expect(userJoinedList.length, equals(1));
      expect(userJoinedList.first.id, equals(created.id));
    });
  });

  group('Challenge UI Widgets', () {
    testWidgets('StarRating renders correct number of filled stars', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(rating: 3),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('ChallengeCard displays challenge details and handles copy code', (
      WidgetTester tester,
    ) async {
      bool copied = false;

      final challenge = Challenge(
        id: 1,
        type: ChallengeType.open,
        description: 'Evening Friendly Match',
        difficulty: 4,
        locationName: 'Arena Stadium',
        dateTime: DateTime(2025, 10, 15, 18, 0),
        maxPlayers: 10,
        currentPlayers: 4,
        joinCode: 'KICK55',
        createdByUserId: 99,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(
              challenge: challenge,
              onCopyCode: () => copied = true,
              onJoin: () {},
            ),
          ),
        ),
      );

      expect(find.text('Evening Friendly Match'), findsOneWidget);
      expect(find.text('Arena Stadium'), findsOneWidget);
      expect(find.text('KICK55'), findsOneWidget);

      await tester.tap(find.text('KICK55'));
      expect(copied, isTrue);
    });

    testWidgets('ChallengesDashboardScreen switches tabs', (
      WidgetTester tester,
    ) async {
      final inMemoryDb = await databaseFactoryFfi.openDatabase('widget_db_1.db');
      await inMemoryDb.execute('''
        CREATE TABLE teams (id INTEGER PRIMARY KEY, name TEXT, color TEXT, icon TEXT);
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE challenges (id INTEGER PRIMARY KEY, type TEXT, team_id INTEGER, description TEXT, difficulty INTEGER, location_name TEXT, date_time TEXT, max_players INTEGER, current_players INTEGER, join_code TEXT UNIQUE, created_by_user_id INTEGER, challenge_status TEXT);
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE challenge_participants (challenge_id INTEGER, user_id INTEGER, joined_at TEXT, PRIMARY KEY(challenge_id, user_id));
      ''');

      final db = ChallengeDatabase(inMemoryDb);
      final repo = SqliteChallengeRepository(db);

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesDashboardScreen(
            repository: repo,
            user: _testUser,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);

      await tester.tap(find.text('Browse'));
      await tester.pumpAndSettle();

      expect(find.text('Create'), findsOneWidget);
    });
  });
}
