import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/challenge_model.dart';
import '../models/team_model.dart';

class ChallengeDatabase {
  ChallengeDatabase([this._dbOverride]);

  final Database? _dbOverride;
  Database? _database;

  Future<Database> get database async {
    final override = _dbOverride;
    if (override != null) return override;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'kickoff_challenges.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE teams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    await db.execute('''
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
        rules_notes TEXT,
        FOREIGN KEY (team_id) REFERENCES teams(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE challenge_participants (
        challenge_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        joined_at TEXT NOT NULL,
        PRIMARY KEY (challenge_id, user_id),
        FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE
      )
    ''');

    // Seed default teams
    final teams = [
      {'name': 'Thunder FC', 'color': '#0B5FE8', 'icon': 'flash_on'},
      {'name': 'Solar United', 'color': '#FFD21F', 'icon': 'wb_sunny'},
      {'name': 'Apex Warriors', 'color': '#FFA24A', 'icon': 'shield'},
      {'name': 'Cyber Strikers', 'color': '#3D4C7C', 'icon': 'sports_soccer'},
    ];

    for (final team in teams) {
      await db.insert('teams', team);
    }

    // Seed default mock challenges
    final now = DateTime.now();
    final mockChallenges = [
      {
        'type': 'open',
        'team_id': null,
        'description': '5v5 Casual Match at Sunset Arena',
        'difficulty': 3,
        'location_name': 'Sunset Arena - Pitch 2',
        'date_time': now.add(const Duration(days: 1, hours: 4)).toIso8601String(),
        'max_players': 10,
        'current_players': 6,
        'join_code': 'KICK10',
        'created_by_user_id': 999,
        'challenge_status': 'active',
        'game_format': '5v5',
        'pitch_type': 'Turf',
        'skill_level': 'Intermediate',
        'duration_minutes': 90,
        'rules_notes': 'Please bring light and dark shirts!',
      },
      {
        'type': 'team',
        'team_id': 1,
        'description': 'Thunder FC vs Challengers Showcase',
        'difficulty': 4,
        'location_name': 'Downtown Sports Complex',
        'date_time': now.add(const Duration(days: 3, hours: 2)).toIso8601String(),
        'max_players': 14,
        'current_players': 8,
        'join_code': 'KICK77',
        'created_by_user_id': 998,
        'challenge_status': 'active',
        'game_format': '7v7',
        'pitch_type': 'Natural Grass',
        'skill_level': 'Advanced',
        'duration_minutes': 90,
        'rules_notes': 'Competitive match. Cleats allowed.',
      },
      {
        'type': 'open',
        'team_id': null,
        'description': 'Beginner Friendly 7v7 Weekend Session',
        'difficulty': 2,
        'location_name': 'Greenfield Park',
        'date_time': now.add(const Duration(days: 5)).toIso8601String(),
        'max_players': 14,
        'current_players': 11,
        'join_code': 'KICK99',
        'created_by_user_id': 997,
        'challenge_status': 'active',
        'game_format': '7v7',
        'pitch_type': 'Turf',
        'skill_level': 'Beginner',
        'duration_minutes': 60,
        'rules_notes': 'Friendly atmosphere for fun practice.',
      },
    ];

    for (final challenge in mockChallenges) {
      final challengeId = await db.insert('challenges', challenge);

      final currentPlayers = challenge['current_players'] as int;
      final creatorId = challenge['created_by_user_id'] as int;
      await db.insert('challenge_participants', {
        'challenge_id': challengeId,
        'user_id': creatorId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      for (var i = 1; i < currentPlayers; i++) {
        await db.insert('challenge_participants', {
          'challenge_id': challengeId,
          'user_id': 1000 + i,
          'joined_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE challenges ADD COLUMN game_format TEXT DEFAULT '5v5'");
      await db.execute("ALTER TABLE challenges ADD COLUMN pitch_type TEXT DEFAULT 'Turf'");
      await db.execute("ALTER TABLE challenges ADD COLUMN skill_level TEXT DEFAULT 'All Levels'");
      await db.execute("ALTER TABLE challenges ADD COLUMN duration_minutes INTEGER DEFAULT 60");
      await db.execute("ALTER TABLE challenges ADD COLUMN rules_notes TEXT");
    }
  }

  /// Generates a unique join code like KICK42, KICK8B, etc.
  Future<String> generateUniqueJoinCode() async {
    final db = await database;
    final random = Random();
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    while (true) {
      final suffix = List.generate(2, (_) => chars[random.nextInt(chars.length)]).join();
      final code = 'KICK$suffix';

      final res = await db.query(
        'challenges',
        where: 'join_code = ?',
        whereArgs: [code],
      );

      if (res.isEmpty) {
        return code;
      }
    }
  }

  Future<List<Team>> getTeams() async {
    final db = await database;
    final result = await db.query('teams', orderBy: 'id ASC');
    return result.map(Team.fromMap).toList();
  }

  Future<int> insertChallenge(Challenge challenge) async {
    final db = await database;
    return await db.transaction((txn) async {
      final map = challenge.toMap();
      final challengeId = await txn.insert('challenges', map);

      // Creator automatically joins the challenge
      await txn.insert('challenge_participants', {
        'challenge_id': challengeId,
        'user_id': challenge.createdByUserId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      return challengeId;
    });
  }

  Future<bool> updateChallenge(Challenge challenge) async {
    if (challenge.id == null) return false;
    final db = await database;
    final rows = await db.update(
      'challenges',
      challenge.toMap(),
      where: 'id = ? AND created_by_user_id = ?',
      whereArgs: [challenge.id, challenge.createdByUserId],
    );
    return rows > 0;
  }

  Future<bool> deleteChallenge(int challengeId, int userId) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.delete(
        'challenge_participants',
        where: 'challenge_id = ?',
        whereArgs: [challengeId],
      );

      final rows = await txn.delete(
        'challenges',
        where: 'id = ? AND created_by_user_id = ?',
        whereArgs: [challengeId, userId],
      );

      return rows > 0;
    });
  }

  Future<bool> leaveChallenge(int challengeId, int userId) async {
    final db = await database;
    return await db.transaction((txn) async {
      final deleted = await txn.delete(
        'challenge_participants',
        where: 'challenge_id = ? AND user_id = ?',
        whereArgs: [challengeId, userId],
      );

      if (deleted > 0) {
        await txn.rawUpdate('''
          UPDATE challenges
          SET current_players = MAX(1, current_players - 1)
          WHERE id = ?
        ''', [challengeId]);
        return true;
      }
      return false;
    });
  }

  Future<List<Challenge>> getCreatedChallenges(int userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT c.*, t.name as team_name
      FROM challenges c
      LEFT JOIN teams t ON c.team_id = t.id
      WHERE c.created_by_user_id = ?
      ORDER BY c.date_time ASC
    ''', [userId]);

    return result
        .map((map) => Challenge.fromMap(map, currentUserId: userId, isJoinedOverride: true))
        .toList();
  }

