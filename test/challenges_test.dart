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
        gameFormat: '7v7',
        pitchType: 'Turf',
        skillLevel: 'Advanced',
      );

      expect(challenge.isFull, isFalse);
      expect(challenge.isTeamChallenge, isFalse);
      expect(challenge.gameFormat, equals('7v7'));

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
      final dbName = 'test_db_crud_$testCount.db';
      await databaseFactoryFfi.deleteDatabase(dbName);
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
          challenge_status TEXT NOT NULL DEFAULT 'active',
          game_format TEXT DEFAULT '5v5',
          pitch_type TEXT DEFAULT 'Turf',
          skill_level TEXT DEFAULT 'All Levels',
          duration_minutes INTEGER DEFAULT 60,
          rules_notes TEXT
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

    test('Creates, updates, and deletes challenge', () async {
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

      // Update
      final updated = created.copyWith(description: 'Updated Sunday Cup');
      final updateSuccess = await repository.updateChallenge(updated);
      expect(updateSuccess, isTrue);

      final createdList = await repository.getCreatedChallenges(42);
      expect(createdList.first.description, equals('Updated Sunday Cup'));

      // Delete
      final deleteSuccess = await repository.deleteChallenge(created.id!, 42);
      expect(deleteSuccess, isTrue);

      final emptyList = await repository.getCreatedChallenges(42);
      expect(emptyList.isEmpty, isTrue);
    });

    test('User can join and quit (leave) challenge', () async {
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

      // Join
      final joined = await repository.joinChallenge(created.id!, 42);
      expect(joined, isTrue);

      var userJoinedList = await repository.getJoinedChallenges(42);
      expect(userJoinedList.length, equals(1));

      // Leave
      final left = await repository.leaveChallenge(created.id!, 42);
      expect(left, isTrue);

      userJoinedList = await repository.getJoinedChallenges(42);
      expect(userJoinedList.isEmpty, isTrue);
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
      late Database inMemoryDb;
      await tester.runAsync(() async {
        await databaseFactoryFfi.deleteDatabase('widget_db_2.db');
        inMemoryDb = await databaseFactoryFfi.openDatabase('widget_db_2.db');
        await inMemoryDb.execute('''
          CREATE TABLE teams (id INTEGER PRIMARY KEY, name TEXT, color TEXT, icon TEXT);
        ''');
        await inMemoryDb.execute('''
          CREATE TABLE challenges (id INTEGER PRIMARY KEY, type TEXT, team_id INTEGER, description TEXT, difficulty INTEGER, location_name TEXT, date_time TEXT, max_players INTEGER, current_players INTEGER, join_code TEXT UNIQUE, created_by_user_id INTEGER, challenge_status TEXT, game_format TEXT, pitch_type TEXT, skill_level TEXT, duration_minutes INTEGER, rules_notes TEXT);
        ''');
        await inMemoryDb.execute('''
          CREATE TABLE challenge_participants (challenge_id INTEGER, user_id INTEGER, joined_at TEXT, PRIMARY KEY(challenge_id, user_id));
        ''');
      });

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

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);

      await tester.tap(find.text('Browse'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.text('Create'), findsOneWidget);
    });
  });
}