  Future<List<Challenge>> getJoinedChallenges(int userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT c.*, t.name as team_name
      FROM challenges c
      INNER JOIN challenge_participants cp ON c.id = cp.challenge_id
      LEFT JOIN teams t ON c.team_id = t.id
      WHERE cp.user_id = ? AND c.created_by_user_id != ?
      ORDER BY c.date_time ASC
    ''', [userId, userId]);

    return result
        .map((map) => Challenge.fromMap(map, currentUserId: userId, isJoinedOverride: true))
        .toList();
  }

  Future<List<Challenge>> getBrowseChallenges(int userId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT c.*, t.name as team_name,
        EXISTS(SELECT 1 FROM challenge_participants cp WHERE cp.challenge_id = c.id AND cp.user_id = ?) as is_joined
      FROM challenges c
      LEFT JOIN teams t ON c.team_id = t.id
      ORDER BY c.date_time ASC
    ''', [userId]);

    return result
        .map((map) => Challenge.fromMap(map, currentUserId: userId))
        .toList();
  }

  Future<bool> joinChallenge(int challengeId, int userId) async {
    final db = await database;
    return await db.transaction((txn) async {
      final challenges = await txn.query(
        'challenges',
        where: 'id = ?',
        whereArgs: [challengeId],
      );
      if (challenges.isEmpty) return false;

      final challengeMap = challenges.first;
      final maxPlayers = challengeMap['max_players'] as int;
      final currentPlayers = challengeMap['current_players'] as int;

      if (currentPlayers >= maxPlayers) return false;

      final existing = await txn.query(
        'challenge_participants',
        where: 'challenge_id = ? AND user_id = ?',
        whereArgs: [challengeId, userId],
      );
      if (existing.isNotEmpty) return true;

      await txn.insert('challenge_participants', {
        'challenge_id': challengeId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate('''
        UPDATE challenges
        SET current_players = current_players + 1
        WHERE id = ?
      ''', [challengeId]);

      return true;
    });
  }

  Future<Challenge?> findByJoinCode(String code, int userId) async {
    final db = await database;
    final cleanCode = code.trim().toUpperCase();
    final result = await db.rawQuery('''
      SELECT c.*, t.name as team_name,
        EXISTS(SELECT 1 FROM challenge_participants cp WHERE cp.challenge_id = c.id AND cp.user_id = ?) as is_joined
      FROM challenges c
      LEFT JOIN teams t ON c.team_id = t.id
      WHERE c.join_code = ?
    ''', [userId, cleanCode]);

    if (result.isEmpty) return null;
    return Challenge.fromMap(result.first, currentUserId: userId);
  }

  Future<bool> isJoinCodeUnique(String code) async {
    final db = await database;
    final result = await db.query(
      'challenges',
      where: 'join_code = ?',
      whereArgs: [code.trim().toUpperCase()],
    );
    return result.isEmpty;
  }
}
